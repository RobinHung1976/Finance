<script setup lang="ts">
import { ref, nextTick, onMounted, onBeforeUnmount, watch } from 'vue'
import Chart from 'chart.js/auto'
import { fetchMonthlyTrend } from '@/api/ledgerApi'
import type { MonthlyTrendOut } from '@/types/ledger'
import { CHART_COLORS, withAlpha } from '@/utils/chartTheme'

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
          borderColor: CHART_COLORS.income,
          backgroundColor: withAlpha(CHART_COLORS.income, 0.12),
          tension: 0.3,
          fill: true,
        },
        {
          label: '支出',
          data: expenseData,
          borderColor: CHART_COLORS.expense,
          backgroundColor: withAlpha(CHART_COLORS.expense, 0.12),
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
  <div class="trend">
    <div v-if="loading" class="empty">載入中…</div>
    <div v-else-if="error" class="error-banner">{{ error }}</div>
    <template v-else-if="data">
      <div class="stat-grid">
        <div class="stat">
          <div class="stat-label">總收入</div>
          <div class="stat-value income">{{ formatCurrency(data.total_income) }}</div>
        </div>
        <div class="stat">
          <div class="stat-label">總支出</div>
          <div class="stat-value expense">{{ formatCurrency(data.total_expense) }}</div>
        </div>
        <div class="stat">
          <div class="stat-label">結餘</div>
          <div class="stat-value" :class="data.total_balance >= 0 ? 'income' : 'expense'">
            {{ formatCurrency(data.total_balance) }}
          </div>
        </div>
      </div>
      <div class="chart-box">
        <div class="chart-wrap"><canvas ref="canvasRef"></canvas></div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.chart-box { margin-top: 16px; }
.chart-wrap { position: relative; height: 320px; }
</style>
