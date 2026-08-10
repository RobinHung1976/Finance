#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# update46.sh
# 分類統計(A3)下鑽時,補上「本分類直接交易(未再細分)」項目
#
# 背景:
#   頂層彙總(parent_id=None)的 Recursive CTE 起點是分類自己,所以直接掛在
#   該分類本身的交易會被算進總額;但下鑽某分類(parent_id=該分類 id)時,
#   CTE 起點變成「該分類的子分類們」,分類自己不在樹裡,導致「直接掛在
#   該分類本身、未再歸類到任何子分類」的交易在下鑽畫面消失,造成
#   「子分類加總 != 頂層總額」的落差。
#
# 修法:
#   下鑽情境下,額外查一次「category_id = 該分類本身」的直接交易加總,
#   若 >0 就補一個 is_self=true 的項目進 items,讓總和對得起來。
#
# 影響檔案:
#   - ledger-backend/app/routers/stats.py       (完整覆寫)
#   - ledger-backend/app/schemas_ledger.py       (完整覆寫)
#   - ledger-frontend/src/components/CategoryBreakdownChart.vue (完整覆寫)
#
# 前置狀態:本次腳本基於 update45.sh 已套用的 server 現況(stats.py 現有
#          category-breakdown / tag-breakdown 邏輯)進行完整覆寫,不做
#          精確字串比對。
# =============================================================================

CURRENT=46

echo "===> [1/4] 自動歸檔已執行的 updateN.sh"
mkdir -p "update${CURRENT}"
for f in update*.sh; do
  [ "$f" = "update${CURRENT}.sh" ] && continue
  [ -f "$f" ] || continue
  git mv "$f" "update${CURRENT}/$f" 2>/dev/null || mv "$f" "update${CURRENT}/$f"
done
git add -A
if ! git diff --cached --quiet; then
  git commit -m "chore: 歸檔已執行的 updateN.sh 腳本"
  echo "    已歸檔並 commit"
else
  echo "    無需歸檔的舊腳本"
fi

echo "===> [2/4] 前置驗證:確認受影響檔案存在"
for f in \
  "ledger-backend/app/routers/stats.py" \
  "ledger-backend/app/schemas_ledger.py" \
  "ledger-frontend/src/components/CategoryBreakdownChart.vue"
do
  if [ ! -f "$f" ]; then
    echo "❌ 找不到 $f,請確認目前 repo 狀態是否為預期版本" >&2
    exit 1
  fi
done
echo "    三個檔案皆存在,繼續執行"

echo "===> [3/4] 完整覆寫三個檔案"

# -----------------------------------------------------------------------
# ledger-backend/app/routers/stats.py
# -----------------------------------------------------------------------
cat > ledger-backend/app/routers/stats.py << 'PYEOF'
from datetime import date
from dateutil.relativedelta import relativedelta

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, text
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models import EntryType, Transaction, User, Category
from app.schemas_ledger import (
    MonthlySummary,
    MonthlyTrendOut,
    CategoryBreakdownItem,
    CategoryBreakdownOut,
)

router = APIRouter(prefix="/stats", tags=["stats"])


def _default_range() -> tuple[date, date]:
    today = date.today()
    return date(today.year, 1, 1), today


def _resolve_range(start_date: date | None, end_date: date | None) -> tuple[date, date]:
    default_start, default_end = _default_range()
    start = start_date or default_start
    end = end_date or default_end
    if start > end:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="起始日期不能晚於結束日期")
    return start, end


@router.get("/monthly-trend", response_model=MonthlyTrendOut)
def monthly_trend(
    start_date: date | None = Query(default=None, description="預設今年 1/1"),
    end_date: date | None = Query(default=None, description="預設今天"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """區間收支趨勢 + 結餘計算(A1 + A2)。"""
    start, end = _resolve_range(start_date, end_date)
    range_start = start.replace(day=1)
    months = (end.year - range_start.year) * 12 + (end.month - range_start.month) + 1

    month_bucket = func.date_trunc("month", Transaction.date).label("month_bucket")
    rows = (
        db.query(month_bucket, Transaction.type, func.sum(Transaction.amount).label("total"))
        .filter(
            Transaction.household_id == current_user.household_id,
            Transaction.date >= start,
            Transaction.date <= end,
        )
        .group_by(month_bucket, Transaction.type)
        .order_by(month_bucket)
        .all()
    )

    buckets: dict[str, dict[str, float]] = {}
    cursor = range_start
    for _ in range(months):
        key = cursor.strftime("%Y-%m")
        buckets[key] = {"income": 0.0, "expense": 0.0}
        cursor = cursor + relativedelta(months=1)

    for row in rows:
        key = row.month_bucket.strftime("%Y-%m")
        if key not in buckets:
            continue
        field = "income" if row.type == EntryType.income else "expense"
        buckets[key][field] = float(row.total)

    month_list = [
        MonthlySummary(
            month=key,
            income=vals["income"],
            expense=vals["expense"],
            balance=round(vals["income"] - vals["expense"], 2),
        )
        for key, vals in sorted(buckets.items())
    ]

    total_income = round(sum(m.income for m in month_list), 2)
    total_expense = round(sum(m.expense for m in month_list), 2)

    return MonthlyTrendOut(
        months=month_list,
        total_income=total_income,
        total_expense=total_expense,
        total_balance=round(total_income - total_expense, 2),
    )


_CATEGORY_BREAKDOWN_ROLLUP_SQL = text("""
    WITH RECURSIVE cat_tree AS (
        SELECT id, id AS root_id, name AS root_name
        FROM categories
        WHERE household_id = :household_id
          AND parent_id IS NOT DISTINCT FROM :root_parent_id

        UNION ALL

        SELECT c.id, ct.root_id, ct.root_name
        FROM categories c
        JOIN cat_tree ct ON c.parent_id = ct.id
        WHERE c.household_id = :household_id
    )
    SELECT ct.root_id AS category_id, ct.root_name AS category_name,
           COALESCE(SUM(t.amount), 0) AS amount,
           EXISTS (
               SELECT 1 FROM categories cc
               WHERE cc.parent_id = ct.root_id AND cc.household_id = :household_id
           ) AS has_children
    FROM cat_tree ct
    JOIN transactions t ON t.category_id = ct.id
    WHERE t.household_id = :household_id
      AND t.type = :entry_type
      AND t.date >= :start_date
      AND t.date <= :end_date
    GROUP BY ct.root_id, ct.root_name
    ORDER BY amount DESC
""")


# 下鑽情境專用:算出「直接掛在被下鑽分類本身、未再歸類到任何子分類」的交易加總。
# 頂層彙總(parent_id=None)的 cat_tree 起點已包含分類自己,不會有這個問題,
# 只有下鑽(parent_id=某分類 id)時,分類自己不在 cat_tree 裡,才需要這條額外查詢補回來。
_CATEGORY_SELF_DIRECT_SQL = text("""
    SELECT COALESCE(SUM(t.amount), 0) AS amount
    FROM transactions t
    WHERE t.household_id = :household_id
      AND t.category_id = :parent_id
      AND t.type = :entry_type
      AND t.date >= :start_date
      AND t.date <= :end_date
""")


@router.get("/category-breakdown", response_model=CategoryBreakdownOut)
def category_breakdown(
    type: EntryType = Query(EntryType.expense),
    start_date: date | None = Query(default=None, description="預設今年 1/1"),
    end_date: date | None = Query(default=None, description="預設今天"),
    parent_id: str | None = Query(None, description="下鑽指定分類的子項,None=頂層"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    start, end = _resolve_range(start_date, end_date)

    rows = db.execute(
        _CATEGORY_BREAKDOWN_ROLLUP_SQL,
        {
            "household_id": current_user.household_id,
            "entry_type": type.value,
            "start_date": start,
            "end_date": end,
            "root_parent_id": parent_id,
        },
    ).mappings().all()

    raw_items = [
        {
            "category_id": str(r["category_id"]),
            "category_name": r["category_name"],
            "amount": float(r["amount"]),
            "has_children": bool(r["has_children"]),
            "is_self": False,
        }
        for r in rows
    ]

    # 下鑽情境才需要補「本分類直接交易」這一行,頂層(parent_id=None)沒有這個問題
    if parent_id is not None:
        direct_amount = float(
            db.execute(
                _CATEGORY_SELF_DIRECT_SQL,
                {
                    "household_id": current_user.household_id,
                    "parent_id": parent_id,
                    "entry_type": type.value,
                    "start_date": start,
                    "end_date": end,
                },
            ).scalar() or 0
        )
        if direct_amount > 0:
            parent_name = (
                db.query(Category.name).filter(Category.id == parent_id).scalar()
                or "未知分類"
            )
            raw_items.append(
                {
                    "category_id": parent_id,
                    "category_name": f"{parent_name}(直接歸類,未再細分)",
                    "amount": direct_amount,
                    "has_children": False,
                    "is_self": True,
                }
            )

    total = sum(i["amount"] for i in raw_items)
    items = [
        CategoryBreakdownItem(
            **i,
            percentage=round(i["amount"] / total * 100, 2) if total > 0 else 0.0,
        )
        for i in sorted(raw_items, key=lambda x: x["amount"], reverse=True)
    ]
    return CategoryBreakdownOut(type=type, total=total, items=items)


from app.models import Tag, TransactionTag
from app.schemas_ledger import TagBreakdownItem, TagBreakdownOut


@router.get("/tag-breakdown", response_model=TagBreakdownOut)
def get_tag_breakdown(
    start_date: date,
    end_date: date,
    type: EntryType = EntryType.expense,
    limit: int = Query(15, ge=1, le=50),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if end_date < start_date:
        raise HTTPException(status_code=400, detail="end_date 不可早於 start_date")

    rows = (
        db.query(
            Tag.id,
            Tag.name,
            func.sum(Transaction.amount).label("total_amount"),
            func.count(Transaction.id).label("transaction_count"),
        )
        .join(TransactionTag, TransactionTag.tag_id == Tag.id)
        .join(Transaction, Transaction.id == TransactionTag.transaction_id)
        .filter(
            Tag.household_id == current_user.household_id,
            Transaction.type == type,
            Transaction.date >= start_date,
            Transaction.date <= end_date,
        )
        .group_by(Tag.id, Tag.name)
        .order_by(func.sum(Transaction.amount).desc())
        .limit(limit)
        .all()
    )

    return TagBreakdownOut(
        items=[
            TagBreakdownItem(
                tag_id=str(r.id),
                name=r.name,
                total_amount=float(r.total_amount),
                transaction_count=r.transaction_count,
            )
            for r in rows
        ],
        type=type,
        start_date=start_date,
        end_date=end_date,
    )
PYEOF
echo "    stats.py 覆寫完成"

# -----------------------------------------------------------------------
# ledger-backend/app/schemas_ledger.py
# -----------------------------------------------------------------------
cat > ledger-backend/app/schemas_ledger.py << 'PYEOF'
from datetime import date as date_type, datetime, date

from pydantic import BaseModel, Field, field_validator

from app.models import AccountType, EntryType
from app.schemas_tag import TagOut


# ---------- Account ----------
class AccountCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    type: AccountType
    balance: float = 0
    is_default_expense: bool = False


class AccountUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    type: AccountType | None = None
    balance: float | None = None
    is_default_expense: bool | None = None


class AccountOut(BaseModel):
    id: str
    name: str
    type: AccountType
    balance: float
    is_default_expense: bool

    class Config:
        from_attributes = True


# ---------- Category ----------
class CategoryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    parent_id: str | None = None
    type: EntryType


class CategoryUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    parent_id: str | None = None


class CategoryOut(BaseModel):
    id: str
    name: str
    parent_id: str | None
    type: EntryType

    class Config:
        from_attributes = True


# ---------- Transaction ----------
class TransactionCreate(BaseModel):
    account_id: str
    category_id: str
    amount: float = Field(gt=0)
    type: EntryType
    date: date_type
    note: str | None = Field(default=None, max_length=500)
    tag_ids: list[str] = Field(default_factory=list)

    @field_validator("amount")
    @classmethod
    def amount_must_be_positive(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("金額必須大於 0")
        return round(v, 2)


class TransactionUpdate(BaseModel):
    account_id: str | None = None
    category_id: str | None = None
    amount: float | None = Field(default=None, gt=0)
    type: EntryType | None = None
    date: date_type | None = None
    note: str | None = Field(default=None, max_length=500)
    tag_ids: list[str] | None = None  # None=不變動,[]=清空所有品項


class TransactionOut(BaseModel):
    id: str
    account_id: str
    category_id: str
    amount: float
    type: EntryType
    date: date_type
    note: str | None
    user_id: str | None
    tags: list[TagOut] = []

    class Config:
        from_attributes = True


# ---------- Stats: Monthly Trend ----------
class MonthlySummary(BaseModel):
    month: str
    income: float
    expense: float
    balance: float


class MonthlyTrendOut(BaseModel):
    months: list[MonthlySummary]
    total_income: float
    total_expense: float
    total_balance: float


# ---------- Stats: Category Breakdown (A3, 含下鑽) ----------
class CategoryBreakdownItem(BaseModel):
    category_id: str
    category_name: str
    amount: float
    percentage: float
    has_children: bool
    is_self: bool = False  # True = 本節點自身直接掛的交易,未再細分到任何子分類


class CategoryBreakdownOut(BaseModel):
    type: EntryType
    total: float
    items: list[CategoryBreakdownItem]


class TagBreakdownItem(BaseModel):
    tag_id: str
    name: str
    total_amount: float
    transaction_count: int


class TagBreakdownOut(BaseModel):
    items: list[TagBreakdownItem]
    type: EntryType
    start_date: date
    end_date: date
PYEOF
echo "    schemas_ledger.py 覆寫完成"

# -----------------------------------------------------------------------
# ledger-frontend/src/components/CategoryBreakdownChart.vue
# -----------------------------------------------------------------------
cat > ledger-frontend/src/components/CategoryBreakdownChart.vue << 'VUEEOF'
<script setup lang="ts">
import { ref, nextTick, onMounted, onBeforeUnmount, watch } from 'vue'
import Chart from 'chart.js/auto'
import { fetchCategoryBreakdown } from '@/api/ledgerApi'
import type { CategoryBreakdownOut, EntryType } from '@/types/ledger'

const props = withDefaults(defineProps<{ type?: EntryType; startDate: string; endDate: string }>(), {
  type: 'expense',
})

const breadcrumb = ref<{ id: string; name: string }[]>([])
const canvasRef = ref<HTMLCanvasElement | null>(null)
const data = ref<CategoryBreakdownOut | null>(null)
const errorMsg = ref('')
let chartInstance: Chart | null = null

const PALETTE = [
  '#4F46E5', '#059669', '#D97706', '#DC2626', '#7C3AED',
  '#0891B2', '#DB2777', '#65A30D', '#EA580C', '#4338CA',
]
// 「本分類直接交易(未再細分)」固定用中性灰,跟一般子分類的彩色區隔開來
const SELF_COLOR = '#9CA3AF'

function formatCurrency(v: number): string {
  return v.toLocaleString('zh-TW', { style: 'currency', currency: 'TWD', maximumFractionDigits: 0 })
}

function currentParentId(): string | null {
  return breadcrumb.value.length ? breadcrumb.value[breadcrumb.value.length - 1].id : null
}

async function loadAndRender() {
  errorMsg.value = ''
  try {
    // rollup 固定 true:UI 不再提供切換,子分類一律捲到頂層
    data.value = await fetchCategoryBreakdown(props.type, props.startDate, props.endDate, currentParentId())
    await nextTick()
    requestAnimationFrame(renderChart) // 等瀏覽器完成 layout,避免 canvas 量到 0x0
  } catch {
    errorMsg.value = '載入分類統計失敗,請稍後再試'
  }
}

function drillInto(index: number) {
  if (!data.value) return
  const item = data.value.items[index]
  if (!item.has_children) return
  breadcrumb.value.push({ id: item.category_id, name: item.category_name })
  loadAndRender()
}

function goToLevel(index: number) {
  breadcrumb.value = index < 0 ? [] : breadcrumb.value.slice(0, index + 1)
  loadAndRender()
}

function renderChart() {
  if (!canvasRef.value || !data.value) return
  chartInstance?.destroy()

  const items = data.value.items
  chartInstance = new Chart(canvasRef.value, {
    type: 'doughnut',
    data: {
      labels: items.map((i) => i.category_name),
      datasets: [
        {
          data: items.map((i) => i.amount),
          backgroundColor: items.map((i, idx) => (i.is_self ? SELF_COLOR : PALETTE[idx % PALETTE.length])),
          borderWidth: 1,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      onClick: (_evt, elements) => {
        if (elements.length > 0) drillInto(elements[0].index)
      },
      onHover: (evt, elements) => {
        const target = evt.native?.target as HTMLElement | undefined
        if (!target) return
        const hoveringDrillable = elements.length > 0 && items[elements[0].index]?.has_children
        target.style.cursor = hoveringDrillable ? 'pointer' : 'default'
      },
      plugins: {
        legend: { position: 'bottom' },
        tooltip: {
          callbacks: {
            label: (ctx) => {
              const item = items[ctx.dataIndex]
              const hint = item.has_children ? '(點擊查看子分類)' : ''
              return `${item.category_name}: ${formatCurrency(item.amount)} (${item.percentage}%) ${hint}`
            },
          },
        },
      },
    },
  })
}

onMounted(loadAndRender)
onBeforeUnmount(() => chartInstance?.destroy())
watch(() => [props.type, props.startDate, props.endDate], () => {
  breadcrumb.value = []
  loadAndRender()
})
</script>

<template>
  <div class="category-breakdown">
    <nav v-if="breadcrumb.length > 0" class="breadcrumb">
      <button class="crumb" @click="goToLevel(-1)">頂層</button>
      <template v-for="(crumb, idx) in breadcrumb" :key="crumb.id">
        <span class="sep">›</span>
        <button class="crumb" :class="{ current: idx === breadcrumb.length - 1 }" @click="goToLevel(idx)">
          {{ crumb.name }}
        </button>
      </template>
    </nav>
    <p v-if="errorMsg" class="error">{{ errorMsg }}</p>
    <p v-else-if="data && data.items.length === 0" class="empty">此期間無資料</p>
    <div v-else class="chart-wrap"><canvas ref="canvasRef"></canvas></div>
    <p v-if="data && data.items.length > 0" class="total">總計:{{ formatCurrency(data.total) }}</p>
  </div>
</template>

<style scoped>
.category-breakdown { display: flex; flex-direction: column; height: 100%; }

.breadcrumb {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 12px;
  flex-wrap: wrap;
}
.crumb {
  background: #f3f4f6;
  border: 1px solid #e5e7eb;
  border-radius: 999px;
  padding: 4px 12px;
  font-size: 0.8rem;
  color: #4b5563;
  cursor: pointer;
  transition: background 0.15s;
}
.crumb:hover { background: #e5e7eb; }
.crumb.current { background: #4F46E5; border-color: #4F46E5; color: #fff; cursor: default; }
.sep { color: #9ca3af; font-size: 0.8rem; }

.chart-wrap { position: relative; height: 320px; }
.error { color: #dc2626; }
.empty { color: #6b7280; text-align: center; padding: 2rem 0; }
.total { text-align: center; font-weight: 600; margin-top: 0.5rem; }
</style>
VUEEOF
echo "    CategoryBreakdownChart.vue 覆寫完成"

echo "===> [4/4] Commit 本次功能異動"
git add \
  ledger-backend/app/routers/stats.py \
  ledger-backend/app/schemas_ledger.py \
  ledger-frontend/src/components/CategoryBreakdownChart.vue

if git diff --cached --quiet; then
  echo "⚠️  沒有偵測到檔案差異,可能 server 內容已經是這個版本,略過 commit"
else
  git commit -m "fix: 分類統計下鑽補「本分類直接交易」項目,修正子分類加總與頂層總額不符"
fi

echo ""
echo "===> 完成,確認 commit 是否真的產生:"
git log --oneline -3
