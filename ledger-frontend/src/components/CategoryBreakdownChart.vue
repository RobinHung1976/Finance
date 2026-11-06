<script setup lang="ts">
import { ref, nextTick, onMounted, onBeforeUnmount, watch } from 'vue'
import Chart from 'chart.js/auto'
import { fetchCategoryBreakdown } from '@/api/ledgerApi'
import type { CategoryBreakdownOut, EntryType } from '@/types/ledger'
import { CHART_COLORS, paletteColor } from '@/utils/chartTheme'

const props = withDefaults(defineProps<{ type?: EntryType; startDate: string; endDate: string }>(), {
  type: 'expense',
})

const breadcrumb = ref<{ id: string; name: string }[]>([])
const canvasRef = ref<HTMLCanvasElement | null>(null)
const data = ref<CategoryBreakdownOut | null>(null)
const errorMsg = ref('')
let chartInstance: Chart | null = null

// 「本分類直接交易(未再細分)」固定用中性灰,跟一般子分類的彩色區隔開來
const SELF_COLOR = CHART_COLORS.neutral

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
          backgroundColor: items.map((i, idx) => (i.is_self ? SELF_COLOR : paletteColor(idx))),
          borderColor: '#f4f5f7',
          borderWidth: 2,
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
    <nav class="crumbs" aria-label="分類層級">
      <button type="button" class="btn sm" :class="{ on: breadcrumb.length === 0 }" @click="goToLevel(-1)">頂層</button>
      <template v-for="(crumb, idx) in breadcrumb" :key="crumb.id">
        <span class="sep">›</span>
        <button type="button" class="btn sm" :class="{ on: idx === breadcrumb.length - 1 }" @click="goToLevel(idx)">
          {{ crumb.name }}
        </button>
      </template>
      <span class="hint">點圓餅區塊可查看子分類</span>
    </nav>
    <div v-if="errorMsg" class="error-banner">{{ errorMsg }}</div>
    <p v-else-if="data && data.items.length === 0" class="empty">此期間無資料</p>
    <div v-else class="chart-wrap"><canvas ref="canvasRef"></canvas></div>
    <p v-if="data && data.items.length > 0" class="total">總計 <span class="amount expense">{{ formatCurrency(data.total) }}</span></p>
  </div>
</template>

<style scoped>
.category-breakdown { display: flex; flex-direction: column; height: 100%; }
.crumbs { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; margin-bottom: 12px; }
.crumbs .hint { margin-left: 8px; }
.sep { color: var(--muted); font-weight: 700; }
.chart-wrap { position: relative; height: 320px; }
.total { margin: 10px 0 0; text-align: center; font-weight: 700; }
</style>
