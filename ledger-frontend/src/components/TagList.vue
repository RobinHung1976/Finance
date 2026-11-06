<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { fetchTags, createTag, updateTag, deleteTag } from '@/api/ledgerApi'
import AppIcon from './AppIcon.vue'
import type { TagOut } from '@/types/ledger'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const RECENT_LIMIT = 12

const emit = defineEmits<{ changed: [] }>()

const tags = ref<TagOut[]>([])
const isLoading = ref(true)
const loadError = ref('')
const newTagName = ref('')
const createError = ref('')
const isCreating = ref(false)
const searchQuery = ref('')

const activeTagId = ref<string | null>(null)
const editingId = ref<string | null>(null)
const editName = ref('')
const editError = ref('')
const isSavingEdit = ref(false)

const isSearching = computed(() => searchQuery.value.trim().length > 0)

const filteredTags = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return tags.value
  return tags.value.filter((t) => t.name.toLowerCase().includes(q))
})

const recentTags = computed(() => {
  return tags.value
    .filter((t) => t.last_used_date)
    .sort((a, b) => (b.last_used_date! < a.last_used_date! ? -1 : 1))
    .slice(0, RECENT_LIMIT)
})

const otherTags = computed(() => {
  const recentIds = new Set(recentTags.value.map((t) => t.id))
  return tags.value.filter((t) => !recentIds.has(t.id))
})

const activeTag = computed(() => tags.value.find((t) => t.id === activeTagId.value) ?? null)

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

function isDuplicateName(name: string, excludeId?: string): boolean {
  const lower = name.trim().toLowerCase()
  return tags.value.some((t) => t.id !== excludeId && t.name.trim().toLowerCase() === lower)
}

function toggleActive(id: string) {
  if (activeTagId.value === id) {
    activeTagId.value = null
    editingId.value = null
    return
  }
  activeTagId.value = id
  editingId.value = null
  editError.value = ''
}

async function handleCreate() {
  createError.value = ''
  const trimmedName = newTagName.value.trim()
  if (!trimmedName) {
    createError.value = '請輸入名稱'
    return
  }
  if (isDuplicateName(trimmedName)) {
    createError.value = '此消費品項名稱已存在,請直接使用現有品項'
    return
  }
  isCreating.value = true
  try {
    const created = await createTag({ name: trimmedName })
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
    activeTagId.value = null
    editingId.value = null
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
      <h2><AppIcon name="tag" />消費品項</h2>
      <span v-if="!isLoading" class="pill">{{ tags.length }} 個</span>
      <span class="spacer"></span>
      <form class="row create" @submit.prevent="handleCreate">
        <input v-model="newTagName" type="text" maxlength="50" placeholder="新增消費品項(例如:三媽)" aria-label="新消費品項名稱" />
        <button class="btn primary" type="submit" :disabled="isCreating">
          <AppIcon name="plus" />{{ isCreating ? '新增中…' : '新增' }}
        </button>
      </form>
    </div>

    <div v-if="createError || loadError" class="panel-body msgs">
      <div v-if="createError" class="error-banner" role="alert">{{ createError }}</div>
      <div v-if="loadError" class="error-banner">{{ loadError }}</div>
    </div>

    <div class="toolbar">
      <input v-model="searchQuery" type="search" placeholder="搜尋消費品項" aria-label="搜尋消費品項" />
      <span class="hint">點選品項可改名或刪除;數字為使用次數</span>
    </div>

    <div class="panel-body">
      <p v-if="!isLoading && tags.length === 0" class="empty">尚未建立任何消費品項。</p>
      <p v-else-if="isSearching && filteredTags.length === 0" class="empty">找不到符合「{{ searchQuery }}」的消費品項。</p>

      <template v-if="!isSearching">
        <template v-if="recentTags.length">
          <div class="section-label">最近使用</div>
          <div class="tag-grid">
            <button
              v-for="t in recentTags"
              :key="t.id"
              type="button"
              class="tag-key"
              :class="{ active: activeTagId === t.id, unused: t.usage_count === 0 }"
              :aria-pressed="activeTagId === t.id"
              @click="toggleActive(t.id)"
            >
              {{ t.name }}<span class="tag-count">{{ t.usage_count }}</span>
            </button>
          </div>
        </template>
        <template v-if="otherTags.length">
          <div v-if="recentTags.length" class="section-label">全部品項</div>
          <div class="tag-grid">
            <button
              v-for="t in otherTags"
              :key="t.id"
              type="button"
              class="tag-key"
              :class="{ active: activeTagId === t.id, unused: t.usage_count === 0 }"
              :aria-pressed="activeTagId === t.id"
              @click="toggleActive(t.id)"
            >
              {{ t.name }}<span class="tag-count">{{ t.usage_count }}</span>
            </button>
          </div>
        </template>
      </template>

      <div v-else class="tag-grid">
        <button
          v-for="t in filteredTags"
          :key="t.id"
          type="button"
          class="tag-key"
          :class="{ active: activeTagId === t.id, unused: t.usage_count === 0 }"
          :aria-pressed="activeTagId === t.id"
          @click="toggleActive(t.id)"
        >
          {{ t.name }}<span class="tag-count">{{ t.usage_count }}</span>
        </button>
      </div>
    </div>

    <div v-if="activeTag" class="detail">
      <form v-if="editingId === activeTag.id" class="row rename" @submit.prevent="saveEdit(activeTag.id)">
        <input v-model="editName" type="text" maxlength="50" aria-label="新名稱" />
        <button class="btn primary sm" type="submit" :disabled="isSavingEdit">
          {{ isSavingEdit ? '儲存中…' : '儲存' }}
        </button>
        <button type="button" class="btn sm" @click="cancelEdit">取消</button>
        <span v-if="editError" class="field-error">{{ editError }}</span>
      </form>
      <template v-else>
        <b>{{ activeTag.name }}</b>
        <span class="hint">
          使用 {{ activeTag.usage_count }} 次<template v-if="activeTag.last_used_date">,最後使用於 {{ activeTag.last_used_date }}</template>
        </span>
        <span class="spacer"></span>
        <button type="button" class="btn sm" @click="startEdit(activeTag)"><AppIcon name="edit" />改名</button>
        <button type="button" class="btn danger sm" @click="handleDelete(activeTag)"><AppIcon name="trash" />刪除</button>
        <button type="button" class="btn ghost sm" @click="activeTagId = null"><AppIcon name="x" />關閉</button>
      </template>
    </div>
  </section>
</template>

<style scoped>
.create { flex-wrap: nowrap; }
.create input { width: 260px; }
.msgs { padding-bottom: 0; }
.section-label { margin: 0 0 8px; font-size: 12px; font-weight: 700; color: var(--muted); }
.tag-grid + .section-label { margin-top: 18px; }
.tag-grid { display: flex; flex-wrap: wrap; gap: 8px; }
.tag-key {
  display: inline-flex; align-items: center; gap: 7px; height: 32px; padding: 0 12px;
  font: inherit; font-size: 13.5px; font-weight: 700; color: #22272e; text-shadow: 0 1px 0 #fff;
  border: 1px solid #959ca6; border-radius: 999px; background: var(--metal-key); cursor: pointer;
  box-shadow: inset 0 1px 0 #fff, 0 1px 2px rgb(0 0 0 / 18%);
}
.tag-key:hover { background: var(--metal-key-hover); }
.tag-key.unused { color: #7d8590; font-weight: 600; }
.tag-key.active {
  color: #fff; text-shadow: 0 -1px 0 rgb(0 0 0 / 35%); border-color: var(--brand-edge); background: var(--brand-metal-lit);
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 45%), 0 0 8px var(--brand-glow);
}
.tag-count {
  min-width: 20px; padding: 0 6px; border-radius: 999px; font-size: 11px; line-height: 18px; text-align: center;
  background: rgb(0 0 0 / 8%); font-variant-numeric: tabular-nums;
}
.tag-key.active .tag-count { background: rgb(255 255 255 / 25%); }
.detail {
  display: flex; align-items: center; gap: 10px; flex-wrap: wrap; padding: 12px 20px;
  border-top: 1px solid var(--line-soft); background: rgb(255 255 255 / 45%); border-radius: 0 0 var(--radius) var(--radius);
}
.detail .spacer { flex: 1; }
.rename { flex: 1; flex-wrap: nowrap; }
.rename input { flex: 1; max-width: 320px; }
.field-error { color: var(--bad); font-size: 12px; white-space: nowrap; }
</style>
