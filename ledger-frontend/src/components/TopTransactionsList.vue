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
      <div class="type-toggle">
        <button :class="{ active: type === 'expense' }" @click="type = 'expense'">支出</button>
        <button :class="{ active: type === 'income' }" @click="type = 'income'">收入</button>
      </div>
      <select v-model.number="limit" class="limit-select">
        <option :value="5">Top 5</option>
        <option :value="10">Top 10</option>
        <option :value="20">Top 20</option>
      </select>
    </div>

    <p class="hint">依單筆交易金額排行,不套用進階篩選(帳戶/分類/消費品項)</p>

    <div v-if="loading" class="state-msg">載入中...</div>
    <div v-else-if="errorMsg" class="state-msg error">{{ errorMsg }}</div>
    <div v-else-if="items.length === 0" class="state-msg">此區間無交易</div>

    <div v-else class="bar-list">
      <div v-for="(item, index) in items" :key="item.id" class="bar-row">
        <span class="rank">{{ index + 1 }}</span>
        <div class="info">
          <div class="info-top">
            <span class="category" :title="item.category_name">{{ item.category_name }}</span>
            <span class="account" :title="item.account_name">{{ item.account_name }}</span>
          </div>
          <div class="bar-track">
            <div class="bar-fill" :style="{ width: `${(item.amount / maxAmount) * 100}%` }" />
          </div>
        </div>
        <div class="right">
          <span class="amount">{{ formatCurrency(item.amount) }}</span>
          <span class="date">{{ item.date }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.top-transactions {
  height: 320px;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.header-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 4px;
}
.type-toggle button {
  padding: 4px 12px;
  border: 1px solid #ddd;
  background: #fff;
  cursor: pointer;
}
.type-toggle button.active {
  background: #333;
  color: #fff;
}
.limit-select {
  border: 1px solid #ddd;
  border-radius: 4px;
  padding: 4px 8px;
  font-size: 13px;
}
.hint {
  font-size: 12px;
  color: #888;
  margin: 4px 0 8px;
}
.state-msg {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #999;
}
.state-msg.error {
  color: #d33;
}
.bar-list {
  flex: 1;
  overflow-y: auto;
}
.bar-row {
  display: grid;
  grid-template-columns: 24px 1fr 110px;
  align-items: center;
  gap: 10px;
  padding: 6px 0;
  border-bottom: 1px solid #f3f4f6;
}
.rank {
  font-size: 13px;
  font-weight: 600;
  color: #9ca3af;
  text-align: center;
}
.info-top {
  display: flex;
  justify-content: space-between;
  gap: 8px;
  font-size: 13px;
  margin-bottom: 4px;
}
.category {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-weight: 500;
}
.account {
  color: #888;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  flex-shrink: 0;
}
.bar-track {
  height: 10px;
  background: #f0f0f0;
  border-radius: 4px;
  overflow: hidden;
}
.bar-fill {
  height: 100%;
  background: #4a90d9;
  transition: width 0.3s ease;
}
.right {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
}
.amount {
  font-size: 13px;
  font-weight: 600;
}
.date {
  font-size: 11px;
  color: #999;
}
</style>
