<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import CategoryPicker from './CategoryPicker.vue'
import CategoryTreeNode from './CategoryTreeNode.vue'
import { fetchCategories, updateCategory, deleteCategory } from '@/api/ledgerApi'
import type { CategoryOut, EntryType } from '@/types/ledger'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const emit = defineEmits<{ changed: [] }>()

const categories = ref<CategoryOut[]>([])
const isLoading = ref(true)
const loadError = ref('')

const activeType = ref<EntryType>('expense')
// CategoryPicker 需要 v-model,但此頁純粹用來瀏覽/建立結構,不需要真正「選定」某個分類
const browsingSelection = ref('')

const treeSearchQuery = ref('')
const isTreeSearching = computed(() => treeSearchQuery.value.trim().length > 0)

const editingId = ref<string | null>(null)
const editName = ref('')
const editError = ref('')

async function load() {
  isLoading.value = true
  try {
    categories.value = await fetchCategories()
  } catch {
    loadError.value = '載入分類失敗'
  } finally {
    isLoading.value = false
  }
}

onMounted(load)

function handleCategoryCreated(category: CategoryOut) {
  categories.value.push(category)
  emit('changed')
}

const rootCategories = computed(() =>
  categories.value.filter((c) => c.type === activeType.value && c.parent_id === null)
)

function ancestorChain(category: CategoryOut): CategoryOut[] {
  const chain: CategoryOut[] = []
  let node: CategoryOut | undefined = category
  while (node) {
    chain.unshift(node)
    node = node.parent_id ? categories.value.find((c) => c.id === node!.parent_id) : undefined
  }
  return chain
}
function fullPathLabel(category: CategoryOut): string {
  return ancestorChain(category).map((c) => c.name).join(' › ')
}

const searchResults = computed(() => {
  const q = treeSearchQuery.value.trim().toLowerCase()
  if (!q) return []
  return categories.value
    .filter((c) => c.type === activeType.value && c.name.toLowerCase().includes(q))
    .map((c) => ({ category: c, label: fullPathLabel(c) }))
    .sort((a, b) => a.label.localeCompare(b.label))
    .slice(0, 50)
})

async function handleDelete(id: string) {
  if (!confirm('確定刪除此分類？')) return
  try {
    await deleteCategory(id)
    await load()
    editingId.value = null
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    alert(axiosErr.response?.data?.detail ?? '刪除失敗(可能仍有子分類或交易紀錄使用中)')
  }
}

async function handleRename(id: string, name: string): Promise<boolean> {
  try {
    const updated = await updateCategory(id, { name })
    const idx = categories.value.findIndex((c) => c.id === id)
    if (idx !== -1) categories.value[idx] = updated
    emit('changed')
    return true
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    alert(axiosErr.response?.data?.detail ?? '改名失敗')
    return false
  }
}

function startEdit(category: CategoryOut) {
  editingId.value = category.id
  editName.value = category.name
  editError.value = ''
}
function cancelEdit() {
  editingId.value = null
  editError.value = ''
}
async function saveSearchEdit(id: string) {
  editError.value = ''
  const trimmed = editName.value.trim()
  if (!trimmed) {
    editError.value = '請輸入分類名稱'
    return
  }
  const target = categories.value.find((c) => c.id === id)
  const isDuplicate = categories.value.some(
    (c) => c.id !== id && c.parent_id === target?.parent_id && c.name.trim().toLowerCase() === trimmed.toLowerCase()
  )
  if (isDuplicate) {
    editError.value = '此層級已有同名分類'
    return
  }
  const ok = await handleRename(id, trimmed)
  if (ok) editingId.value = null
}
</script>

<template>
  <div>
    <h2 class="section-title">分類</h2>

    <div v-if="loadError" class="error-banner">{{ loadError }}</div>

    <div class="type-toggle">
      <button :class="{ active: activeType === 'expense' }" @click="activeType = 'expense'">支出</button>
      <button :class="{ active: activeType === 'income' }" @click="activeType = 'income'">收入</button>
    </div>

    <CategoryPicker
      v-model="browsingSelection"
      :type="activeType"
      :categories="categories"
      :hide-selected-hint="true"
      @created="handleCategoryCreated"
    />

    <p v-if="!isLoading && categories.length === 0" style="color: #6b7a74; font-size: 13px; margin-top: 16px">
      尚未建立任何分類。
    </p>

    <h3 class="section-title" style="margin-top: 20px">全部分類</h3>
    <input
      v-model="treeSearchQuery"
      type="text"
      placeholder="搜尋分類(不限層級,例如：晚餐)"
      style="width: 100%; padding: 8px 10px; margin-bottom: 12px; border: 1px solid var(--color-border); border-radius: 6px; box-sizing: border-box"
    />

    <template v-if="isTreeSearching">
      <p v-if="searchResults.length === 0" style="color: #6b7a74; font-size: 13px">
        找不到符合「{{ treeSearchQuery }}」的分類。
      </p>
      <div v-for="r in searchResults" :key="r.category.id" class="row-card">
        <template v-if="editingId !== r.category.id">
          <span>{{ r.label }}</span>
          <div style="display: flex; gap: 12px">
            <button class="btn-text" @click="startEdit(r.category)">改名</button>
            <button class="btn-text-danger" @click="handleDelete(r.category.id)">刪除</button>
          </div>
        </template>
        <form
          v-else
          style="display: flex; gap: 8px; align-items: center; width: 100%"
          @submit.prevent="saveSearchEdit(r.category.id)"
        >
          <input
            v-model="editName"
            type="text"
            maxlength="100"
            style="flex: 1; padding: 6px 10px; border: 1px solid var(--color-border); border-radius: 6px"
          />
          <button class="btn-primary" type="submit" style="width: auto; padding: 6px 14px">儲存</button>
          <button type="button" class="btn-text" @click="cancelEdit">取消</button>
        </form>
        <div v-if="editingId === r.category.id && editError" class="error-banner" style="width: 100%; margin-top: 4px">
          {{ editError }}
        </div>
      </div>
    </template>

    <template v-else>
      <div v-if="rootCategories.length === 0" style="color: #6b7a74; font-size: 13px">
        此類型尚未建立任何分類。
      </div>
      <CategoryTreeNode
        v-for="root in rootCategories"
        :key="root.id"
        :category="root"
        :categories="categories"
        :depth="0"
        @delete="handleDelete"
        @rename="handleRename"
      />
    </template>
  </div>
</template>

<style scoped>
.section-title {
  font-size: 15px;
  color: #6b7a74;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  margin: 0 0 12px;
  font-weight: 600;
}

.type-toggle {
  display: flex;
  gap: 4px;
  margin-bottom: 12px;
}

.type-toggle button {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 6px;
  padding: 6px 16px;
  font-size: 13px;
  cursor: pointer;
}

.type-toggle button.active {
  background: var(--color-primary);
  color: #fff;
  border-color: var(--color-primary);
}

.row-card {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  margin-bottom: 8px;
}

.btn-text-danger {
  background: none;
  border: none;
  color: var(--color-danger);
  font-size: 13px;
  padding: 4px 8px;
}
</style>
