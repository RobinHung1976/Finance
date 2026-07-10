<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import type { AccountOut } from '@/types/ledger'

const props = defineProps<{
  accounts: AccountOut[]
  modelValue: string
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

const rootEl = ref<HTMLElement | null>(null)
const isOpen = ref(false)
const searchQuery = ref('')

const selectedLabel = computed(() => {
  if (!props.modelValue) return '所有帳戶'
  return props.accounts.find((a) => a.id === props.modelValue)?.name ?? '所有帳戶'
})

const filteredAccounts = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  const list = q ? props.accounts.filter((a) => a.name.toLowerCase().includes(q)) : props.accounts
  return [...list].sort((a, b) => a.name.localeCompare(b.name))
})

function toggleOpen() {
  isOpen.value = !isOpen.value
  if (isOpen.value) searchQuery.value = ''
}
function selectAccount(id: string) {
  emit('update:modelValue', id)
  isOpen.value = false
}
function clearSelection() {
  emit('update:modelValue', '')
  isOpen.value = false
}

function handleOutsideClick(e: MouseEvent) {
  if (rootEl.value && !rootEl.value.contains(e.target as Node)) {
    isOpen.value = false
  }
}
onMounted(() => document.addEventListener('click', handleOutsideClick))
onBeforeUnmount(() => document.removeEventListener('click', handleOutsideClick))
</script>

<template>
  <div ref="rootEl" class="account-filter-picker">
    <button type="button" class="filter-input picker-trigger" @click="toggleOpen">
      {{ selectedLabel }}
    </button>
    <div v-if="isOpen" class="dropdown-panel">
      <input v-model="searchQuery" type="text" class="search-input" placeholder="搜尋帳戶…" autofocus />
      <div class="result-list">
        <button type="button" class="result-item" :class="{ selected: !modelValue }" @click="clearSelection">
          所有帳戶
        </button>
        <button
          v-for="a in filteredAccounts"
          :key="a.id"
          type="button"
          class="result-item"
          :class="{ selected: a.id === modelValue }"
          @click="selectAccount(a.id)"
        >
          {{ a.name }}
        </button>
        <p v-if="filteredAccounts.length === 0" class="no-result">沒有符合的帳戶</p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.account-filter-picker {
  position: relative;
}
.picker-trigger {
  cursor: pointer;
  text-align: left;
  min-width: 120px;
  max-width: 200px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.dropdown-panel {
  position: absolute;
  top: calc(100% + 4px);
  left: 0;
  z-index: 20;
  width: 220px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  padding: 8px;
}
.search-input {
  width: 100%;
  padding: 6px 10px;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  font-size: 13px;
  margin-bottom: 6px;
  box-sizing: border-box;
}
.result-list {
  max-height: 240px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.result-item {
  text-align: left;
  background: none;
  border: none;
  padding: 6px 8px;
  font-size: 13px;
  cursor: pointer;
  border-radius: 6px;
}
.result-item:hover {
  background: var(--color-bg);
}
.result-item.selected {
  color: var(--color-primary);
  font-weight: 600;
}
.no-result {
  font-size: 12px;
  color: #6b7a74;
  padding: 6px 8px;
  margin: 0;
}
</style>
