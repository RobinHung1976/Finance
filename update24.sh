#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
[ -d "$BACKEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

python3 << 'PYEOF'
path = "ledger-backend/app/services/excel_transfer.py"
with open(path) as f:
    content = f.read()

old = '''import re
from datetime import datetime, date, timedelta
from io import BytesIO

import openpyxl
from openpyxl import Workbook
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Account, Category, Transaction, EntryType

MONTH_SHEET_RE = re.compile(r"^(\\d{1,2})月$")
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
                "category_top": _to_clean_str(category_cell.value),
                "item": _to_clean_str(item_cell.value),
                "amount_raw": amount_cell.value,
            })
    return rows


def _to_clean_str(value) -> str | None:
    """儲存格內容可能是 str/int/float(使用者誤填數字),統一轉字串再 strip。"""
    if value is None:
        return None
    text = str(value).strip()
    return text or None'''

new = '''from datetime import datetime, date, timedelta
from io import BytesIO

import openpyxl
from openpyxl import Workbook
from openpyxl.worksheet.worksheet import Worksheet
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Account, Category, Transaction, EntryType

EXCEL_EPOCH = datetime(1899, 12, 30)
REQUIRED_HEADERS = {"日期", "類別", "項目", "金額"}


def _to_clean_str(value) -> str | None:
    """儲存格內容可能是 str/int/float(使用者誤填數字),統一轉字串再 strip。"""
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _excel_serial_to_date(value) -> date:
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    return (EXCEL_EPOCH + timedelta(days=float(value))).date()


def _find_header_row(ws: Worksheet) -> tuple[int, dict[str, int]] | tuple[None, None]:
    """掃描前 10 列,找出同時包含「日期/類別/項目/金額」四個標題文字的列,
    回傳 (標題列列號, {標題文字: 欄位號}),沒找到回傳 (None, None)。"""
    scan_rows = min(10, ws.max_row)
    for row in ws.iter_rows(min_row=1, max_row=scan_rows):
        found: dict[str, int] = {}
        for cell in row:
            label = _to_clean_str(cell.value)
            if label in REQUIRED_HEADERS and label not in found:
                found[label] = cell.column
        if len(found) == len(REQUIRED_HEADERS):
            return row[0].row, found
    return None, None


def parse_month_sheets(file_bytes: bytes) -> list[dict]:
    """掃描所有工作表,自動偵測含「日期/類別/項目/金額」標題列的表(不限工作表名稱/欄位排列),
    找不到完整標題列的工作表(如總表、類別下拉選單來源)自動跳過。"""
    wb = openpyxl.load_workbook(BytesIO(file_bytes), data_only=True)
    rows: list[dict] = []

    for sheet_name in wb.sheetnames:
        ws = wb[sheet_name]
        header_row_idx, col_map = _find_header_row(ws)
        if header_row_idx is None:
            continue

        date_col = col_map["日期"]
        category_col = col_map["類別"]
        item_col = col_map["項目"]
        amount_col = col_map["金額"]

        for row_idx in range(header_row_idx + 1, ws.max_row + 1):
            date_cell = ws.cell(row=row_idx, column=date_col)
            category_cell = ws.cell(row=row_idx, column=category_col)
            item_cell = ws.cell(row=row_idx, column=item_col)
            amount_cell = ws.cell(row=row_idx, column=amount_col)

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
    return rows'''

if old not in content:
    raise SystemExit("❌ 內容不符,請人工檢查 excel_transfer.py 現況(可能上次修改後結構有異動)")
content = content.replace(old, new, 1)

with open(path, "w") as f:
    f.write(content)
print("✅ excel_transfer.py: parse_month_sheets 改成自動偵測標題列,不限工作表名稱/欄位排列")
PYEOF

git add -A
git commit -m "feat: 匯入功能改為自動偵測標題列位置與欄位排列,不再限定工作表命名為 N月 或固定欄位 C:F"
echo "✅ 已 commit,請 push + deploy"