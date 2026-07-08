#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
FRONTEND=ledger-frontend
[ -d "$BACKEND" ] && [ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

# ---------- backend: stats.py(改吃 start_date/end_date,移除 months) ----------
cat > "$BACKEND/app/routers/stats.py" << 'EOF'
from datetime import date
from dateutil.relativedelta import relativedelta

from fastapi import APIRouter, Depends, HTTPException, Query, status
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

    total = sum(float(r["amount"]) for r in rows)
    items = [
        CategoryBreakdownItem(
            category_id=str(r["category_id"]),
            category_name=r["category_name"],
            amount=float(r["amount"]),
            percentage=round(float(r["amount"]) / total * 100, 2) if total > 0 else 0.0,
            has_children=bool(r["has_children"]),
        )
        for r in rows
    ]
    return CategoryBreakdownOut(type=type, total=total, items=items)
EOF

# ---------- frontend: api/ledger.ts(改吃 start_date/end_date) ----------
python3 << 'PYEOF'
path = "ledger-frontend/src/api/ledger.ts"
with open(path) as f:
    content = f.read()

old = """export function fetchMonthlyTrend(months = 12) {
  return apiClient.get<MonthlyTrendOut>('/stats/monthly-trend', { params: { months } }).then((r) => r.data)
}

export function fetchCategoryBreakdown(
  type: EntryType = 'expense',
  months = 1,
  rollup = true,
  parentId: string | null = null,
) {
  return apiClient
    .get<CategoryBreakdownOut>('/stats/category-breakdown', {
      params: { type, months, rollup, parent_id: parentId },
    })
    .then((r) => r.data)
}"""

new = """export function fetchMonthlyTrend(startDate?: string, endDate?: string) {
  return apiClient
    .get<MonthlyTrendOut>('/stats/monthly-trend', {
      params: { start_date: startDate, end_date: endDate },
    })
    .then((r) => r.data)
}

export function fetchCategoryBreakdown(
  type: EntryType = 'expense',
  startDate?: string,
  endDate?: string,
  parentId: string | null = null,
) {
  return apiClient
    .get<CategoryBreakdownOut>('/stats/category-breakdown', {
      params: { type, start_date: startDate, end_date: endDate, parent_id: parentId },
    })
    .then((r) => r.data)
}"""

if old not in content:
    raise SystemExit("❌ ledger.ts 舊內容不符,請人工檢查 fetchMonthlyTrend/fetchCategoryBreakdown")
content = content.replace(old, new)
with open(path, "w") as f:
    f.write(content)
print("✅ api/ledger.ts 已改為 start_date/end_date")
PYEOF

# ---------- frontend: 新增 DateRangePicker.vue ----------
cat > "$FRONTEND/src/components/DateRangePicker.vue" << 'EOF'
<script setup lang="ts">
const startDate = defineModel<string>('startDate', { required: true })
const endDate = defineModel<string>('endDate', { required: true })

function thisYear() {
  const today = new Date()
  startDate.value = `${today.getFullYear()}-01-01`
  endDate.value = today.toISOString().slice(0, 10)
}
</script>

<template>
  <div class="date-range">
    <input type="date" v-model="startDate" :max="endDate" />
    <span class="sep">~</span>
    <input type="date" v-model="endDate" :min="startDate" />
    <button class="reset-btn" @click="thisYear">今年</button>
  </div>
</template>

<style scoped>
.date-range { display: flex; align-items: center; gap: 6px; font-size: 0.85rem; }
.date-range input[type='date'] {
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  padding: 4px 8px;
  font-size: 0.85rem;
}
.sep { color: #9ca3af; }
.reset-btn {
  background: #f3f4f6;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  padding: 4px 10px;
  font-size: 0.8rem;
  color: #4b5563;
  cursor: pointer;
}
.reset-btn:hover { background: #e5e7eb; }
</style>
EOF

# ---------- frontend: MonthlyTrendChart.vue(props 改 startDate/endDate) ----------
cat > "$FRONTEND/src/components/MonthlyTrendChart.vue" << 'EOF'
<script setup lang="ts">
import { ref, nextTick, onMounted, onBeforeUnmount, watch } from 'vue'
import Chart from 'chart.js/auto'
import { fetchMonthlyTrend } from '@/api/ledger'
import type { MonthlyTrendOut } from '@/types/ledger'

const props = defineProps<{ startDate: string; endDate: string }>()

const loading = ref(true)
const error = ref<string | null>(null)
const data = ref<MonthlyTrendOut | null>(null)

const canvasRef = ref<HTMLCanvasElement | null>(null)
let chartInstance: Chart | null = null

function formatCurrency(value: number | null): string {
  if (value === null) return '-'
  return value.toLocaleString('zh-TW', { style: 'currency', currency: 'TWD', maximumFractionDigits: 0 })
}

function renderChart() {
  if (!canvasRef.value || !data.value) return

  chartInstance?.destroy()

  const labels = data.value.months.map((m) => m.month)
  const incomeData = data.value.months.map((m) => m.income)
  const expenseData = data.value.months.map((m) => m.expense)

  chartInstance = new Chart(canvasRef.value, {
    type: 'line',
    data: {
      labels,
      datasets: [
        {
          label: '收入',
          data: incomeData,
          borderColor: '#1f5f4f',
          backgroundColor: '#1f5f4f22',
          tension: 0.3,
          fill: true,
        },
        {
          label: '支出',
          data: expenseData,
          borderColor: '#b3432b',
          backgroundColor: '#b3432b22',
          tension: 0.3,
          fill: true,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { position: 'top' },
        tooltip: {
          callbacks: {
            label: (ctx) => `${ctx.dataset.label}: ${formatCurrency(ctx.parsed.y)}`,
          },
        },
      },
      scales: {
        y: {
          ticks: { callback: (v) => formatCurrency(Number(v)) },
        },
      },
    },
  })
}

async function loadData() {
  loading.value = true
  error.value = null
  try {
    data.value = await fetchMonthlyTrend(props.startDate, props.endDate)
    await nextTick()
    requestAnimationFrame(renderChart) // 等瀏覽器完成 layout,避免 canvas 量到 0x0
  } catch (e) {
    error.value = '統計資料載入失敗,請稍後再試'
    console.error(e)
  } finally {
    loading.value = false
  }
}

watch(() => [props.startDate, props.endDate], loadData)

onMounted(loadData)
onBeforeUnmount(() => chartInstance?.destroy())
</script>

<template>
  <div class="trend-card">
    <div v-if="loading" class="state-msg">載入中…</div>
    <div v-else-if="error" class="state-msg error">{{ error }}</div>
    <template v-else-if="data">
      <div class="summary-row">
        <div class="summary-item">
          <span class="label">總收入</span>
          <span class="value income">{{ formatCurrency(data.total_income) }}</span>
        </div>
        <div class="summary-item">
          <span class="label">總支出</span>
          <span class="value expense">{{ formatCurrency(data.total_expense) }}</span>
        </div>
        <div class="summary-item">
          <span class="label">結餘</span>
          <span class="value" :class="data.total_balance >= 0 ? 'income' : 'expense'">
            {{ formatCurrency(data.total_balance) }}
          </span>
        </div>
      </div>
      <div class="chart-wrap">
        <canvas ref="canvasRef"></canvas>
      </div>
    </template>
  </div>
</template>

<style scoped>
.trend-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  padding: 20px;
}

.state-msg {
  text-align: center;
  padding: 40px 0;
  color: #6b7a74;
}

.state-msg.error {
  color: var(--color-danger);
}

.summary-row {
  display: flex;
  gap: 16px;
  margin-bottom: 20px;
  flex-wrap: wrap;
}

.summary-item {
  flex: 1;
  min-width: 120px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.summary-item .label {
  font-size: 12px;
  color: #6b7a74;
}

.summary-item .value {
  font-size: 20px;
  font-weight: 600;
}

.value.income {
  color: var(--color-primary);
}

.value.expense {
  color: var(--color-danger);
}

.chart-wrap {
  height: 320px;
  position: relative;
}
</style>
EOF

# ---------- frontend: CategoryBreakdownChart.vue(props 改 startDate/endDate) ----------
python3 << 'PYEOF'
path = "ledger-frontend/src/components/CategoryBreakdownChart.vue"
with open(path) as f:
    content = f.read()

old_props = """const props = withDefaults(defineProps<{ type?: EntryType; months?: number }>(), {
  type: 'expense',
  months: 1,
})"""
new_props = """const props = withDefaults(defineProps<{ type?: EntryType; startDate: string; endDate: string }>(), {
  type: 'expense',
})"""
if old_props not in content:
    raise SystemExit("❌ CategoryBreakdownChart.vue props 不符")
content = content.replace(old_props, new_props)

old_fetch = "data.value = await fetchCategoryBreakdown(props.type, props.months, true, currentParentId())"
new_fetch = "data.value = await fetchCategoryBreakdown(props.type, props.startDate, props.endDate, currentParentId())"
if old_fetch not in content:
    raise SystemExit("❌ CategoryBreakdownChart.vue fetch 呼叫不符")
content = content.replace(old_fetch, new_fetch)

old_watch = """watch(() => [props.type, props.months], () => {
  breadcrumb.value = []
  loadAndRender()
})"""
new_watch = """watch(() => [props.type, props.startDate, props.endDate], () => {
  breadcrumb.value = []
  loadAndRender()
})"""
if old_watch not in content:
    raise SystemExit("❌ CategoryBreakdownChart.vue watch 不符")
content = content.replace(old_watch, new_watch)

with open(path, "w") as f:
    f.write(content)
print("✅ CategoryBreakdownChart.vue 已改為 startDate/endDate")
PYEOF

# ---------- frontend: DashboardView.vue(新增日期區間狀態,傳給雙圖表,grid 改 3fr:2fr) ----------
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
import DateRangePicker from '@/components/DateRangePicker.vue'

const router = useRouter()
const auth = useAuthStore()

type Tab = 'stats' | 'transactions' | 'accounts' | 'categories'
const activeTab = ref<Tab>('stats')

// 統計頁日期區間,預設今年 1/1 ~ 今天,兩張圖表共用同一組區間
const today = new Date()
const startDate = ref(`${today.getFullYear()}-01-01`)
const endDate = ref(today.toISOString().slice(0, 10))

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
  <div style="max-width: 1000px; margin: 0 auto; padding: 32px 24px">
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
      <div v-if="activeTab === 'stats'">
        <div class="stats-toolbar">
          <DateRangePicker v-model:start-date="startDate" v-model:end-date="endDate" />
        </div>
        <div class="stats-grid">
          <div class="stats-panel">
            <h3>月收支趨勢</h3>
            <MonthlyTrendChart :start-date="startDate" :end-date="endDate" />
          </div>
          <div class="stats-panel">
            <h3>支出分類統計</h3>
            <CategoryBreakdownChart type="expense" :start-date="startDate" :end-date="endDate" />
          </div>
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

.stats-toolbar { display: flex; justify-content: flex-end; margin-bottom: 12px; }

/* 3fr:2fr — 折線圖需要橫向空間畫時間軸,圓餅圖不需要太寬 */
.stats-grid { display: grid; grid-template-columns: 3fr 2fr; gap: 1.5rem; align-items: stretch; }
/* 若想改上下堆疊,改成: grid-template-columns: 1fr; */

.stats-panel { background: #fff; border-radius: 8px; padding: 1rem; box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1); display: flex; flex-direction: column; }
.stats-panel h3 { margin: 0 0 12px; font-size: 15px; }
@media (max-width: 900px) { .stats-grid { grid-template-columns: 1fr; } }
</style>
EOF

echo "✅ 全部檔案已修正完成"
git add -A
git commit -m "feat: 統計頁日期區間選擇(預設今年)+ grid 改 3fr:2fr 改善折線圖寬度"
echo "✅ 已 commit,請執行 'git push origin main',再到 server 跑 ./deploy.sh"