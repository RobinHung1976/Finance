<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { fetchTags, createTag, deleteTag } from '@/api/ledger'
import type { TagOut } from '@/types/ledger'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const emit = defineEmits<{ changed: [] }>()

const tags = ref<TagOut[]>([])
const isLoading = ref(true)
const loadError = ref('')
const newTagName = ref('')
const createError = ref('')
const isCreating = ref(false)

async function load() {
  isLoading.value = true
  loadError.value = ''
  try {
    tags.value = await fetchTags()
  } catch {
    loadError.value = '載入消費品項失敗'
  } finally {
    isLoading.value = false
  }
}

onMounted(load)

async function handleCreate() {
  createError.value = ''
  if (!newTagName.value.trim()) {
    createError.value = '請輸入名稱'
    return
  }
  isCreating.value = true
  try {
    const created = await createTag({ name: newTagName.value.trim() })
    tags.value.push(created)
    newTagName.value = ''
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    createError.value = axiosErr.response?.data?.detail ?? '新增失敗'
  } finally {
    isCreating.value = false
  }
}

async function handleDelete(id: string) {
  if (!confirm('確定刪除此消費品項？已使用此品項的交易將移除此標籤，交易本身不受影響。')) return
  try {
    await deleteTag(id)
    tags.value = tags.value.filter((t) => t.id !== id)
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    alert(axiosErr.response?.data?.detail ?? '刪除失敗')
  }
}
</script>

<template>
  <div>
    <h2 style="font-size: 15px; color: #6b7a74; text-transform: uppercase; letter-spacing: 0.04em; margin: 0 0 12px">
      消費品項管理
    </h2>
    <form class="inline-card" @submit.prevent="handleCreate" style="display: flex; gap: 8px; align-items: flex-start">
      <div style="flex: 1">
        <input
          v-model="newTagName"
          type="text"
          maxlength="50"
          placeholder="新增消費品項（例如：三媽）"
          style="width: 100%; padding: 8px 10px; border: 1px solid var(--color-border); border-radius: 6px; box-sizing: border-box"
        />
        <div v-if="createError" class="error-banner" style="margin-top: 6px">{{ createError }}</div>
      </div>
      <button class="btn-primary" type="submit" style="width: auto; padding: 8px 16px" :disabled="isCreating">
        {{ isCreating ? '新增中…' : '新增' }}
      </button>
    </form>

    <div v-if="loadError" class="error-banner">{{ loadError }}</div>
    <p v-if="!isLoading && tags.length === 0" style="color: #6b7a74; font-size: 13px">尚未建立任何消費品項。</p>

    <div v-for="t in tags" :key="t.id" class="row-card">
      <span>{{ t.name }}</span>
      <button class="btn-text-danger" @click="handleDelete(t.id)">刪除</button>
    </div>
  </div>
</template>
