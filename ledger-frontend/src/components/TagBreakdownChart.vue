<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { fetchTagBreakdown } from '@/api/ledgerApi'
import type { TagBreakdownItem } from '@/types/ledger'
import { formatCurrency } from '@/utils/ledgerLabels'

const props = defineProps<{
  startDate: string
  endDate: string
}>()

const items = ref<TagBreakdownItem[]>([])
const loading = ref(false)
const errorMsg = ref('')
const type = ref<'expense' | 'income'>('expense')

async function load() {
  loading.value = true
  errorMsg.value = ''
  try {
    const result = await fetchTagBreakdown(props.startDate, props.endDate, type.value)
    items.value = result.items
  } catch (e) {
    errorMsg.value = '載入消費品項排行失敗'
    items.value = []
  } finally {
    loading.value = false
  }
}

onMounted(load)
watch([() => props.startDate, () => props.endDate, type], load)

const maxAmount = computed(() =>
  items.value.length ? Math.max(...items.value.map((i) => i.total_amount)) : 1,
)
</script>

<template>
  <div class="tag-breakdown">
    <div class="header-row">
      <div class="keypad sm" role="radiogroup" aria-label="收支類型">
        <button type="button" role="radio" class="key" :class="{ active: type === 'expense' }" :aria-checked="type === 'expense'" @click="type = 'expense'">支出</button>
        <button type="button" role="radio" class="key" :class="{ active: type === 'income' }" :aria-checked="type === 'income'" @click="type = 'income'">收入</button>
      </div>
    </div>

    <p class="hint">
      依消費品項排行(單筆交易可能同時掛多個品項,故總和不等於{{ type === 'expense' ? '支出' : '收入' }}總額)
    </p>

    <div v-if="loading" class="empty">載入中…</div>
    <div v-else-if="errorMsg" class="error-banner">{{ errorMsg }}</div>
    <div v-else-if="items.length === 0" class="empty">此區間無已標記消費品項的交易</div>

    <div v-else class="bar-list">
      <div v-for="item in items" :key="item.tag_id" class="bar-row">
        <span class="label" :title="item.name">{{ item.name }}</span>
        <div class="bar-track">
          <div class="bar-fill" :class="type" :style="{ width: `${(item.total_amount / maxAmount) * 100}%` }" />
        </div>
        <span class="amount" :class="type">{{ formatCurrency(item.total_amount) }}</span>
        <span class="count">{{ item.transaction_count }} 筆</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.tag-breakdown { height: 360px; display: flex; flex-direction: column; overflow: hidden; }
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
.bar-row { display: grid; grid-template-columns: 110px 1fr 110px 56px; align-items: center; gap: 10px; padding: 5px 0; }
.label { overflow: hidden; font-size: 13.5px; font-weight: 600; text-overflow: ellipsis; white-space: nowrap; }
.amount { font-size: 13.5px; text-align: right; }
.count { font-size: 12px; color: var(--muted); text-align: right; font-variant-numeric: tabular-nums; }
</style>
