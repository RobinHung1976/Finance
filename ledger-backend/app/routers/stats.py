from datetime import date
from dateutil.relativedelta import relativedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models import EntryType, Transaction, User
from app.schemas_ledger import MonthlySummary, MonthlyTrendOut

router = APIRouter(prefix="/stats", tags=["stats"])


@router.get("/monthly-trend", response_model=MonthlyTrendOut)
def monthly_trend(
    months: int = Query(default=12, ge=1, le=36, description="回溯月數"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    近 N 個月收支趨勢 + 結餘計算(A1 + A2)。
    以資料庫層 date_trunc('month', ...) group by,避免把整年交易拉回 Python 迭代。
    """
    today = date.today()
    # 回溯 N 個月的起點(含當月),例如 months=12 -> 從 11 個月前的月初開始
    range_start = (today.replace(day=1) - relativedelta(months=months - 1))

    month_bucket = func.date_trunc("month", Transaction.date).label("month_bucket")
    rows = (
        db.query(
            month_bucket,
            Transaction.type,
            func.sum(Transaction.amount).label("total"),
        )
        .filter(
            Transaction.household_id == current_user.household_id,
            Transaction.date >= range_start,
        )
        .group_by(month_bucket, Transaction.type)
        .order_by(month_bucket)
        .all()
    )

    # 先建立完整月份骨架(缺資料的月份補 0),避免前端圖表出現斷點
    buckets: dict[str, dict[str, float]] = {}
    cursor = range_start
    for _ in range(months):
        key = cursor.strftime("%Y-%m")
        buckets[key] = {"income": 0.0, "expense": 0.0}
        cursor = cursor + relativedelta(months=1)

    for row in rows:
        key = row.month_bucket.strftime("%Y-%m")
        if key not in buckets:
            continue  # 理論上不會發生,防禦性檢查
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
