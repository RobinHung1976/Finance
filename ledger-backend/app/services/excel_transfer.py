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
