<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import type { CategoryOut } from '@/types/ledger'

const props = defineProps<{
  categories: CategoryOut[]
  modelValue: string
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

const rootEl = ref<HTMLElement | null>(null)
const isOpen = ref(false)
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

const selectedLabel = computed(() => {
  if (!props.modelValue) return '所有分類'
  const cat = props.categories.find((c) => c.id === props.modelValue)
  return cat ? fullPathLabel(cat) : '所有分類'
})

const filteredResults = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  const list = q ? props.categories.filter((c) => c.name.toLowerCase().includes(q)) : props.categories
  return list
    .map((c) => ({ category: c, label: fullPathLabel(c) }))
    .sort((a, b) => a.label.localeCompare(b.label))
    .slice(0, 50)
})

function toggleOpen() {
  isOpen.value = !isOpen.value
  if (isOpen.value) searchQuery.value = ''
}
function selectCategory(id: string) {
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
  <div ref="rootEl" class="category-filter-picker">
    <button type="button" class="filter-input picker-trigger" @click="toggleOpen">
      {{ selectedLabel }}
    </button>
    <div v-if="isOpen" class="dropdown-panel">
      <input v-model="searchQuery" type="text" class="search-input" placeholder="搜尋分類…" autofocus />
      <div class="result-list">
        <button type="button" class="result-item" :class="{ selected: !modelValue }" @click="clearSelection">
          所有分類
        </button>
        <button
          v-for="r in filteredResults"
          :key="r.category.id"
          type="button"
          class="result-item"
          :class="{ selected: r.category.id === modelValue }"
          @click="selectCategory(r.category.id)"
        >
          {{ r.label }}
        </button>
        <p v-if="filteredResults.length === 0" class="no-result">沒有符合的分類</p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.category-filter-picker {
  position: relative;
}
.picker-trigger {
  cursor: pointer;
  text-align: left;
  min-width: 140px;
  max-width: 220px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.dropdown-panel {
  position: absolute;
  top: calc(100% + 4px);
  left: 0;
  z-index: 20;
  width: 260px;
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
  max-height: 280px;
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
