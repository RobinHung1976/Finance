<script setup lang="ts">
import { computed, ref } from 'vue'
import type { AccountOut } from '@/types/ledger'

const props = defineProps<{
  accounts: AccountOut[]
  modelValue: string
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

const searchQuery = ref('')

const filteredAccounts = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  const list = q ? props.accounts.filter((a) => a.name.toLowerCase().includes(q)) : props.accounts
  return [...list].sort((a, b) => a.name.localeCompare(b.name))
})

function selectAccount(id: string) {
  emit('update:modelValue', id)
}
function clearSelection() {
  emit('update:modelValue', '')
}
</script>

<template>
  <div class="filter-picker-box">
    <input v-model="searchQuery" type="text" class="search-input" placeholder="搜尋帳戶…" />
    <div class="option-grid">
      <button type="button" class="option-btn" :class="{ selected: !modelValue }" @click="clearSelection">
        所有帳戶
      </button>
      <button
        v-for="a in filteredAccounts"
        :key="a.id"
        type="button"
        class="option-btn"
        :class="{ selected: a.id === modelValue }"
        @click="selectAccount(a.id)"
      >
        {{ a.name }}
      </button>
      <p v-if="filteredAccounts.length === 0" class="no-result">沒有符合的帳戶</p>
    </div>
  </div>
</template>

<style scoped>
.filter-picker-box {
  border: 1px solid var(--color-border);
  border-radius: 8px;
  padding: 10px;
  background: var(--color-bg);
}
.search-input {
  width: 100%;
  padding: 6px 10px;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  font-size: 13px;
  margin-bottom: 8px;
  box-sizing: border-box;
}
.option-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  max-height: 240px;
  overflow-y: auto;
}
.option-btn {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 6px;
  padding: 6px 12px;
  font-size: 13px;
  cursor: pointer;
}
.option-btn.selected {
  border-color: var(--color-primary);
  color: var(--color-primary);
  font-weight: 600;
}
.no-result {
  font-size: 12px;
  color: #6b7a74;
  margin: 0;
}
</style>
