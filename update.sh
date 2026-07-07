#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
FRONTEND=ledger-frontend

[ -d "$BACKEND" ] && [ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

cat > "$BACKEND/app/schemas_ledger.py" << 'EOF'
from datetime import date as date_type, datetime

from pydantic import BaseModel, Field, field_validator

from app.models import AccountType, EntryType


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


class TransactionOut(BaseModel):
    id: str
    account_id: str
    category_id: str
    amount: float
    type: EntryType
    date: date_type
    note: str | None
    user_id: str | None

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


# ---------- Stats: Category Breakdown (A3) ----------
class CategoryBreakdownItem(BaseModel):
    category_id: str
    category_name: str
    amount: float
    percentage: float


class CategoryBreakdownOut(BaseModel):
    type: EntryType
    total: float
    items: list[CategoryBreakdownItem]
EOF

cat > "$BACKEND/app/routers/stats.py" << 'EOF'
from datetime import date
from dateutil.relativedelta import relativedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, text
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models import EntryType, Transaction, User
from app.schemas_ledger import (
    MonthlySummary,
    MonthlyTrendOut,
    CategoryBreakdownItem,
    CategoryBreakdownOut,
)

router = APIRouter(prefix="/stats", tags=["stats"])


@router.get("/monthly-trend", response_model=MonthlyTrendOut)
def monthly_trend(
    months: int = Query(default=12, ge=1, le=36, description="回溯月數"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """近 N 個月收支趨勢 + 結餘計算(A1 + A2)。"""
    today = date.today()
    range_start = today.replace(day=1) - relativedelta(months=months - 1)

    month_bucket = func.date_trunc("month", Transaction.date).label("month_bucket")
    rows = (
        db.query(month_bucket, Transaction.type, func.sum(Transaction.amount).label("total"))
        .filter(
            Transaction.household_id == current_user.household_id,
            Transaction.date >= range_start,
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


# rollup=True: 子分類金額 Recursive CTE 捲到頂層分類
_CATEGORY_BREAKDOWN_ROLLUP_SQL = text("""
    WITH RECURSIVE cat_tree AS (
        SELECT id, id AS root_id, name AS root_name
        FROM categories
        WHERE household_id = :household_id AND parent_id IS NULL

        UNION ALL

        SELECT c.id, ct.root_id, ct.root_name
        FROM categories c
        JOIN cat_tree ct ON c.parent_id = ct.id
        WHERE c.household_id = :household_id
    )
    SELECT ct.root_id AS category_id, ct.root_name AS category_name,
           COALESCE(SUM(t.amount), 0) AS amount
    FROM cat_tree ct
    JOIN transactions t ON t.category_id = ct.id
    WHERE t.household_id = :household_id
      AND t.type = :entry_type
      AND t.date >= :start_date
      AND t.date <= :end_date
    GROUP BY ct.root_id, ct.root_name
    ORDER BY amount DESC
""")

# rollup=False: 保留原始分類層級,不捲層
_CATEGORY_BREAKDOWN_LEAF_SQL = text("""
    SELECT c.id AS category_id, c.name AS category_name,
           COALESCE(SUM(t.amount), 0) AS amount
    FROM categories c
    JOIN transactions t ON t.category_id = c.id
    WHERE t.household_id = :household_id
      AND t.type = :entry_type
      AND t.date >= :start_date
      AND t.date <= :end_date
    GROUP BY c.id, c.name
    ORDER BY amount DESC
""")


@router.get("/category-breakdown", response_model=CategoryBreakdownOut)
def category_breakdown(
    type: EntryType = Query(EntryType.expense),
    months: int = Query(1, ge=1, le=36, description="回溯月數,1=本月"),
    rollup: bool = Query(True, description="True=捲到頂層分類, False=保留原始分類層級"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    today = date.today()
    start_date = today.replace(day=1) - relativedelta(months=months - 1)
    end_date = today

    sql = _CATEGORY_BREAKDOWN_ROLLUP_SQL if rollup else _CATEGORY_BREAKDOWN_LEAF_SQL
    rows = db.execute(
        sql,
        {
            "household_id": current_user.household_id,
            "entry_type": type.value,
            "start_date": start_date,
            "end_date": end_date,
        },
    ).mappings().all()

    total = sum(float(r["amount"]) for r in rows)
    items = [
        CategoryBreakdownItem(
            category_id=r["category_id"],
            category_name=r["category_name"],
            amount=float(r["amount"]),
            percentage=round(float(r["amount"]) / total * 100, 2) if total > 0 else 0.0,
        )
        for r in rows
    ]

    return CategoryBreakdownOut(type=type, total=total, items=items)
EOF

cat > "$FRONTEND/src/types/ledger.ts" << 'EOF'
export type AccountType = 'cash' | 'credit_card' | 'bank'
export type EntryType = 'income' | 'expense'

export interface AccountOut {
  id: string
  name: string
  type: AccountType
  balance: number
  is_default_expense: boolean
}

export interface CategoryOut {
  id: string
  name: string
  parent_id: string | null
  type: EntryType
}

export interface TransactionOut {
  id: string
  account_id: string
  category_id: string
  amount: number
  type: EntryType
  date: string
  note: string | null
  user_id: string | null
}

export interface AccountCreatePayload {
  name: string
  type: AccountType
  balance: number
  is_default_expense: boolean
}

export interface CategoryCreatePayload {
  name: string
  parent_id: string | null
  type: EntryType
}

export interface TransactionCreatePayload {
  account_id: string
  category_id: string
  amount: number
  type: EntryType
  date: string
  note: string | null
}

export interface TransactionFilters {
  start_date?: string
  end_date?: string
  account_id?: string
  category_id?: string
}

// ---------- Stats ----------
export interface MonthlySummary {
  month: string
  income: number
  expense: number
  balance: number
}

export interface MonthlyTrendOut {
  months: MonthlySummary[]
  total_income: number
  total_expense: number
  total_balance: number
}

export interface CategoryBreakdownItem {
  category_id: string
  category_name: string
  amount: number
  percentage: number
}

export interface CategoryBreakdownOut {
  type: EntryType
  total: number
  items: CategoryBreakdownItem[]
}
EOF

cat > "$FRONTEND/src/api/ledger.ts" << 'EOF'
import { apiClient } from './client'
import type {
  AccountOut,
  AccountCreatePayload,
  CategoryOut,
  CategoryCreatePayload,
  TransactionOut,
  TransactionCreatePayload,
  TransactionFilters,
  MonthlyTrendOut,
  CategoryBreakdownOut,
  EntryType,
} from '@/types/ledger'

// ---------- Accounts ----------
export function fetchAccounts() {
  return apiClient.get<AccountOut[]>('/accounts').then((r) => r.data)
}

export function createAccount(payload: AccountCreatePayload) {
  return apiClient.post<AccountOut>('/accounts', payload).then((r) => r.data)
}

export function updateAccount(id: string, payload: Partial<AccountCreatePayload>) {
  return apiClient.patch<AccountOut>(`/accounts/${id}`, payload).then((r) => r.data)
}

export function deleteAccount(id: string) {
  return apiClient.delete(`/accounts/${id}`)
}

// ---------- Categories ----------
export function fetchCategories() {
  return apiClient.get<CategoryOut[]>('/categories').then((r) => r.data)
}

export function createCategory(payload: CategoryCreatePayload) {
  return apiClient.post<CategoryOut>('/categories', payload).then((r) => r.data)
}

export function deleteCategory(id: string) {
  return apiClient.delete(`/categories/${id}`)
}

// ---------- Transactions ----------
export function fetchTransactions(filters: TransactionFilters = {}) {
  return apiClient.get<TransactionOut[]>('/transactions', { params: filters }).then((r) => r.data)
}

export function createTransaction(payload: TransactionCreatePayload) {
  return apiClient.post<TransactionOut>('/transactions', payload).then((r) => r.data)
}

export function updateTransaction(id: string, payload: Partial<TransactionCreatePayload>) {
  return apiClient.patch<TransactionOut>(`/transactions/${id}`, payload).then((r) => r.data)
}

export function deleteTransaction(id: string) {
  return apiClient.delete(`/transactions/${id}`)
}

// ---------- Stats ----------
export function fetchMonthlyTrend(months = 12) {
  return apiClient.get<MonthlyTrendOut>('/stats/monthly-trend', { params: { months } }).then((r) => r.data)
}

export function fetchCategoryBreakdown(type: EntryType = 'expense', months = 1, rollup = true) {
  return apiClient
    .get<CategoryBreakdownOut>('/stats/category-breakdown', { params: { type, months, rollup } })
    .then((r) => r.data)
}
EOF

cat > "$FRONTEND/src/components/CategoryBreakdownChart.vue" << 'EOF'
<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount, watch } from 'vue'
import Chart from 'chart.js/auto'
import { fetchCategoryBreakdown } from '@/api/ledger'
import type { CategoryBreakdownOut, EntryType } from '@/types/ledger'

const props = withDefaults(defineProps<{ type?: EntryType; months?: number }>(), {
  type: 'expense',
  months: 1,
})

const rollup = ref(true)
const canvasRef = ref<HTMLCanvasElement | null>(null)
const data = ref<CategoryBreakdownOut | null>(null)
const errorMsg = ref('')
let chartInstance: Chart | null = null

const PALETTE = [
  '#4F46E5', '#059669', '#D97706', '#DC2626', '#7C3AED',
  '#0891B2', '#DB2777', '#65A30D', '#EA580C', '#4338CA',
]

function formatCurrency(v: number): string {
  return v.toLocaleString('zh-TW', { style: 'currency', currency: 'TWD', maximumFractionDigits: 0 })
}

async function loadAndRender() {
  errorMsg.value = ''
  try {
    data.value = await fetchCategoryBreakdown(props.type, props.months, rollup.value)
    renderChart()
  } catch {
    errorMsg.value = '載入分類統計失敗,請稍後再試'
  }
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
          backgroundColor: items.map((_, idx) => PALETTE[idx % PALETTE.length]),
          borderWidth: 1,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { position: 'bottom' },
        tooltip: {
          callbacks: {
            label: (ctx) => {
              const item = items[ctx.dataIndex]
              return `${item.category_name}: ${formatCurrency(item.amount)} (${item.percentage}%)`
            },
          },
        },
      },
    },
  })
}

onMounted(loadAndRender)
onBeforeUnmount(() => chartInstance?.destroy())
watch(() => [props.type, props.months, rollup.value], loadAndRender)
</script>

<template>
  <div class="category-breakdown">
    <div class="toolbar">
      <label class="toggle">
        <input type="checkbox" v-model="rollup" />
        捲到頂層分類
      </label>
    </div>
    <p v-if="errorMsg" class="error">{{ errorMsg }}</p>
    <p v-else-if="data && data.items.length === 0" class="empty">此期間無資料</p>
    <div v-else class="chart-wrap"><canvas ref="canvasRef"></canvas></div>
    <p v-if="data && data.items.length > 0" class="total">總計:{{ formatCurrency(data.total) }}</p>
  </div>
</template>

<style scoped>
.category-breakdown { display: flex; flex-direction: column; height: 100%; }
.toolbar { text-align: right; margin-bottom: 0.5rem; }
.toggle { font-size: 0.85rem; cursor: pointer; user-select: none; }
.chart-wrap { flex: 1; position: relative; min-height: 260px; }
.error { color: #dc2626; }
.empty { color: #6b7280; text-align: center; padding: 2rem 0; }
.total { text-align: center; font-weight: 600; margin-top: 0.5rem; }
</style>
EOF

cat > "$FRONTEND/src/views/DashboardView.vue" << 'EOF'
<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import AccountList from '@/components/AccountList.vue'
import CategoryList from '@/components/CategoryList.vue'
import TransactionList from '@/components/TransactionList.vue'
import MonthlyTrendChart from '@/components/MonthlyTrendChart.vue'
import CategoryBreakdownChart from '@/components/CategoryBreakdownChart.vue'

const router = useRouter()
const auth = useAuthStore()

type Tab = 'stats' | 'transactions' | 'accounts' | 'categories'
const activeTab = ref<Tab>('stats')

const refreshKey = ref(0)
function handleReferenceDataChanged() {
  refreshKey.value += 1
}

function handleLogout() {
  auth.logout()
  router.push({ name: 'login' })
}
</script>

<template>
  <div style="max-width: 800px; margin: 0 auto; padding: 32px 24px">
    <header style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px">
      <h1 style="font-size: 20px; margin: 0">家庭理財</h1>
      <div style="display: flex; gap: 12px; align-items: center">
        <router-link to="/members" style="font-size: 13px; color: var(--color-primary); text-decoration: none">
          成員管理
        </router-link>
        <button class="btn-primary" style="width: auto; padding: 6px 14px; font-size: 13px" @click="handleLogout">
          登出
        </button>
      </div>
    </header>

    <nav class="tab-bar">
      <button :class="{ active: activeTab === 'stats' }" @click="activeTab = 'stats'">統計</button>
      <button :class="{ active: activeTab === 'transactions' }" @click="activeTab = 'transactions'">
        交易紀錄
      </button>
      <button :class="{ active: activeTab === 'accounts' }" @click="activeTab = 'accounts'">帳戶</button>
      <button :class="{ active: activeTab === 'categories' }" @click="activeTab = 'categories'">分類</button>
    </nav>

    <section style="margin-top: 20px">
      <div v-if="activeTab === 'stats'" class="stats-grid">
        <div class="stats-panel">
          <h3>月收支趨勢</h3>
          <MonthlyTrendChart />
        </div>
        <div class="stats-panel">
          <h3>支出分類統計</h3>
          <CategoryBreakdownChart type="expense" :months="1" />
        </div>
      </div>
      <TransactionList v-else-if="activeTab === 'transactions'" :refresh-key="refreshKey" />
      <AccountList v-else-if="activeTab === 'accounts'" @changed="handleReferenceDataChanged" />
      <CategoryList v-else-if="activeTab === 'categories'" @changed="handleReferenceDataChanged" />
    </section>
  </div>
</template>

<style scoped>
.tab-bar { display: flex; gap: 4px; border-bottom: 1px solid var(--color-border); }
.tab-bar button {
  background: none; border: none; padding: 10px 16px; font-size: 14px;
  color: #6b7a74; border-bottom: 2px solid transparent; margin-bottom: -1px; cursor: pointer;
}
.tab-bar button.active { color: var(--color-primary); border-bottom-color: var(--color-primary); font-weight: 600; }
.stats-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; }
.stats-panel { background: #fff; border-radius: 8px; padding: 1rem; box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1); }
.stats-panel h3 { margin: 0 0 12px; font-size: 15px; }
@media (max-width: 768px) { .stats-grid { grid-template-columns: 1fr; } }
</style>
EOF

echo "✅ 檔案已寫入完成"
git add -A
git commit -m "feat: A3 分類統計圓餅圖(rollup 切換)+ 統計分頁併排顯示"
echo "✅ 已 commit,請執行 'git push origin main',再到 server 跑 ./deploy.sh"
