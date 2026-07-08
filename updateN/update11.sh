#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
FRONTEND=ledger-frontend
[ -d "$BACKEND" ] && [ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

# ---------- Backend: schemas ----------
cat > "$BACKEND/app/schemas_import_export.py" << 'EOF'
from datetime import date
from pydantic import BaseModel


class ImportRowPreview(BaseModel):
    sheet: str
    row: int
    date: date
    category_top: str
    item: str | None
    amount: float
    type: str  # income / expense
    will_create_category: bool
    is_duplicate: bool = False
    error: str | None = None


class ImportPreviewResponse(BaseModel):
    total_rows: int
    valid_rows: int
    new_categories: list[str]
    errors: list[str]
    rows: list[ImportRowPreview]


class ImportCommitResponse(BaseModel):
    imported: int
    skipped_errors: int
    skipped_duplicates: int
    created_categories: int
EOF

# ---------- Backend: services package ----------
mkdir -p "$BACKEND/app/services"
touch "$BACKEND/app/services/__init__.py"

cat > "$BACKEND/app/services/excel_transfer.py" << 'EOF'
import re
from datetime import datetime, date, timedelta
from io import BytesIO

import openpyxl
from openpyxl import Workbook
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Category, Transaction, EntryType

MONTH_SHEET_RE = re.compile(r"^(\d{1,2})月$")
EXCEL_EPOCH = datetime(1899, 12, 30)


def _excel_serial_to_date(value) -> date:
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    return (EXCEL_EPOCH + timedelta(days=float(value))).date()


def parse_month_sheets(file_bytes: bytes) -> list[dict]:
    """只解析 N月 分頁,總表/類別分頁自動略過。"""
    wb = openpyxl.load_workbook(BytesIO(file_bytes), data_only=True)
    rows: list[dict] = []
    for sheet_name in wb.sheetnames:
        if not MONTH_SHEET_RE.match(sheet_name):
            continue
        ws = wb[sheet_name]
        for row_idx, row in enumerate(ws.iter_rows(min_row=3, min_col=3, max_col=6), start=3):
            date_cell, category_cell, item_cell, amount_cell = row
            if category_cell.value is None and amount_cell.value is None:
                continue
            rows.append({
                "sheet": sheet_name,
                "row": row_idx,
                "date_raw": date_cell.value,
                "category_top": (category_cell.value or "").strip() if category_cell.value else None,
                "item": (item_cell.value or "").strip() if item_cell.value else None,
                "amount_raw": amount_cell.value,
            })
    return rows


def _validate_row(raw: dict) -> tuple[dict | None, str | None]:
    if not raw["category_top"]:
        return None, "缺少類別"
    if raw["amount_raw"] is None:
        return None, "缺少金額"
    try:
        amount = float(raw["amount_raw"])
    except (TypeError, ValueError):
        return None, f"金額格式錯誤: {raw['amount_raw']!r}"
    if amount <= 0:
        return None, f"金額必須為正數: {amount}"
    try:
        tx_date = _excel_serial_to_date(raw["date_raw"])
    except (TypeError, ValueError):
        return None, f"日期格式錯誤: {raw['date_raw']!r}"

    entry_type = EntryType.income if raw["category_top"] == "收入" else EntryType.expense
    return {
        "sheet": raw["sheet"], "row": raw["row"], "date": tx_date,
        "category_top": raw["category_top"], "item": raw["item"],
        "amount": amount, "type": entry_type,
    }, None


def _get_or_create_top_category(db: Session, household_id: str, name: str, type_: EntryType, dry_run: bool) -> Category | None:
    cat = db.execute(
        select(Category).where(
            Category.household_id == household_id,
            Category.parent_id.is_(None),
            Category.name == name,
            Category.type == type_,
        )
    ).scalar_one_or_none()
    if cat or dry_run:
        return cat
    cat = Category(household_id=household_id, name=name, parent_id=None, type=type_)
    db.add(cat)
    db.flush()
    return cat


def _find_category_anywhere(db: Session, household_id: str, name: str, type_: EntryType) -> Category | None:
    """不限層級比對同名分類,相容既有多層樹,避免重複建立。"""
    return db.execute(
        select(Category).where(
            Category.household_id == household_id,
            Category.name == name,
            Category.type == type_,
        )
    ).scalars().first()


def _existing_tx_keys(db: Session, household_id: str, account_id: str, tx_dates: set[date]) -> set[tuple]:
    if not tx_dates:
        return set()
    rows = db.execute(
        select(Transaction.date, Transaction.amount, Transaction.category_id, Transaction.type)
        .where(
            Transaction.household_id == household_id,
            Transaction.account_id == account_id,
            Transaction.date.in_(tx_dates),
        )
    ).all()
    return {(r.date, float(r.amount), r.category_id, r.type) for r in rows}


def process_import(
    db: Session, household_id: str, user_id: str, account_id: str,
    file_bytes: bytes, dry_run: bool, force_rows: set[str] | None = None,
) -> dict:
    force_rows = force_rows or set()
    raw_rows = parse_month_sheets(file_bytes)
    errors: list[str] = []
    new_categories: set[str] = set()
    preview_rows: list[dict] = []
    imported = 0
    skipped_duplicates = 0
    created_categories = 0

    top_cache: dict[tuple[str, EntryType], Category | None] = {}
    item_cache: dict[tuple[str, EntryType], Category | None] = {}

    parsed_list: list[dict] = []
    for raw in raw_rows:
        parsed, err = _validate_row(raw)
        if err:
            errors.append(f"[{raw['sheet']} row {raw['row']}] {err}")
            continue
        parsed_list.append(parsed)

    existing_keys = _existing_tx_keys(db, household_id, account_id, {p["date"] for p in parsed_list})
    seen_in_batch: set[tuple] = set()

    for parsed in parsed_list:
        top_key = (parsed["category_top"], parsed["type"])
        top_cat = top_cache.get(top_key)
        if top_cat is None and top_key not in top_cache:
            top_cat = _get_or_create_top_category(db, household_id, parsed["category_top"], parsed["type"], dry_run)
            top_cache[top_key] = top_cat
            if top_cat is None:
                new_categories.add(parsed["category_top"])
                created_categories += 1 if not dry_run else 0

        category_id_for_tx = top_cat.id if top_cat else None
        will_create = top_cat is None

        # 項目一律建成子分類(含卡費 > 富邦/兆豐...)
        if parsed["item"]:
            item_key = (parsed["item"], parsed["type"])
            item_cat = item_cache.get(item_key)
            if item_cat is None and item_key not in item_cache:
                item_cat = _find_category_anywhere(db, household_id, parsed["item"], parsed["type"])
                if item_cat is None and top_cat is not None and not dry_run:
                    item_cat = Category(
                        household_id=household_id, name=parsed["item"],
                        parent_id=top_cat.id, type=parsed["type"],
                    )
                    db.add(item_cat)
                    db.flush()
                    created_categories += 1
                if item_cat is None:
                    new_categories.add(f"{parsed['category_top']} > {parsed['item']}")
                    will_create = True
                item_cache[item_key] = item_cat
            if item_cat is not None:
                category_id_for_tx = item_cat.id

        row_key = f"{parsed['sheet']}:{parsed['row']}"
        dedupe_key = (parsed["date"], parsed["amount"], category_id_for_tx, parsed["type"])
        is_duplicate = dedupe_key in existing_keys or dedupe_key in seen_in_batch
        forced = row_key in force_rows

        preview_rows.append({
            "sheet": parsed["sheet"], "row": parsed["row"], "date": parsed["date"],
            "category_top": parsed["category_top"], "item": parsed["item"],
            "amount": parsed["amount"], "type": parsed["type"].value,
            "will_create_category": will_create,
            "is_duplicate": is_duplicate, "error": None,
        })

        if is_duplicate and not forced:
            skipped_duplicates += 1
            continue

        if not forced:
            seen_in_batch.add(dedupe_key)
        if not dry_run and category_id_for_tx:
            db.add(Transaction(
                household_id=household_id, user_id=user_id, account_id=account_id,
                category_id=category_id_for_tx, amount=parsed["amount"],
                type=parsed["type"], date=parsed["date"], note=None,
            ))
            imported += 1

    if not dry_run:
        db.commit()

    return {
        "total_rows": len(raw_rows),
        "valid_rows": len(preview_rows),
        "new_categories": sorted(new_categories),
        "errors": errors,
        "rows": preview_rows,
        "imported": imported,
        "skipped_errors": len(errors),
        "skipped_duplicates": skipped_duplicates,
        "created_categories": created_categories,
    }


def _root_category_name(db: Session, category: Category, cache: dict[str, Category]) -> str:
    node = category
    while node.parent_id is not None:
        parent = cache.get(node.parent_id)
        if parent is None:
            parent = db.get(Category, node.parent_id)
            cache[node.parent_id] = parent
        node = parent
    return node.name


def build_export_workbook(db: Session, household_id: str, year: int) -> BytesIO:
    txs = db.execute(
        select(Transaction)
        .where(Transaction.household_id == household_id)
        .where(Transaction.date >= date(year, 1, 1), Transaction.date <= date(year, 12, 31))
        .order_by(Transaction.date)
    ).scalars().all()

    cat_cache: dict[str, Category] = {}
    by_month: dict[int, list[Transaction]] = {m: [] for m in range(1, 13)}
    for tx in txs:
        by_month[tx.date.month].append(tx)

    wb = Workbook()
    wb.remove(wb.active)

    for month in range(1, 13):
        ws = wb.create_sheet(f"{month}月")
        ws.append(["日期", "類別", "項目", "金額"])
        for tx in by_month[month]:
            category = cat_cache.get(tx.category_id)
            if category is None:
                category = db.get(Category, tx.category_id)
                cat_cache[tx.category_id] = category
            root_name = _root_category_name(db, category, cat_cache)
            item = category.name if category.parent_id is not None else (tx.note or "")
            ws.append([tx.date, root_name, item, float(tx.amount)])

    buf = BytesIO()
    wb.save(buf)
    buf.seek(0)
    return buf
EOF

# ---------- Backend: router ----------
cat > "$BACKEND/app/routers/transactions_transfer.py" << 'EOF'
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.deps import get_current_user, get_db
from app.schemas_import_export import ImportPreviewResponse, ImportCommitResponse
from app.services.excel_transfer import process_import, build_export_workbook

router = APIRouter(prefix="/transactions", tags=["import-export"])

MAX_IMPORT_SIZE = 10 * 1024 * 1024  # 10MB


@router.post("/import/preview", response_model=ImportPreviewResponse)
async def import_preview(
    file: UploadFile = File(...),
    account_id: str = Form(...),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    content = await file.read()
    if len(content) > MAX_IMPORT_SIZE:
        raise HTTPException(413, "檔案過大")
    result = process_import(db, current_user.household_id, current_user.id, account_id, content, dry_run=True)
    return ImportPreviewResponse(**result)


@router.post("/import/commit", response_model=ImportCommitResponse)
async def import_commit(
    file: UploadFile = File(...),
    account_id: str = Form(...),
    force_rows: str = Form(""),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    content = await file.read()
    if len(content) > MAX_IMPORT_SIZE:
        raise HTTPException(413, "檔案過大")
    force_set = {r for r in force_rows.split(",") if r}
    result = process_import(
        db, current_user.household_id, current_user.id, account_id, content,
        dry_run=False, force_rows=force_set,
    )
    return ImportCommitResponse(
        imported=result["imported"],
        skipped_errors=result["skipped_errors"],
        skipped_duplicates=result["skipped_duplicates"],
        created_categories=result["created_categories"],
    )


@router.get("/export/excel")
async def export_excel(
    year: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    buf = build_export_workbook(db, current_user.household_id, year)
    filename = f"{year}-記帳表.xlsx"
    return StreamingResponse(
        buf,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
EOF

# ---------- Backend: main.py 掛載 router(精確字串替換) ----------
python3 << 'PYEOF'
path = "ledger-backend/app/main.py"
with open(path) as f:
    content = f.read()

old = "from app.routers import auth, households, accounts, categories, transactions"
new = "from app.routers import auth, households, accounts, categories, transactions, transactions_transfer"
if old in content:
    content = content.replace(old, new)
else:
    print("⚠️ import 行不符,請人工檢查 main.py 現有 import 寫法")
    raise SystemExit(1)

anchor = "app.include_router(transactions.router)"
if anchor not in content:
    print("⚠️ 找不到 transactions.router 掛載行,請人工檢查")
    raise SystemExit(1)
if "app.include_router(transactions_transfer.router)" not in content:
    content = content.replace(anchor, anchor + "\napp.include_router(transactions_transfer.router)")

with open(path, "w") as f:
    f.write(content)
print("✅ main.py 已掛載 transactions_transfer.router")
PYEOF

# ---------- Backend: requirements.txt 補 openpyxl(若缺) ----------
python3 << 'PYEOF'
path = "ledger-backend/requirements.txt"
with open(path) as f:
    lines = f.read().splitlines()
if not any(l.strip().lower().startswith("openpyxl") for l in lines):
    lines.append("openpyxl")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("✅ requirements.txt 已加入 openpyxl")
else:
    print("ℹ️ openpyxl 已存在,略過")
PYEOF

# ---------- Frontend: types ----------
cat > "$FRONTEND/src/types/importExport.ts" << 'EOF'
export interface ImportRowPreview {
  sheet: string
  row: number
  date: string
  category_top: string
  item: string | null
  amount: number
  type: 'income' | 'expense'
  will_create_category: boolean
  is_duplicate: boolean
  error: string | null
}

export interface ImportPreviewResponse {
  total_rows: number
  valid_rows: number
  new_categories: string[]
  errors: string[]
  rows: ImportRowPreview[]
}

export interface ImportCommitResponse {
  imported: number
  skipped_errors: number
  skipped_duplicates: number
  created_categories: number
}
EOF

# ---------- Frontend: api ----------
cat > "$FRONTEND/src/api/importExport.ts" << 'EOF'
import { apiClient } from './client'
import type { ImportPreviewResponse, ImportCommitResponse } from '@/types/importExport'

export function previewImport(file: File, accountId: string) {
  const form = new FormData()
  form.append('file', file)
  form.append('account_id', accountId)
  return apiClient
    .post<ImportPreviewResponse>('/transactions/import/preview', form, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    .then((r) => r.data)
}

export function commitImport(file: File, accountId: string, forceRows: string[] = []) {
  const form = new FormData()
  form.append('file', file)
  form.append('account_id', accountId)
  form.append('force_rows', forceRows.join(','))
  return apiClient
    .post<ImportCommitResponse>('/transactions/import/commit', form, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    .then((r) => r.data)
}

export async function exportExcel(year: number): Promise<void> {
  const { data } = await apiClient.get('/transactions/export/excel', {
    params: { year },
    responseType: 'blob',
  })
  const url = URL.createObjectURL(new Blob([data]))
  const a = document.createElement('a')
  a.href = url
  a.download = `${year}-記帳表.xlsx`
  a.click()
  URL.revokeObjectURL(url)
}
EOF

# ---------- Frontend: component ----------
cat > "$FRONTEND/src/components/ExcelImportExport.vue" << 'EOF'
<template>
  <div class="import-export">
    <section class="export-section">
      <h3>匯出 Excel</h3>
      <select v-model.number="exportYear">
        <option v-for="y in availableYears" :key="y" :value="y">{{ y }}</option>
      </select>
      <button @click="handleExport" :disabled="exporting">
        {{ exporting ? '匯出中...' : '下載 Excel' }}
      </button>
    </section>

    <section class="import-section">
      <h3>匯入 Excel</h3>
      <label>
        目標帳戶
        <select v-model="selectedAccountId">
          <option v-for="acc in accounts" :key="acc.id" :value="acc.id">
            {{ acc.name }}{{ acc.is_default_expense ? '（預設）' : '' }} - {{ ACCOUNT_TYPE_LABEL[acc.type] }}
          </option>
        </select>
      </label>
      <input type="file" accept=".xlsx" @change="handleFileSelect" ref="fileInput" />

      <button
        v-if="selectedFile && !preview"
        @click="handlePreview"
        :disabled="!selectedAccountId || loading"
      >
        {{ loading ? '解析中...' : '預覽' }}
      </button>

      <div v-if="preview" class="preview-result">
        <p>
          共 {{ preview.total_rows }} 筆,有效 {{ preview.valid_rows }} 筆,
          重複 {{ duplicateCount }} 筆,錯誤 {{ preview.errors.length }} 筆
        </p>

        <details v-if="preview.new_categories.length">
          <summary>將新建 {{ preview.new_categories.length }} 個分類</summary>
          <ul><li v-for="c in preview.new_categories" :key="c">{{ c }}</li></ul>
        </details>

        <details v-if="preview.errors.length" open>
          <summary class="error-summary">{{ preview.errors.length }} 筆錯誤(不會匯入)</summary>
          <ul><li v-for="(e, i) in preview.errors" :key="i" class="error-line">{{ e }}</li></ul>
        </details>

        <table class="preview-table">
          <thead>
            <tr><th></th><th>日期</th><th>類別</th><th>項目</th><th>金額</th><th>狀態</th></tr>
          </thead>
          <tbody>
            <tr
              v-for="r in preview.rows"
              :key="`${r.sheet}-${r.row}`"
              :class="{ duplicate: r.is_duplicate && !isForced(r), 'new-cat': r.will_create_category }"
            >
              <td>
                <input
                  v-if="r.is_duplicate"
                  type="checkbox"
                  :checked="isForced(r)"
                  @change="toggleForce(r)"
                  title="仍要匯入這筆"
                />
              </td>
              <td>{{ r.date }}</td>
              <td>{{ r.category_top }}</td>
              <td>{{ r.item ?? '-' }}</td>
              <td>{{ r.amount.toLocaleString() }}</td>
              <td>
                <span v-if="r.is_duplicate && !isForced(r)" class="tag tag-dup">重複跳過</span>
                <span v-else-if="r.is_duplicate && isForced(r)" class="tag tag-forced">強制匯入</span>
                <span v-else-if="r.will_create_category" class="tag tag-new">新分類</span>
                <span v-else class="tag tag-ok">匯入</span>
              </td>
            </tr>
          </tbody>
        </table>

        <div class="actions">
          <button @click="handleCommit" :disabled="committing">
            {{ committing ? '匯入中...' : `確認匯入 ${finalImportCount} 筆` }}
          </button>
          <button @click="resetImport">取消</button>
        </div>
      </div>

      <div v-if="commitResult" class="commit-result">
        ✅ 已匯入 {{ commitResult.imported }} 筆,
        跳過重複 {{ commitResult.skipped_duplicates }} 筆,
        跳過錯誤 {{ commitResult.skipped_errors }} 筆,
        新建分類 {{ commitResult.created_categories }} 個
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { previewImport, commitImport, exportExcel } from '@/api/importExport'
import { fetchAccounts } from '@/api/ledger'
import { ACCOUNT_TYPE_LABEL } from '@/utils/ledgerLabels'
import type { ImportPreviewResponse, ImportCommitResponse } from '@/types/importExport'
import type { AccountOut } from '@/types/ledger'

const accounts = ref<AccountOut[]>([])
const selectedAccountId = ref('')
const selectedFile = ref<File | null>(null)
const preview = ref<ImportPreviewResponse | null>(null)
const commitResult = ref<ImportCommitResponse | null>(null)
const loading = ref(false)
const committing = ref(false)
const exporting = ref(false)
const exportYear = ref(new Date().getFullYear())
const forcedRows = ref<Set<string>>(new Set())

const availableYears = computed(() => {
  const cur = new Date().getFullYear()
  return Array.from({ length: 5 }, (_, i) => cur - i)
})
const duplicateCount = computed(() => preview.value?.rows.filter((r) => r.is_duplicate).length ?? 0)
const finalImportCount = computed(() => {
  if (!preview.value) return 0
  return preview.value.rows.filter((r) => !r.is_duplicate || isForced(r)).length
})

fetchAccounts().then((list) => {
  accounts.value = list
  if (list.length && !selectedAccountId.value) {
    selectedAccountId.value = list.find((a) => a.is_default_expense)?.id ?? list[0].id
  }
})

function rowKey(r: { sheet: string; row: number }) {
  return `${r.sheet}:${r.row}`
}
function isForced(r: { sheet: string; row: number }) {
  return forcedRows.value.has(rowKey(r))
}
function toggleForce(r: { sheet: string; row: number }) {
  const key = rowKey(r)
  forcedRows.value.has(key) ? forcedRows.value.delete(key) : forcedRows.value.add(key)
}

function handleFileSelect(e: Event) {
  const target = e.target as HTMLInputElement
  selectedFile.value = target.files?.[0] ?? null
  preview.value = null
  commitResult.value = null
  forcedRows.value.clear()
}

async function handlePreview() {
  if (!selectedFile.value || !selectedAccountId.value) return
  loading.value = true
  try {
    preview.value = await previewImport(selectedFile.value, selectedAccountId.value)
  } catch (err) {
    alert('預覽失敗,請確認檔案格式是否正確')
    console.error(err)
  } finally {
    loading.value = false
  }
}

async function handleCommit() {
  if (!selectedFile.value || !selectedAccountId.value) return
  if (!confirm(`確定匯入 ${finalImportCount.value} 筆交易?`)) return
  committing.value = true
  try {
    commitResult.value = await commitImport(selectedFile.value, selectedAccountId.value, [...forcedRows.value])
    preview.value = null
    selectedFile.value = null
    forcedRows.value.clear()
  } catch (err) {
    alert('匯入失敗')
    console.error(err)
  } finally {
    committing.value = false
  }
}

function resetImport() {
  preview.value = null
  selectedFile.value = null
  forcedRows.value.clear()
}

async function handleExport() {
  exporting.value = true
  try {
    await exportExcel(exportYear.value)
  } catch (err) {
    alert('匯出失敗')
    console.error(err)
  } finally {
    exporting.value = false
  }
}
</script>

<style scoped>
.duplicate { opacity: 0.5; }
.new-cat { background: #fffbe6; }
.tag { padding: 2px 6px; border-radius: 4px; font-size: 12px; }
.tag-dup { background: #f0f0f0; color: #999; }
.tag-forced { background: #d1e7ff; color: #084298; }
.tag-new { background: #fff3cd; color: #856404; }
.tag-ok { background: #d4edda; color: #155724; }
.error-summary { color: #d32f2f; cursor: pointer; }
.error-line { color: #d32f2f; }
.preview-table { width: 100%; border-collapse: collapse; margin: 12px 0; }
.preview-table th, .preview-table td { padding: 4px 8px; border-bottom: 1px solid #eee; text-align: left; }
.actions { display: flex; gap: 8px; margin-top: 12px; }
</style>
EOF

echo "✅ 檔案已寫入完成"
git add -A
git commit -m "feat: Excel 匯入/匯出功能(分類自動比對建立、重複偵測、強制匯入覆蓋)"
echo "✅ 已 commit,請執行 'git push origin main',再到 server 跑 ./deploy.sh"