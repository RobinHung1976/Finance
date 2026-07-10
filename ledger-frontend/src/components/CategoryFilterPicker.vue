<script setup lang="ts">
import { computed, ref } from 'vue'
import type { CategoryOut } from '@/types/ledger'

const props = defineProps<{
  categories: CategoryOut[]
  modelValue: string
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

const searchQuery = ref('')

function ancestorChain(category: CategoryOut): CategoryOut[] {
  const chain: CategoryOut[] = []
  let node: CategoryOut | undefined = category
  while (node) {
    chain.unshift(node)
    node = node.parent_id ? props.categories.find((c) => c.id === node!.parent_id) : undefined
  }
  return chain
}
function fullPathLabel(category: CategoryOut): string {
  return ancestorChain(category).map((c) => c.name).join(' › ')
}

const filteredResults = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  const list = q ? props.categories.filter((c) => c.name.toLowerCase().includes(q)) : props.categories
  return list
    .map((c) => ({ category: c, label: fullPathLabel(c) }))
    .sort((a, b) => a.label.localeCompare(b.label))
    .slice(0, 50)
})

function selectCategory(id: string) {
  emit('update:modelValue', id)
}
function clearSelection() {
  emit('update:modelValue', '')
}
</script>

<template>
  <div class="filter-picker-box">
    <input v-model="searchQuery" type="text" class="search-input" placeholder="搜尋分類…" />
    <div class="option-grid">
      <button type="button" class="option-btn" :class="{ selected: !modelValue }" @click="clearSelection">
        所有分類
      </button>
      <button
        v-for="r in filteredResults"
        :key="r.category.id"
        type="button"
        class="option-btn"
        :class="{ selected: r.category.id === modelValue }"
        @click="selectCategory(r.category.id)"
      >
        {{ r.label }}
      </button>
      <p v-if="filteredResults.length === 0" class="no-result">沒有符合的分類</p>
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
