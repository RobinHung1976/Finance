<script setup lang="ts">
import { computed, ref } from 'vue'
import type { CategoryOut } from '@/types/ledger'

const props = defineProps<{
  categories: CategoryOut[]
  modelValue: string
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

const path = ref<CategoryOut[]>([])
const searchQuery = ref('')

const currentParentId = computed<string | null>(() => {
  const last = path.value[path.value.length - 1]
  return last ? last.id : null
})

const currentLevelCategories = computed(() =>
  props.categories.filter((c) => c.parent_id === currentParentId.value)
)

function hasChildren(categoryId: string): boolean {
  return props.categories.some((c) => c.parent_id === categoryId)
}

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

function selectCategory(category: CategoryOut) {
  emit('update:modelValue', category.id)
  path.value.push(category)
}

function jumpToBreadcrumb(index: number) {
  if (index < 0) {
    path.value = []
    return
  }
  path.value = path.value.slice(0, index + 1)
  emit('update:modelValue', path.value[index].id)
}

function clearSelection() {
  emit('update:modelValue', '')
  path.value = []
}

const searchResults = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return []
  return props.categories
    .map((c) => ({ category: c, label: fullPathLabel(c) }))
    .filter((r) => r.category.name.toLowerCase().includes(q))
    .sort((a, b) => a.label.localeCompare(b.label))
    .slice(0, 30)
})

function selectFromSearch(category: CategoryOut) {
  emit('update:modelValue', category.id)
  path.value = ancestorChain(category).slice(0, -1)
  searchQuery.value = ''
}
</script>

<template>
  <div class="filter-picker-box">
    <input v-model="searchQuery" type="text" class="search-input" placeholder="搜尋分類(不限層級)…" />

    <template v-if="searchQuery.trim()">
      <div v-if="searchResults.length" class="search-results">
        <button
          v-for="r in searchResults"
          :key="r.category.id"
          type="button"
          class="search-result-btn"
          :class="{ selected: r.category.id === modelValue }"
          @click="selectFromSearch(r.category)"
        >
          {{ r.label }}
        </button>
      </div>
      <p v-else class="no-result">沒有符合「{{ searchQuery }}」的分類</p>
    </template>

    <template v-else>
      <div class="breadcrumb">
        <button type="button" class="crumb" :class="{ active: path.length === 0 }" @click="jumpToBreadcrumb(-1)">
          全部
        </button>
        <template v-for="(node, idx) in path" :key="node.id">
          <span class="crumb-sep">›</span>
          <button
            type="button"
            class="crumb"
            :class="{ active: idx === path.length - 1 }"
            @click="jumpToBreadcrumb(idx)"
          >
            {{ node.name }}
          </button>
        </template>
      </div>

      <div class="option-grid">
        <button type="button" class="option-btn" :class="{ selected: !modelValue }" @click="clearSelection">
          所有分類
        </button>
        <button
          v-for="c in currentLevelCategories"
          :key="c.id"
          type="button"
          class="option-btn"
          :class="{ selected: c.id === modelValue }"
          @click="selectCategory(c)"
        >
          {{ c.name }}
          <span v-if="hasChildren(c.id)" class="chevron">›</span>
        </button>
      </div>
    </template>
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
.search-results {
  display: flex;
  flex-direction: column;
  gap: 4px;
  max-height: 240px;
  overflow-y: auto;
}
.search-result-btn {
  text-align: left;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 6px;
  padding: 6px 10px;
  font-size: 13px;
  cursor: pointer;
}
.search-result-btn.selected {
  border-color: var(--color-primary);
  color: var(--color-primary);
  font-weight: 600;
}
.breadcrumb {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 4px;
  margin-bottom: 8px;
}
.crumb {
  background: none;
  border: none;
  font-size: 12px;
  color: #6b7a74;
  padding: 2px 4px;
  cursor: pointer;
}
.crumb.active {
  color: var(--color-primary);
  font-weight: 600;
}
.crumb-sep {
  color: #b7c2bd;
  font-size: 12px;
}
.option-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.option-btn {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 6px;
  padding: 6px 12px;
  font-size: 13px;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 4px;
}
.option-btn.selected {
  border-color: var(--color-primary);
  color: var(--color-primary);
  font-weight: 600;
}
.chevron {
  color: #9fb3ac;
  font-size: 11px;
}
.no-result {
  font-size: 12px;
  color: #6b7a74;
  margin: 0;
}
</style>
