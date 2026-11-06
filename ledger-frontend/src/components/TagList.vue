<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import type { AxiosError } from 'axios'
import AppIcon from './AppIcon.vue'
import TagPicker from './TagPicker.vue'
import { fetchTags, updateTag, deleteTag } from '@/api/ledgerApi'
import type { TagOut } from '@/types/ledger'
import type { ApiError } from '@/types/api'

// 版面比照分類頁:上方「建立消費品項」用 TagPicker 瀏覽/新增,下方「全部消費品項」列表改名/刪除

const emit = defineEmits<{ changed: [] }>()

const tags = ref<TagOut[]>([])
const isLoading = ref(true)
const loadError = ref('')

// TagPicker 需要 v-model,但此頁純粹用來瀏覽/建立,不需要真正「選定」品項
const browsingSelection = ref<string[]>([])

const listSearchQuery = ref('')
const isListSearching = computed(() => listSearchQuery.value.trim().length > 0)

const editingId = ref<string | null>(null)
const editName = ref('')
const editError = ref('')
const isSavingEdit = ref(false)

// 後端已依使用次數多→少、名稱排序
const listedTags = computed(() => {
  const q = listSearchQuery.value.trim().toLowerCase()
  return q ? tags.value.filter((t) => t.name.toLowerCase().includes(q)) : tags.value
})

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

function handleTagCreated(tag: TagOut) {
  tags.value.push(tag)
  emit('changed')
}

function isDuplicateName(name: string, excludeId: string): boolean {
  const lower = name.trim().toLowerCase()
  return tags.value.some((t) => t.id !== excludeId && t.name.trim().toLowerCase() === lower)
}

function startEdit(tag: TagOut) {
  editingId.value = tag.id
  editName.value = tag.name
  editError.value = ''
}

function cancelEdit() {
  editingId.value = null
  editError.value = ''
}

async function saveEdit(id: string) {
  editError.value = ''
  const trimmedName = editName.value.trim()
  if (!trimmedName) {
    editError.value = '請輸入名稱'
    return
  }
  if (isDuplicateName(trimmedName, id)) {
    editError.value = '此消費品項名稱已存在,請直接使用現有品項'
    return
  }
  isSavingEdit.value = true
  try {
    const updated = await updateTag(id, { name: trimmedName })
    const idx = tags.value.findIndex((t) => t.id === id)
    if (idx !== -1) tags.value[idx] = updated
    editingId.value = null
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    editError.value = axiosErr.response?.data?.detail ?? '更新失敗'
  } finally {
    isSavingEdit.value = false
  }
}

async function handleDelete(tag: TagOut) {
  const message =
    tag.usage_count > 0
      ? `此消費品項已掛用於 ${tag.usage_count} 筆交易,刪除後這些交易將移除此標籤,交易本身不受影響。確定刪除？`
      : '確定刪除此消費品項？'
  if (!confirm(message)) return
  try {
    await deleteTag(tag.id)
    tags.value = tags.value.filter((t) => t.id !== tag.id)
    browsingSelection.value = browsingSelection.value.filter((id) => id !== tag.id)
    if (editingId.value === tag.id) editingId.value = null
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    alert(axiosErr.response?.data?.detail ?? '刪除失敗')
  }
}
</script>

<template>
  <section class="panel">
    <div class="panel-head">
      <h2><AppIcon name="tag" />建立消費品項</h2>
    </div>
    <div class="panel-body">
      <div v-if="loadError" class="error-banner">{{ loadError }}</div>
      <p class="hint intro">先搜尋或瀏覽既有品項,沒有的話按「新增品項」。</p>
      <TagPicker v-model="browsingSelection" :tags="tags" @created="handleTagCreated" />
    </div>
  </section>

  <section class="panel">
    <div class="panel-head">
      <h2><AppIcon name="table" />全部消費品項</h2>
      <span class="pill">{{ tags.length }} 個</span>
    </div>
    <div class="toolbar">
      <input v-model="listSearchQuery" type="search" placeholder="搜尋消費品項" aria-label="搜尋消費品項" />
    </div>

    <div v-if="listedTags.length" class="table-wrap">
      <table class="grid">
        <thead>
          <tr>
            <th>品項</th>
            <th class="num">使用次數</th>
            <th>最後使用</th>
            <th class="num">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="t in listedTags" :key="t.id" :class="{ unused: t.usage_count === 0 }">
            <td>
              <form v-if="editingId === t.id" class="row rename" @submit.prevent="saveEdit(t.id)">
                <input v-model="editName" type="text" maxlength="50" aria-label="新名稱" />
                <button class="btn primary sm" type="submit" :disabled="isSavingEdit">
                  {{ isSavingEdit ? '儲存中…' : '儲存' }}
                </button>
                <button type="button" class="btn sm" @click="cancelEdit">取消</button>
                <span v-if="editError" class="field-error">{{ editError }}</span>
              </form>
              <b v-else>{{ t.name }}</b>
            </td>
            <td class="num">{{ t.usage_count }}</td>
            <td class="nowrap">{{ t.last_used_date ?? '—' }}</td>
            <td class="actions">
              <template v-if="editingId !== t.id">
                <button type="button" class="btn sm" @click="startEdit(t)"><AppIcon name="edit" />改名</button>
                <button type="button" class="btn danger sm" @click="handleDelete(t)"><AppIcon name="trash" />刪除</button>
              </template>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p v-else-if="isListSearching" class="empty">找不到符合「{{ listSearchQuery }}」的消費品項。</p>
    <p v-else-if="!isLoading" class="empty">尚未建立任何消費品項。</p>
  </section>
</template>

<style scoped>
.intro { margin: 0 0 10px; }
.rename { flex-wrap: nowrap; }
.rename input { flex: 1; min-width: 160px; max-width: 320px; }
.field-error { color: var(--bad); font-size: 12px; white-space: nowrap; }
tr.unused td:not(.actions) { color: var(--muted); }
</style>
