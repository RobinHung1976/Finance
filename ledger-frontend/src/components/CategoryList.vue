<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import CategoryPicker from './CategoryPicker.vue'
import CategoryTreeNode from './CategoryTreeNode.vue'
import AppIcon from './AppIcon.vue'
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

const typeCount = computed(() => categories.value.filter((c) => c.type === activeType.value).length)

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
  <section class="panel">
    <div class="panel-head">
      <h2><AppIcon name="folder" />建立分類</h2>
      <span class="spacer"></span>
      <div class="keypad" role="radiogroup" aria-label="收支類型">
        <button
          type="button"
          role="radio"
          class="key"
          :class="{ active: activeType === 'expense' }"
          :aria-checked="activeType === 'expense'"
          @click="activeType = 'expense'"
        >
          <AppIcon name="expense" class="ic-expense" />支出
        </button>
        <button
          type="button"
          role="radio"
          class="key"
          :class="{ active: activeType === 'income' }"
          :aria-checked="activeType === 'income'"
          @click="activeType = 'income'"
        >
          <AppIcon name="income" class="ic-income" />收入
        </button>
      </div>
    </div>
    <div class="panel-body">
      <div v-if="loadError" class="error-banner">{{ loadError }}</div>
      <p class="hint intro">逐層點選進入下一層,在要放的層級按「+ 新增分類」。</p>
      <CategoryPicker
        v-model="browsingSelection"
        :type="activeType"
        :categories="categories"
        :hide-selected-hint="true"
        @created="handleCategoryCreated"
      />
    </div>
  </section>

  <section class="panel">
    <div class="panel-head">
      <h2><AppIcon name="table" />全部分類</h2>
      <span class="pill">{{ activeType === 'expense' ? '支出' : '收入' }}・{{ typeCount }} 個</span>
    </div>
    <div class="toolbar">
      <input v-model="treeSearchQuery" type="search" placeholder="搜尋分類(不限層級,例如:晚餐)" aria-label="搜尋分類" />
    </div>

    <template v-if="isTreeSearching">
      <div v-if="searchResults.length" class="table-wrap">
        <table class="grid">
          <thead>
            <tr>
              <th>分類路徑</th>
              <th class="num">操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="r in searchResults" :key="r.category.id">
              <td>
                <form v-if="editingId === r.category.id" class="row rename" @submit.prevent="saveSearchEdit(r.category.id)">
                  <input v-model="editName" type="text" maxlength="100" aria-label="新名稱" />
                  <button class="btn primary sm" type="submit">儲存</button>
                  <button type="button" class="btn sm" @click="cancelEdit">取消</button>
                  <span v-if="editError" class="field-error">{{ editError }}</span>
                </form>
                <span v-else>{{ r.label }}</span>
              </td>
              <td class="actions">
                <template v-if="editingId !== r.category.id">
                  <button type="button" class="btn sm" @click="startEdit(r.category)"><AppIcon name="edit" />改名</button>
                  <button type="button" class="btn danger sm" @click="handleDelete(r.category.id)"><AppIcon name="trash" />刪除</button>
                </template>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <p v-else class="empty">找不到符合「{{ treeSearchQuery }}」的分類。</p>
    </template>

    <template v-else>
      <div v-if="rootCategories.length" class="tree">
        <CategoryTreeNode
          v-for="root in rootCategories"
          :key="root.id"
          :category="root"
          :categories="categories"
          :depth="0"
          @delete="handleDelete"
          @rename="handleRename"
        />
      </div>
      <p v-else-if="!isLoading" class="empty">此類型尚未建立任何分類。</p>
    </template>
  </section>
</template>

<style scoped>
.panel-head .keypad { padding: 0; }
.ic-expense { color: var(--c-expense); }
.ic-income { color: var(--c-income); }
.intro { margin: 0 0 10px; }
.rename { flex-wrap: nowrap; }
.rename input { flex: 1; min-width: 160px; }
.field-error { color: var(--bad); font-size: 12px; white-space: nowrap; }
.tree { padding: 4px 0 8px; }
</style>
