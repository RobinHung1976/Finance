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
    renderChart()
  } catch {
    errorMsg.value = '載入分類統計失敗,請稍後再試'
  }
}

function drillInto(index: number) {
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
        const hoveringDrillable = elements.length > 0 && items[elements[0].index]?.has_children
        target.style.cursor = hoveringDrillable ? 'pointer' : 'default'
      },
      plugins: {
        legend: { position: 'bottom' },
        tooltip: {
          callbacks: {
            label: (ctx) => {
              const item = items[ctx.dataIndex]
              const hint = item.has_children ? '(點擊查看子分類)' : ''
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
  breadcrumb.value = []
  loadAndRender()
})
</script>

<template>
  <div class="category-breakdown">
    <div class="toolbar">
      <nav v-if="breadcrumb.length > 0" class="breadcrumb">
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
