#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
[ -d "$BACKEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

python3 << 'PYEOF'
path = "ledger-backend/app/services/excel_transfer.py"
with open(path) as f:
    content = f.read()

old = """def parse_month_sheets(file_bytes: bytes) -> list[dict]:
    \"\"\"只解析 N月 分頁,總表/類別分頁自動略過。\"\"\"
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
    return rows"""

new = """def parse_month_sheets(file_bytes: bytes) -> list[dict]:
    \"\"\"只解析 N月 分頁,總表/類別分頁自動略過。\"\"\"
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
                "category_top": _to_clean_str(category_cell.value),
                "item": _to_clean_str(item_cell.value),
                "amount_raw": amount_cell.value,
            })
    return rows


def _to_clean_str(value) -> str | None:
    \"\"\"儲存格內容可能是 str/int/float(使用者誤填數字),統一轉字串再 strip。\"\"\"
    if value is None:
        return None
    text = str(value).strip()
    return text or None"""

if old not in content:
    raise SystemExit("❌ 內容不符,請人工檢查 excel_transfer.py 現況")
content = content.replace(old, new)
with open(path, "w") as f:
    f.write(content)
print("✅ excel_transfer.py: parse_month_sheets 型別防呆已修正")
PYEOF

python3 << 'PYEOF'
path = "ledger-backend/app/routers/transactions_transfer.py"
with open(path) as f:
    content = f.read()

old = """    content = await file.read()
    if len(content) > MAX_IMPORT_SIZE:
        raise HTTPException(413, "檔案過大")
    result = process_import(db, current_user.household_id, current_user.id, account_id, content, dry_run=True)
    return ImportPreviewResponse(**result)"""

new = """    content = await file.read()
    if len(content) > MAX_IMPORT_SIZE:
        raise HTTPException(413, "檔案過大")
    try:
        result = process_import(db, current_user.household_id, current_user.id, account_id, content, dry_run=True)
    except Exception as e:
        raise HTTPException(400, f"檔案解析失敗:{e}")
    return ImportPreviewResponse(**result)"""

if old not in content:
    raise SystemExit("❌ 內容不符,請人工檢查 transactions_transfer.py 現況")
content = content.replace(old, new)
with open(path, "w") as f:
    f.write(content)
print("✅ transactions_transfer.py: import_preview 例外處理已加上")
PYEOF

git add -A
git commit -m "fix: 項目/類別欄位非字串型別(如誤填數字369)導致 .strip() 拋例外,統一轉字串處理並補上例外攔截"
echo "✅ 已 commit,請執行 'git push origin main',再到 server 跑 ./deploy.sh"