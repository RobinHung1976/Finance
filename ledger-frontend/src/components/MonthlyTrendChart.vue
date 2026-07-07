<script setup lang="ts">
import { ref, nextTick, onMounted, onBeforeUnmount, watch } from 'vue'
import Chart from 'chart.js/auto'
import { fetchMonthlyTrend } from '@/api/ledger'
import type { MonthlyTrendOut } from '@/types/ledger'

const props = withDefaults(defineProps<{ months?: number }>(), { months: 12 })

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
    data.value = await fetchMonthlyTrend(props.months)
    await nextTick() // 等 v-else chart-wrap 掛載後 canvasRef 才存在
    renderChart()
  } catch (e) {
    error.value = '統計資料載入失敗,請稍後再試'
    console.error(e)
  } finally {
    loading.value = false
  }
}

watch(() => props.months, loadData)

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
