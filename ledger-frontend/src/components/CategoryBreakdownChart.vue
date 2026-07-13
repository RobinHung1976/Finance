<script setup lang="ts">
import { ref, nextTick, onMounted, onBeforeUnmount, watch } from 'vue'
import Chart from 'chart.js/auto'
import { fetchCategoryBreakdown } from '@/api/ledgerApi'
import type { CategoryBreakdownOut, EntryType } from '@/types/ledger'

const props = withDefaults(defineProps<{ type?: EntryType; startDate: string; endDate: string }>(), {
  type: 'expense',
})

const breadcrumb = ref<{ id: string; name: string }[]>([])
const canvasRef = ref<HTMLCanvasElement | null>(null)
const data = ref<CategoryBreakdownOut | null>(null)
const errorMsg = ref('')
let chartInstance: Chart | null = null

const PALETTE = [
  '#4F46E5', '#059669', '#D97706', '#DC2626', '#7C3AED',
  '#0891B2', '#DB2777', '#65A30D', '#EA580C', '#4338CA',
]
// 「本分類直接交易(未再細分)」固定用中性灰,跟一般子分類的彩色區隔開來
const SELF_COLOR = '#9CA3AF'

function formatCurrency(v: number): string {
  return v.toLocaleString('zh-TW', { style: 'currency', currency: 'TWD', maximumFractionDigits: 0 })
}

function currentParentId(): string | null {
  return breadcrumb.value.length ? breadcrumb.value[breadcrumb.value.length - 1].id : null
}

async function loadAndRender() {
  errorMsg.value = ''
  try {
    // rollup 固定 true:UI 不再提供切換,子分類一律捲到頂層
    data.value = await fetchCategoryBreakdown(props.type, props.startDate, props.endDate, currentParentId())
    await nextTick()
    requestAnimationFrame(renderChart) // 等瀏覽器完成 layout,避免 canvas 量到 0x0
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
          backgroundColor: items.map((i, idx) => (i.is_self ? SELF_COLOR : PALETTE[idx % PALETTE.length])),
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
watch(() => [props.type, props.startDate, props.endDate], () => {
  breadcrumb.value = []
  loadAndRender()
})
</script>

<template>
  <div class="category-breakdown">
    <nav v-if="breadcrumb.length > 0" class="breadcrumb">
      <button class="crumb" @click="goToLevel(-1)">頂層</button>
      <template v-for="(crumb, idx) in breadcrumb" :key="crumb.id">
        <span class="sep">›</span>
        <button class="crumb" :class="{ current: idx === breadcrumb.length - 1 }" @click="goToLevel(idx)">
          {{ crumb.name }}
        </button>
      </template>
    </nav>
    <p v-if="errorMsg" class="error">{{ errorMsg }}</p>
    <p v-else-if="data && data.items.length === 0" class="empty">此期間無資料</p>
    <div v-else class="chart-wrap"><canvas ref="canvasRef"></canvas></div>
    <p v-if="data && data.items.length > 0" class="total">總計:{{ formatCurrency(data.total) }}</p>
  </div>
</template>

<style scoped>
.category-breakdown { display: flex; flex-direction: column; height: 100%; }

.breadcrumb {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 12px;
  flex-wrap: wrap;
}
.crumb {
  background: #f3f4f6;
  border: 1px solid #e5e7eb;
  border-radius: 999px;
  padding: 4px 12px;
  font-size: 0.8rem;
  color: #4b5563;
  cursor: pointer;
  transition: background 0.15s;
}
.crumb:hover { background: #e5e7eb; }
.crumb.current { background: #4F46E5; border-color: #4F46E5; color: #fff; cursor: default; }
.sep { color: #9ca3af; font-size: 0.8rem; }

.chart-wrap { position: relative; height: 320px; }
.error { color: #dc2626; }
.empty { color: #6b7280; text-align: center; padding: 2rem 0; }
.total { text-align: center; font-weight: 600; margin-top: 0.5rem; }
</style>
