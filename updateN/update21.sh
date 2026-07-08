#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
FRONTEND=ledger-frontend
[ -d "$BACKEND" ] && [ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

# ========== Backend: transactions.py 加 min_amount/max_amount ==========
python3 << 'PYEOF'
path = "ledger-backend/app/routers/transactions.py"
with open(path) as f:
    content = f.read()

old = """@router.get("", response_model=list[TransactionOut])
def list_transactions(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    account_id: str | None = Query(default=None),
    category_id: str | None = Query(default=None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(Transaction).filter(Transaction.household_id == current_user.household_id)

    if start_date is not None:
        query = query.filter(Transaction.date >= start_date)
    if end_date is not None:
        query = query.filter(Transaction.date <= end_date)
    if account_id is not None:
        query = query.filter(Transaction.account_id == account_id)
    if category_id is not None:
        query = query.filter(Transaction.category_id == category_id)

    return query.order_by(Transaction.date.desc()).all()"""

new = """@router.get("", response_model=list[TransactionOut])
def list_transactions(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    account_id: str | None = Query(default=None),
    category_id: str | None = Query(default=None),
    min_amount: float | None = Query(default=None, ge=0),
    max_amount: float | None = Query(default=None, ge=0),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if min_amount is not None and max_amount is not None and min_amount > max_amount:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="最低金額不能大於最高金額")

    query = db.query(Transaction).filter(Transaction.household_id == current_user.household_id)

    if start_date is not None:
        query = query.filter(Transaction.date >= start_date)
    if end_date is not None:
        query = query.filter(Transaction.date <= end_date)
    if account_id is not None:
        query = query.filter(Transaction.account_id == account_id)
    if category_id is not None:
        query = query.filter(Transaction.category_id == category_id)
    if min_amount is not None:
        query = query.filter(Transaction.amount >= min_amount)
    if max_amount is not None:
        query = query.filter(Transaction.amount <= max_amount)

    return query.order_by(Transaction.date.desc()).all()"""

if old not in content:
    raise SystemExit("❌ list_transactions 錨點不符,請人工檢查")
content = content.replace(old, new, 1)
with open(path, "w") as f:
    f.write(content)
print("✅ transactions.py 已加入 min_amount/max_amount 篩選")
PYEOF

# ========== Frontend: types/ledger.ts ==========
python3 << 'PYEOF'
path = "ledger-frontend/src/types/ledger.ts"
with open(path) as f:
    content = f.read()

old = """export interface TransactionFilters {
  start_date?: string
  end_date?: string
  account_id?: string
  category_id?: string
}"""
new = """export interface TransactionFilters {
  start_date?: string
  end_date?: string
  account_id?: string
  category_id?: string
  min_amount?: number
  max_amount?: number
}"""
if old not in content:
    raise SystemExit("❌ TransactionFilters 錨點不符")
content = content.replace(old, new, 1)
with open(path, "w") as f:
    f.write(content)
print("✅ types/ledger.ts 已加入 min_amount/max_amount")
PYEOF

# ========== Frontend: TransactionList.vue ==========
python3 << 'PYEOF'
path = "ledger-frontend/src/components/TransactionList.vue"
with open(path) as f:
    content = f.read()

replacements = [
    ("""const filterAccountId = ref('')
const filterCategoryId = ref('')""",
     """const filterAccountId = ref('')
const filterCategoryId = ref('')
const filterMinAmount = ref<number | null>(null)
const filterMaxAmount = ref<number | null>(null)"""),

    ("""    transactions.value = await fetchTransactions({
      start_date: filterStartDate.value || undefined,
      end_date: filterEndDate.value || undefined,
      account_id: filterAccountId.value || undefined,
      category_id: filterCategoryId.value || undefined,
    })""",
     """    transactions.value = await fetchTransactions({
      start_date: filterStartDate.value || undefined,
      end_date: filterEndDate.value || undefined,
      account_id: filterAccountId.value || undefined,
      category_id: filterCategoryId.value || undefined,
      min_amount: filterMinAmount.value ?? undefined,
      max_amount: filterMaxAmount.value ?? undefined,
    })"""),

    ("""watch([filterStartDate, filterEndDate, filterAccountId, filterCategoryId], loadTransactions)""",
     """watch(
  [filterStartDate, filterEndDate, filterAccountId, filterCategoryId, filterMinAmount, filterMaxAmount],
  loadTransactions
)"""),

    ("""      <select v-model="filterCategoryId" class="filter-input">
        <option value="">所有分類</option>
        <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
      </select>
    </div>""",
     """      <select v-model="filterCategoryId" class="filter-input">
        <option value="">所有分類</option>
        <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
      </select>
      <input
        v-model.number="filterMinAmount"
        type="number"
        min="0"
        placeholder="最低金額"
        class="filter-input"
        style="width: 100px"
      />
      <span style="color: #6b7a74">至</span>
      <input
        v-model.number="filterMaxAmount"
        type="number"
        min="0"
        placeholder="最高金額"
        class="filter-input"
        style="width: 100px"
      />
    </div>"""),

    (""".tag-chip {
  display: inline-block;
  background: #fef3c7;
  color: #92400e;
  border: 1px solid #fde68a;
  border-radius: 999px;
  padding: 2px 10px;
  font-size: 11px;
  font-weight: 600;
}""",
     """.tag-chip {
  display: inline-block;
  background: #fef3c7;
  color: #92400e;
  border: 1px solid #fde68a;
  border-radius: 999px;
  padding: 4px 12px;
  font-size: 14px;
  font-weight: 600;
}"""),
]

for old, new in replacements:
    if old not in content:
        raise SystemExit(f"❌ 內容不符,請人工檢查以下錨點:\n{old[:80]}...")
    content = content.replace(old, new, 1)

with open(path, "w") as f:
    f.write(content)
print("✅ TransactionList.vue 已加入金額範圍篩選 + 消費品項字體放大")
PYEOF

git add -A
git commit -m "feat: 交易紀錄新增金額範圍篩選(搭配既有分類/日期篩選),消費品項標籤字體放大"
echo "✅ 已 commit,請 push + deploy"