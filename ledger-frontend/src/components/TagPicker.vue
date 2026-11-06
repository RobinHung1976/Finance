<script setup lang="ts">
import { ref, computed } from 'vue'
import { createTag } from '@/api/ledgerApi'
import type { TagOut } from '@/types/ledger'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const RECENT_LIMIT = 8

const props = defineProps<{
  modelValue: string[]
  tags: TagOut[]
}>()
const emit = defineEmits<{
  'update:modelValue': [value: string[]]
  created: [tag: TagOut]
}>()

const searchQuery = ref('')
const showCreateForm = ref(false)
const newTagName = ref('')
const createError = ref('')
const isCreating = ref(false)

const isSearching = computed(() => searchQuery.value.trim().length > 0)

const filteredTags = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return props.tags
  return props.tags.filter((t) => t.name.toLowerCase().includes(q))
})

// 最近使用:依 last_used_date 由新到舊排序,取前 N 個(無交易紀錄的品項不列入)
const recentTags = computed(() => {
  return props.tags
    .filter((t) => t.last_used_date)
    .sort((a, b) => (b.last_used_date! < a.last_used_date! ? -1 : 1))
    .slice(0, RECENT_LIMIT)
})

const otherTags = computed(() => {
  const recentIds = new Set(recentTags.value.map((t) => t.id))
  return props.tags.filter((t) => !recentIds.has(t.id))
})

function isSelected(id: string) {
  return props.modelValue.includes(id)
}

function toggleTag(id: string) {
  const next = isSelected(id) ? props.modelValue.filter((v) => v !== id) : [...props.modelValue, id]
  emit('update:modelValue', next)
}

async function handleCreate() {
  createError.value = ''
  const trimmedName = newTagName.value.trim()
  if (!trimmedName) {
    createError.value = '請輸入消費品項名稱'
    return
  }
  const isDuplicate = props.tags.some((t) => t.name.trim().toLowerCase() === trimmedName.toLowerCase())
  if (isDuplicate) {
    createError.value = '此消費品項名稱已存在,請直接選擇現有品項'
    return
  }
  isCreating.value = true
  try {
    const created = await createTag({ name: trimmedName })
    emit('created', created)
    emit('update:modelValue', [...props.modelValue, created.id])
    newTagName.value = ''
    showCreateForm.value = false
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    createError.value = axiosErr.response?.data?.detail ?? '新增失敗'
  } finally {
    isCreating.value = false
  }
}
</script>

<template>
  <div class="tag-picker">
    <input v-model="searchQuery" type="search" class="search-input" placeholder="搜尋消費品項…" />

    <template v-if="!isSearching">
      <div v-if="recentTags.length" class="tag-section-label">最近使用</div>
      <div v-if="recentTags.length" class="tag-grid">
        <button
          v-for="t in recentTags"
          :key="t.id"
          type="button"
          class="tag-btn"
          :class="{ selected: isSelected(t.id) }"
          @click="toggleTag(t.id)"
        >
          {{ t.name }}
        </button>
      </div>

      <div v-if="recentTags.length && otherTags.length" class="tag-section-label">全部品項</div>
      <div class="tag-grid">
        <button
          v-for="t in otherTags"
          :key="t.id"
          type="button"
          class="tag-btn"
          :class="{ selected: isSelected(t.id) }"
          @click="toggleTag(t.id)"
        >
          {{ t.name }}
        </button>
        <button type="button" class="tag-btn add-btn" @click="showCreateForm = !showCreateForm">
          + 新增品項
        </button>
      </div>
    </template>

    <template v-else>
      <div class="tag-grid">
        <button
          v-for="t in filteredTags"
          :key="t.id"
          type="button"
          class="tag-btn"
          :class="{ selected: isSelected(t.id) }"
          @click="toggleTag(t.id)"
        >
          {{ t.name }}
        </button>
        <button type="button" class="tag-btn add-btn" @click="showCreateForm = !showCreateForm">
          + 新增品項
        </button>
      </div>
    </template>

    <form v-if="showCreateForm" class="create-form" @submit.prevent="handleCreate">
      <input v-model="newTagName" type="text" maxlength="50" placeholder="品項名稱（例如：三媽）" required />
      <button class="btn primary sm" type="submit" :disabled="isCreating">
        {{ isCreating ? '新增中…' : '確認' }}
      </button>
    </form>
    <div v-if="createError" class="error-banner">{{ createError }}</div>
  </div>
</template>
