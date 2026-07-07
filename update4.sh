#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
FRONTEND=ledger-frontend

[ -d "$BACKEND" ] && [ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

# ---------- backend: stats.py 只改 LEAF_SQL 語意(去除 parent_id 過濾) ----------
python3 << 'PYEOF'
import re

path = "ledger-backend/app/routers/stats.py"
with open(path) as f:
    content = f.read()

old_leaf = '''_CATEGORY_BREAKDOWN_LEAF_SQL = text("""
    SELECT c.id AS category_id, c.name AS category_name,
           COALESCE(SUM(t.amount), 0) AS amount,
           EXISTS (
               SELECT 1 FROM categories cc
               WHERE cc.parent_id = c.id AND cc.household_id = :household_id
           ) AS has_children
    FROM categories c
    JOIN transactions t ON t.category_id = c.id
    WHERE c.household_id = :household_id
      AND c.parent_id IS NOT DISTINCT FROM :root_parent_id
      AND t.household_id = :household_id
      AND t.type = :entry_type
      AND t.date >= :start_date
      AND t.date <= :end_date
    GROUP BY c.id, c.name
    ORDER BY amount DESC
""")'''

new_leaf = '''_CATEGORY_BREAKDOWN_LEAF_SQL = text("""
    -- leaf 模式:忽略階層,直接依交易實際使用的分類分組(不套 parent_id 過濾,
    -- 因為交易通常記在子分類上,頂層分類本身可能無直接交易)
    SELECT c.id AS category_id, c.name AS category_name,
           COALESCE(SUM(t.amount), 0) AS amount,
           EXISTS (
               SELECT 1 FROM categories cc
               WHERE cc.parent_id = c.id AND cc.household_id = :household_id
           ) AS has_children
    FROM categories c
    JOIN transactions t ON t.category_id = c.id
    WHERE c.household_id = :household_id
      AND t.household_id = :household_id
      AND t.type = :entry_type
      AND t.date >= :start_date
      AND t.date <= :end_date
    GROUP BY c.id, c.name
    ORDER BY amount DESC
""")'''

if old_leaf not in content:
    raise SystemExit("❌ LEAF_SQL 舊內容不符,請人工檢查 stats.py")

content = content.replace(old_leaf, new_leaf)
with open(path, "w") as f:
    f.write(content)
print("✅ stats.py LEAF_SQL 已修正")
PYEOF

# ---------- frontend: CategoryBreakdownChart.vue(加 nextTick,leaf 模式停用下鑽) ----------
cat > "$FRONTEND/src/components/CategoryBreakdownChart.vue" << 'EOF'
<script setup lang="ts">
import { ref, nextTick, onMounted, onBeforeUnmount, watch } from 'vue'
import Chart from 'chart.js/auto'
import { fetchCategoryBreakdown } from '@/api/ledger'
import type { CategoryBreakdownOut, EntryType } from '@/types/ledger'

const props = withDefaults(defineProps<{ type?: EntryType; months?: number }>(), {
  type: 'expense',
  months: 1,
})

const rollup = ref(true)
const breadcrumb = ref<{ id: string; name: string }[]>([])
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

function currentParentId(): string | null {
  return breadcrumb.value.length ? breadcrumb.value[breadcrumb.value.length - 1].id : null
}

async function loadAndRender() {
  errorMsg.value = ''
  try {
    data.value = await fetchCategoryBreakdown(props.type, props.months, rollup.value, currentParentId())
    await nextTick() // 等 v-else chart-wrap 掛載後 canvasRef 才存在,否則 render 到 null canvas
    renderChart()
  } catch {
    errorMsg.value = '載入分類統計失敗,請稍後再試'
  }
}

function drillInto(index: number) {
  if (!rollup.value) return // leaf 模式無階層概念,不支援下鑽
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
          backgroundColor: items.map((_, idx) => PALETTE[idx % PALETTE.length]),
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
        const hoveringDrillable = rollup.value && elements.length > 0 && items[elements[0].index]?.has_children
        target.style.cursor = hoveringDrillable ? 'pointer' : 'default'
      },
      plugins: {
        legend: { position: 'bottom' },
        tooltip: {
          callbacks: {
            label: (ctx) => {
              const item = items[ctx.dataIndex]
              const hint = rollup.value && item.has_children ? '(點擊查看子分類)' : ''
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
watch(() => [props.type, props.months], () => {
  breadcrumb.value = []
  loadAndRender()
})
watch(rollup, () => {
  breadcrumb.value = [] // leaf 模式無階層,重置下鑽狀態
  loadAndRender()
})
</script>

<template>
  <div class="category-breakdown">
    <div class="toolbar">
      <nav v-if="rollup && breadcrumb.length > 0" class="breadcrumb">
        <button @click="goToLevel(-1)">頂層</button>
        <template v-for="(crumb, idx) in breadcrumb" :key="crumb.id">
          <span class="sep">›</span>
          <button @click="goToLevel(idx)">{{ crumb.name }}</button>
        </template>
      </nav>
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
.toolbar { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem; flex-wrap: wrap; gap: 8px; }
.breadcrumb { display: flex; align-items: center; gap: 4px; font-size: 0.85rem; }
.breadcrumb button { background: none; border: none; color: #4F46E5; cursor: pointer; padding: 2px 4px; font-size: 0.85rem; }
.breadcrumb button:hover { text-decoration: underline; }
.breadcrumb .sep { color: #9ca3af; }
.toggle { font-size: 0.85rem; cursor: pointer; user-select: none; }
.chart-wrap { position: relative; height: 320px; }
.error { color: #dc2626; }
.empty { color: #6b7280; text-align: center; padding: 2rem 0; }
.total { text-align: center; font-weight: 600; margin-top: 0.5rem; }
</style>
EOF

# ---------- frontend: MonthlyTrendChart.vue(只加 nextTick,不動其他邏輯) ----------
python3 << 'PYEOF'
path = "ledger-frontend/src/components/MonthlyTrendChart.vue"
with open(path) as f:
    content = f.read()

old_import = "import { ref, onMounted, onBeforeUnmount, watch } from 'vue'"
new_import = "import { ref, nextTick, onMounted, onBeforeUnmount, watch } from 'vue'"
if old_import not in content:
    raise SystemExit("❌ import 行不符,請人工檢查 MonthlyTrendChart.vue")
content = content.replace(old_import, new_import)

old_call = """    data.value = await fetchMonthlyTrend(props.months)
    renderChart()"""
new_call = """    data.value = await fetchMonthlyTrend(props.months)
    await nextTick() // 等 v-else chart-wrap 掛載後 canvasRef 才存在
    renderChart()"""
if old_call not in content:
    raise SystemExit("❌ loadData 內容不符,請人工檢查 MonthlyTrendChart.vue")
content = content.replace(old_call, new_call)

with open(path, "w") as f:
    f.write(content)
print("✅ MonthlyTrendChart.vue 已加入 nextTick")
PYEOF

echo "✅ 全部檔案已修正完成"
git add -A
git commit -m "fix: 圖表渲染時序(nextTick)+ leaf 模式忽略 parent_id 階層過濾"
echo "✅ 已 commit,請執行 'git push origin main',再到 server 跑 ./deploy.sh"