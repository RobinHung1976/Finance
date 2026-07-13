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
