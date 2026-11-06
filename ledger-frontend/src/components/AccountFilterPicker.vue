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
    <input v-model="searchQuery" type="search" class="search-input" placeholder="搜尋帳戶…" />
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
