<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { createCategory } from '@/api/ledger'
import type { CategoryOut, EntryType } from '@/types/ledger'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const props = defineProps<{
  categories: CategoryOut[]
  type: EntryType
  modelValue: string
}>()

const emit = defineEmits<{
  'update:modelValue': [value: string]
  created: [category: CategoryOut]
}>()

// 麵包屑路徑:目前鑽取到哪一層(空陣列 = 頂層)
const path = ref<CategoryOut[]>([])

// 收支類型變更時,舊路徑可能指向錯誤類型的分類,重置回頂層
watch(
  () => props.type,
  () => {
    path.value = []
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

function selectCategory(category: CategoryOut) {
  emit('update:modelValue', category.id)
  path.value.push(category) // 一律往下鑽,允許之後把此節點當父層繼續新增子分類
}

function jumpToBreadcrumb(index: number) {
  if (index < 0) {
    path.value = []
    return
  }
  path.value = path.value.slice(0, index + 1)
  emit('update:modelValue', path.value[index].id)
}

const showCreateForm = ref(false)
const newCategoryName = ref('')
const createError = ref('')
const isCreating = ref(false)

async function handleCreate() {
  createError.value = ''
  if (!newCategoryName.value.trim()) {
    createError.value = '請輸入分類名稱'
    return
  }
  isCreating.value = true
  try {
    const created = await createCategory({
      name: newCategoryName.value.trim(),
      type: props.type,
      parent_id: currentParentId.value,
    })
    emit('created', created)
    emit('update:modelValue', created.id)
    path.value.push(created) // 自動鑽入剛建立的分類,方便立即新增子分類(例如:信用卡 > 富邦)
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

    <form v-if="showCreateForm" class="create-form" @submit.prevent="handleCreate">
      <input v-model="newCategoryName" type="text" maxlength="100" placeholder="分類名稱" required />
      <button class="btn-primary" type="submit" style="width: auto; padding: 6px 14px" :disabled="isCreating">
        {{ isCreating ? '新增中…' : '確認' }}
      </button>
    </form>
    <div v-if="createError" class="error-banner" style="margin-top: 6px">{{ createError }}</div>

    <p v-if="modelValue" class="selected-hint">已選擇：{{ selectedCategoryName }}</p>
    <p v-else class="selected-hint" style="color: var(--color-danger)">尚未選擇分類</p>
  </div>
</template>

<style scoped>
.category-picker {
  border: 1px solid var(--color-border);
  border-radius: 8px;
  padding: 10px;
  background: var(--color-bg);
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
