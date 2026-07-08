<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import CategoryPicker from './CategoryPicker.vue'
import CategoryTreeNode from './CategoryTreeNode.vue'
import { fetchCategories, updateCategory, deleteCategory } from '@/api/ledger'
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

async function handleDelete(id: string) {
  if (!confirm('確定刪除此分類？')) return
  try {
    await deleteCategory(id)
    await load()
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    alert(axiosErr.response?.data?.detail ?? '刪除失敗(可能仍有子分類或交易紀錄使用中)')
  }
}

async function handleRename(id: string, name: string) {
  try {
    const updated = await updateCategory(id, { name })
    const idx = categories.value.findIndex((c) => c.id === id)
    if (idx !== -1) categories.value[idx] = updated
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    alert(axiosErr.response?.data?.detail ?? '改名失敗')
  }
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
      @created="handleCategoryCreated"
    />

    <p v-if="!isLoading && categories.length === 0" style="color: #6b7a74; font-size: 13px; margin-top: 16px">
      尚未建立任何分類。
    </p>

    <h3 class="section-title" style="margin-top: 20px">全部分類</h3>
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
