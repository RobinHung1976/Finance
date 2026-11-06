<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import AppIcon from './AppIcon.vue'
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

// 有子分類才進入下一層;沒有子分類只選取、停在原層,選取狀態直接顯示在按鍵上
function selectCategory(category: CategoryOut) {
  emit('update:modelValue', category.id)
  if (hasChildren(category.id)) path.value.push(category)
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
const currentLevelLabel = computed(() => (path.value.length ? path.value[path.value.length - 1].name : '最上層'))

// 最上層中被選取、且還沒有子分類的大類:新增時可選擇加在它底下(建立第一個細項)
// 只限最上層:分類樹維持兩層(大類 > 細項),第三層請改用消費品項
const selectedLeafHere = computed(() =>
  path.value.length === 0
    ? (currentLevelCategories.value.find((c) => c.id === props.modelValue && !hasChildren(c.id)) ?? null)
    : null
)
const createUnderSelected = ref(false)
const createParent = computed<CategoryOut | null>(() =>
  createUnderSelected.value && selectedLeafHere.value ? selectedLeafHere.value : path.value[path.value.length - 1] ?? null
)
const createTargetLabel = computed(() => createParent.value?.name ?? '最上層')

// 開啟新增欄位時,若正在搜尋且沒有完全同名的分類,直接帶入搜尋字
function toggleCreateForm() {
  showCreateForm.value = !showCreateForm.value
  createError.value = ''
  createUnderSelected.value = false
  const q = searchQuery.value.trim()
  if (showCreateForm.value && q && !newCategoryName.value) newCategoryName.value = q
}
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
  const parent = createParent.value
  const parentId = parent?.id ?? null
  const isDuplicate = props.categories.some(
    (c) => c.type === props.type && c.parent_id === parentId && c.name.trim().toLowerCase() === trimmedName.toLowerCase()
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
      parent_id: parentId,
    })
    emit('created', created)
    emit('update:modelValue', created.id)
    // 新分類沒有子分類,不進入;若是加在選取的分類底下,則進入該分類讓新分類顯示在按鍵列
    if (parent && path.value[path.value.length - 1]?.id !== parent.id) path.value.push(parent)
    createUnderSelected.value = false
    newCategoryName.value = ''
    showCreateForm.value = false
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    createError.value = axiosErr.response?.data?.detail ?? '新增失敗'
  } finally {
    isCreating.value = false
  }
}

const selectedCategoryPath = computed(() => {
  const selected = props.categories.find((c) => c.id === props.modelValue)
  return selected ? fullPathLabel(selected) : ''
})
</script>

<template>
  <div class="category-picker">
    <input
      v-model="searchQuery"
      type="search"
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
            :class="{ active: idx === path.length - 1, selected: node.id === modelValue }"
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

      </div>
    </template>

    <div class="create-row">
      <button
        type="button"
        class="key add-key"
        :class="{ active: showCreateForm }"
        :aria-expanded="showCreateForm"
        @click="toggleCreateForm"
      >
        <AppIcon name="plus" />新增分類
      </button>
      <span v-if="selectedLeafHere" class="create-target" role="group" aria-label="新增位置">
        <button type="button" class="btn sm" :class="{ on: !createUnderSelected }" :aria-pressed="!createUnderSelected" @click="createUnderSelected = false">
          加在「{{ currentLevelLabel }}」
        </button>
        <button type="button" class="btn sm" :class="{ on: createUnderSelected }" :aria-pressed="createUnderSelected" @click="createUnderSelected = true">
          加在「{{ selectedLeafHere.name }}」底下
        </button>
      </span>
      <span v-else-if="!showCreateForm" class="create-where">加在「{{ currentLevelLabel }}」</span>
      <form v-if="showCreateForm" class="create-form" @submit.prevent="handleCreate">
        <input
          v-model="newCategoryName"
          type="text"
          maxlength="100"
          :placeholder="`在「${createTargetLabel}」新增分類`"
          aria-label="新分類名稱"
          required
        />
        <button class="btn primary sm" type="submit" :disabled="isCreating">
          {{ isCreating ? '新增中…' : '確認新增' }}
        </button>
      </form>
    </div>
    <div v-if="createError" class="error-banner">{{ createError }}</div>

    <template v-if="!hideSelectedHint">
      <p v-if="modelValue" class="selected-hint">已選擇 <span class="selected-path">{{ selectedCategoryPath }}</span></p>
      <p v-else class="selected-hint missing">尚未選擇分類</p>
    </template>
  </div>
</template>
