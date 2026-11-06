<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { fetchTopTransactions } from '@/api/ledgerApi'
import type { TopTransactionItem } from '@/types/ledger'
import { formatCurrency } from '@/utils/ledgerLabels'

const props = defineProps<{
  startDate: string
  endDate: string
}>()

const items = ref<TopTransactionItem[]>([])
const loading = ref(false)
const errorMsg = ref('')
const type = ref<'expense' | 'income'>('expense')
const limit = ref(5)

async function load() {
  loading.value = true
  errorMsg.value = ''
  try {
    const result = await fetchTopTransactions(props.startDate, props.endDate, type.value, limit.value)
    items.value = result.items
  } catch (e) {
    errorMsg.value = '載入最大單筆排行失敗'
    items.value = []
  } finally {
    loading.value = false
  }
}

onMounted(load)
watch([() => props.startDate, () => props.endDate, type, limit], load)

const maxAmount = computed(() =>
  items.value.length ? Math.max(...items.value.map((i) => i.amount)) : 1,
)
</script>

<template>
  <div class="top-transactions">
    <div class="header-row">
      <div class="keypad sm" role="radiogroup" aria-label="收支類型">
        <button type="button" role="radio" class="key" :class="{ active: type === 'expense' }" :aria-checked="type === 'expense'" @click="type = 'expense'">支出</button>
        <button type="button" role="radio" class="key" :class="{ active: type === 'income' }" :aria-checked="type === 'income'" @click="type = 'income'">收入</button>
      </div>
      <select v-model.number="limit" class="limit-select" aria-label="顯示筆數">
        <option :value="5">Top 5</option>
        <option :value="10">Top 10</option>
        <option :value="20">Top 20</option>
      </select>
    </div>

    <p class="hint">依單筆交易金額排行,不套用進階篩選(帳戶/分類/消費品項)</p>

    <div v-if="loading" class="empty">載入中…</div>
    <div v-else-if="errorMsg" class="error-banner">{{ errorMsg }}</div>
    <div v-else-if="items.length === 0" class="empty">此區間無交易</div>

    <div v-else class="bar-list">
      <div v-for="(item, index) in items" :key="item.id" class="bar-row">
        <span class="rank">{{ index + 1 }}</span>
        <div class="info">
          <div class="info-top">
            <span class="category" :title="item.category_name">{{ item.category_name }}</span>
            <span class="account" :title="item.account_name">{{ item.account_name }}</span>
          </div>
          <div class="bar-track">
            <div class="bar-fill" :class="type" :style="{ width: `${(item.amount / maxAmount) * 100}%` }" />
          </div>
        </div>
        <div class="right">
          <span class="amount" :class="type">{{ formatCurrency(item.amount) }}</span>
          <span class="date">{{ item.date }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.top-transactions { height: 360px; display: flex; flex-direction: column; overflow: hidden; }
.header-row { display: flex; justify-content: space-between; align-items: center; gap: 12px; margin-bottom: 6px; }
.keypad.sm { padding: 0; gap: 8px; }
.keypad.sm .key { height: 32px; padding: 0 14px 6px; font-size: 13px; }
.keypad.sm .key::after { left: 10px; right: 10px; bottom: 3px; height: 3px; }
.hint { margin: 4px 0 10px; }
.bar-list { flex: 1; overflow-y: auto; padding-right: 4px; }
.bar-track {
  height: 12px; overflow: hidden; border-radius: 6px; background: #d9dde2;
  box-shadow: inset 0 1px 2px rgb(0 0 0 / 25%), 0 1px 0 rgb(255 255 255 / 70%);
}
.bar-fill { height: 100%; border-radius: 6px; transition: width 0.3s ease; box-shadow: inset 0 1px 0 rgb(255 255 255 / 35%); }
.bar-fill.expense { background: linear-gradient(180deg, #d9603c, var(--c-expense)); }
.bar-fill.income { background: linear-gradient(180deg, #34a868, var(--c-income)); }
@media (prefers-reduced-motion: reduce) { .bar-fill { transition: none; } }
.limit-select { width: 110px; }
.bar-row { display: grid; grid-template-columns: 28px 1fr 120px; align-items: center; gap: 12px; padding: 8px 0; border-bottom: 1px solid var(--line-soft); }
.rank {
  display: grid; place-items: center; width: 24px; height: 24px; border-radius: 50%; font-size: 12px; font-weight: 800; color: var(--text-2);
  background: var(--metal-key); border: 1px solid #a9b0b8; box-shadow: inset 0 1px 0 #fff;
}
.info { min-width: 0; }
.info-top { display: flex; justify-content: space-between; gap: 8px; margin-bottom: 5px; font-size: 13.5px; }
.category { overflow: hidden; font-weight: 600; text-overflow: ellipsis; white-space: nowrap; }
.account { flex-shrink: 0; overflow: hidden; color: var(--muted); text-overflow: ellipsis; white-space: nowrap; }
.right { display: flex; flex-direction: column; align-items: flex-end; }
.amount { font-size: 14px; }
.date { font-size: 11.5px; color: var(--muted); font-variant-numeric: tabular-nums; }
</style>
