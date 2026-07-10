<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { createCategory } from '@/api/ledgerApi'
import type { CategoryOut, EntryType } from '@/types/ledger'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const props = defineProps<{
  categories: CategoryOut[]
  type: EntryType
  modelValue: string
  hideSelectedHint?: boolean
}>()

const emit = defineEmits<{
  'update:modelValue': [value: string]
  created: [category: CategoryOut]
}>()

const path = ref<CategoryOut[]>([])

watch(
  () => props.type,
  () => {
    path.value = []
    searchQuery.value = ''
  }
)

const currentParentId = computed<string | null>(() => {
  const last = path.value[path.value.length - 1]
  return last ? last.id : null
})

const currentLevelCategories = computed(() =>
  props.categories.filter((c) => c.type === props.type && c.parent_id === currentParentId.value)
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

const searchQuery = ref('')

const searchResults = computed(() => {
  const q = searchQuery.value.trim()
  if (!q) return []
  const lower = q.toLowerCase()
  return props.categories
    .filter((c) => c.type === props.type && c.name.toLowerCase().includes(lower))
    .map((c) => ({ category: c, label: fullPathLabel(c) }))
    .slice(0, 30)
})

function selectFromSearch(category: CategoryOut) {
  emit('update:modelValue', category.id)
  const chain = ancestorChain(category)
  path.value = chain.slice(0, -1)
  searchQuery.value = ''
}

const showCreateForm = ref(false)
const newCategoryName = ref('')
const createError = ref('')
const isCreating = ref(false)

async function handleCreate() {
  createError.value = ''
  const trimmedName = newCategoryName.value.trim()
  if (!trimmedName) {
    createError.value = '請輸入分類名稱'
    return
  }
  const isDuplicate = currentLevelCategories.value.some(
    (c) => c.name.trim().toLowerCase() === trimmedName.toLowerCase()
  )
  if (isDuplicate) {
    createError.value = '此層級已有同名分類,請直接選擇現有分類'
    return
  }
  isCreating.value = true
  try {
    const created = await createCategory({
      name: trimmedName,
      type: props.type,
      parent_id: currentParentId.value,
    })
    emit('created', created)
    emit('update:modelValue', created.id)
    path.value.push(created)
    newCategoryName.value = ''
    showCreateForm.value = false
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    createError.value = axiosErr.response?.data?.detail ?? '新增失敗'
  } finally {
    isCreating.value = false
  }
}

const selectedCategoryName = computed(
  () => props.categories.find((c) => c.id === props.modelValue)?.name ?? ''
)
</script>

<template>
  <div class="category-picker">
    <input
      v-model="searchQuery"
      type="text"
      class="search-input"
      placeholder="搜尋分類(不限層級,例如：晚餐)"
    />

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
      <p v-else class="selected-hint">沒有符合「{{ searchQuery }}」的分類</p>
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

        <button type="button" class="option-btn add-btn" @click="showCreateForm = !showCreateForm">
          + 新增分類
        </button>
      </div>
    </template>

    <form v-if="showCreateForm" class="create-form" @submit.prevent="handleCreate">
      <input v-model="newCategoryName" type="text" maxlength="100" placeholder="分類名稱" required />
      <button class="btn-primary" type="submit" style="width: auto; padding: 6px 14px" :disabled="isCreating">
        {{ isCreating ? '新增中…' : '確認' }}
      </button>
    </form>
    <div v-if="createError" class="error-banner" style="margin-top: 6px">{{ createError }}</div>

    <template v-if="!hideSelectedHint">
      <p v-if="modelValue" class="selected-hint">已選擇：{{ selectedCategoryName }}</p>
      <p v-else class="selected-hint" style="color: var(--color-danger)">尚未選擇分類</p>
    </template>
  </div>
</template>

<style scoped>
.category-picker {
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

.add-btn {
  color: var(--color-primary);
  border-style: dashed;
}

.create-form {
  display: flex;
  gap: 8px;
  margin-top: 8px;
}

.create-form input {
  flex: 1;
  padding: 6px 10px;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  font-size: 13px;
}

.selected-hint {
  font-size: 12px;
  color: #6b7a74;
  margin: 8px 0 0;
}
</style>
