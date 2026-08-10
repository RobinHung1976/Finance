#!/usr/bin/env bash
set -euo pipefail

# ========================================
# update50.sh
# 新增:A9 最大單筆排行 API(GET /stats/top-transactions)
# 設計:比照 tag-breakdown 的 filter(start_date/end_date/type,選填+預設今年區間),
#      limit 可調(預設 5、上限 20),直接 join 帳戶/分類名稱回傳,不接進階篩選(帳戶/分類/消費品項篩選)
# ========================================

# ---- 0. 自動歸檔(固定寫法,與功能改動分開 commit) ----
CURRENT=50
mkdir -p "update${CURRENT}"
for f in update*.sh; do
  [ "$f" = "update${CURRENT}.sh" ] && continue
  [ -f "$f" ] || continue
  git mv "$f" "update${CURRENT}/$f" 2>/dev/null || mv "$f" "update${CURRENT}/$f"
done
git add -A
if ! git diff --cached --quiet; then
  git commit -m "chore: 歸檔已執行的 updateN.sh 腳本"
fi

# ---- 1. 前置驗證:確認 update49.sh 已套用(tag-breakdown 已是選填 date | None) ----
if ! grep -q 'start_date: date | None = Query(default=None, description="預設今年 1/1")' ledger-backend/app/routers/stats.py; then
  echo "❌ stats.py 尚未包含 update49.sh 的改動(tag-breakdown 選填化),請先確認 update49.sh 是否已套用" >&2
  exit 1
fi

# ---- 2. schemas_ledger.py:新增 TopTransactionItem / TopTransactionsOut ----
python3 << 'PYEOF'
import sys

path = "ledger-backend/app/schemas_ledger.py"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

old = '''class TagBreakdownOut(BaseModel):
    items: list[TagBreakdownItem]
    type: EntryType
    start_date: date
    end_date: date'''

new = '''class TagBreakdownOut(BaseModel):
    items: list[TagBreakdownItem]
    type: EntryType
    start_date: date
    end_date: date


# ---------- Stats: Top Transactions (A9) ----------
class TopTransactionItem(BaseModel):
    id: str
    amount: float
    date: date
    note: str | None
    account_name: str
    category_name: str


class TopTransactionsOut(BaseModel):
    type: EntryType
    start_date: date
    end_date: date
    items: list[TopTransactionItem]'''

count = content.count(old)
if count != 1:
    print(f"❌ schemas_ledger.py 比對字串出現 {count} 次(預期 1 次),中止,未寫入任何檔案", file=sys.stderr)
    sys.exit(1)

content = content.replace(old, new)
with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ schemas_ledger.py 修改完成")
PYEOF

# ---- 3. stats.py:新增 GET /stats/top-transactions ----
python3 << 'PYEOF'
import sys

path = "ledger-backend/app/routers/stats.py"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# 3a. import 補上 Account + 新 schema
old_import = "from app.models import Tag, TransactionTag\nfrom app.schemas_ledger import TagBreakdownItem, TagBreakdownOut"
new_import = ("from app.models import Tag, TransactionTag, Account\n"
              "from app.schemas_ledger import (\n"
              "    TagBreakdownItem,\n"
              "    TagBreakdownOut,\n"
              "    TopTransactionItem,\n"
              "    TopTransactionsOut,\n"
              ")")

count = content.count(old_import)
if count != 1:
    print(f"❌ stats.py import 比對字串出現 {count} 次(預期 1 次),中止,未寫入任何檔案", file=sys.stderr)
    sys.exit(1)
content = content.replace(old_import, new_import)

# 3b. 在檔案尾端(tag_breakdown 函式結尾)後新增 top_transactions 路由
old_tail = '''    return TagBreakdownOut(
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
    )'''

new_tail = old_tail + '''


@router.get("/top-transactions", response_model=TopTransactionsOut)
def top_transactions(
    type: EntryType = Query(EntryType.expense),
    start_date: date | None = Query(default=None, description="預設今年 1/1"),
    end_date: date | None = Query(default=None, description="預設今天"),
    limit: int = Query(5, ge=1, le=20),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """A9:最大單筆排行,直接 join 帳戶/分類名稱回傳,不接進階篩選(帳戶/分類/消費品項)。"""
    start, end = _resolve_range(start_date, end_date)

    rows = (
        db.query(
            Transaction,
            Account.name.label("account_name"),
            Category.name.label("category_name"),
        )
        .join(Account, Account.id == Transaction.account_id)
        .join(Category, Category.id == Transaction.category_id)
        .filter(
            Transaction.household_id == current_user.household_id,
            Transaction.type == type,
            Transaction.date >= start,
            Transaction.date <= end,
        )
        .order_by(Transaction.amount.desc())
        .limit(limit)
        .all()
    )

    return TopTransactionsOut(
        type=type,
        start_date=start,
        end_date=end,
        items=[
            TopTransactionItem(
                id=t.id,
                amount=float(t.amount),
                date=t.date,
                note=t.note,
                account_name=account_name,
                category_name=category_name,
            )
            for t, account_name, category_name in rows
        ],
    )'''

count = content.count(old_tail)
if count != 1:
    print(f"❌ stats.py 尾端比對字串出現 {count} 次(預期 1 次),中止,未寫入任何檔案", file=sys.stderr)
    sys.exit(1)
content = content.replace(old_tail, new_tail)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ stats.py 修改完成")
PYEOF

# ---- 4. commit(feat,與歸檔分開) ----
git add ledger-backend/app/schemas_ledger.py ledger-backend/app/routers/stats.py
git commit -m "feat: 新增 A9 最大單筆排行 API(GET /stats/top-transactions)"

# ---- 5. 確認 commit 真的產生(務必執行,不能只看終端機有無錯誤字樣) ----
echo "---- git log --oneline -1 ----"
git log --oneline -1
