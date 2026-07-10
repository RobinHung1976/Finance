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
      <div class="type-toggle">
        <button :class="{ active: type === 'expense' }" @click="type = 'expense'">支出</button>
        <button :class="{ active: type === 'income' }" @click="type = 'income'">收入</button>
      </div>
    </div>

    <p class="hint">
      依消費品項排行(單筆交易可能同時掛多個品項,故總和不等於{{ type === 'expense' ? '支出' : '收入' }}總額)
    </p>

    <div v-if="loading" class="state-msg">載入中...</div>
    <div v-else-if="errorMsg" class="state-msg error">{{ errorMsg }}</div>
    <div v-else-if="items.length === 0" class="state-msg">此區間無已標記消費品項的交易</div>

    <div v-else class="bar-list">
      <div v-for="item in items" :key="item.tag_id" class="bar-row">
        <span class="label" :title="item.name">{{ item.name }}</span>
        <div class="bar-track">
          <div class="bar-fill" :style="{ width: `${(item.total_amount / maxAmount) * 100}%` }" />
        </div>
        <span class="amount">{{ formatCurrency(item.total_amount) }}</span>
        <span class="count">{{ item.transaction_count }} 筆</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.tag-breakdown {
  height: 320px;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.header-row {
  display: flex;
  justify-content: flex-end;
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
  grid-template-columns: 90px 1fr 90px 50px;
  align-items: center;
  gap: 8px;
  padding: 4px 0;
}
.label {
  font-size: 13px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.bar-track {
  height: 14px;
  background: #f0f0f0;
  border-radius: 4px;
  overflow: hidden;
}
.bar-fill {
  height: 100%;
  background: #4a90d9;
  transition: width 0.3s ease;
}
.amount {
  font-size: 13px;
  text-align: right;
}
.count {
  font-size: 12px;
  color: #999;
  text-align: right;
}
</style>
