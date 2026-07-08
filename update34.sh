#!/usr/bin/env bash
set -euo pipefail

FRONTEND=ledger-frontend
[ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

# ---------- TagList.vue:完整覆寫(chip 網格 + 最近使用分區 + 詳情面板) ----------
cat > "$FRONTEND/src/components/TagList.vue" << 'EOF'
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { fetchTags, createTag, updateTag, deleteTag } from '@/api/ledger'
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

    <input
      v-model="searchQuery"
      type="text"
      placeholder="搜尋消費品項"
      style="width: 100%; padding: 8px 10px; margin: 12px 0; border: 1px solid var(--color-border); border-radius: 6px; box-sizing: border-box"
    />

    <div v-if="loadError" class="error-banner">{{ loadError }}</div>
    <p v-if="!isLoading && tags.length === 0" style="color: #6b7a74; font-size: 13px">尚未建立任何消費品項。</p>
    <p v-if="!isLoading && tags.length > 0 && isSearching && filteredTags.length === 0" style="color: #6b7a74; font-size: 13px">
      找不到符合「{{ searchQuery }}」的消費品項。
    </p>

    <template v-if="!isSearching">
      <div v-if="recentTags.length" class="tag-section-label">最近使用</div>
      <div v-if="recentTags.length" class="tag-grid">
        <button
          v-for="t in recentTags"
          :key="t.id"
          type="button"
          class="tag-chip"
          :class="{ active: activeTagId === t.id, unused: t.usage_count === 0 }"
          @click="toggleActive(t.id)"
        >
          {{ t.name }} <span class="tag-count">{{ t.usage_count }}</span>
        </button>
      </div>

      <div v-if="recentTags.length && otherTags.length" class="tag-section-label">全部品項</div>
      <div v-if="otherTags.length" class="tag-grid">
        <button
          v-for="t in otherTags"
          :key="t.id"
          type="button"
          class="tag-chip"
          :class="{ active: activeTagId === t.id, unused: t.usage_count === 0 }"
          @click="toggleActive(t.id)"
        >
          {{ t.name }} <span class="tag-count">{{ t.usage_count }}</span>
        </button>
      </div>
    </template>

    <template v-else>
      <div class="tag-grid">
        <button
          v-for="t in filteredTags"
          :key="t.id"
          type="button"
          class="tag-chip"
          :class="{ active: activeTagId === t.id, unused: t.usage_count === 0 }"
          @click="toggleActive(t.id)"
        >
          {{ t.name }} <span class="tag-count">{{ t.usage_count }}</span>
        </button>
      </div>
    </template>

    <div v-if="activeTag" class="row-card" style="flex-direction: column; align-items: stretch; gap: 8px; margin-top: 12px">
      <template v-if="editingId !== activeTag.id">
        <div style="display: flex; justify-content: space-between; align-items: center">
          <div>
            <strong>{{ activeTag.name }}</strong>
            <span style="color: #6b7a74; font-size: 13px; margin-left: 8px">
              使用 {{ activeTag.usage_count }} 次<template v-if="activeTag.last_used_date">，最後使用於 {{ activeTag.last_used_date }}</template>
            </span>
          </div>
          <div style="display: flex; gap: 12px">
            <button class="btn-text" @click="startEdit(activeTag)">改名</button>
            <button class="btn-text-danger" @click="handleDelete(activeTag)">刪除</button>
            <button class="btn-text" @click="activeTagId = null">關閉</button>
          </div>
        </div>
      </template>
      <form v-else style="display: flex; gap: 8px; align-items: center" @submit.prevent="saveEdit(activeTag.id)">
        <input
          v-model="editName"
          type="text"
          maxlength="50"
          style="flex: 1; padding: 6px 10px; border: 1px solid var(--color-border); border-radius: 6px"
        />
        <button class="btn-primary" type="submit" style="width: auto; padding: 6px 14px" :disabled="isSavingEdit">
          {{ isSavingEdit ? '儲存中…' : '儲存' }}
        </button>
        <button type="button" class="btn-text" @click="cancelEdit">取消</button>
      </form>
      <div v-if="editingId === activeTag.id && editError" class="error-banner">{{ editError }}</div>
    </div>
  </div>
</template>

<style scoped>
.tag-section-label {
  font-size: 11px;
  color: #8a948e;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  margin: 12px 0 6px;
}
.tag-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.tag-chip {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 999px;
  padding: 6px 14px;
  font-size: 13px;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 6px;
}
.tag-chip.unused {
  color: #a3aca7;
}
.tag-chip.active {
  border-color: var(--color-primary);
  background: var(--color-primary);
  color: #fff;
  font-weight: 600;
}
.tag-count {
  font-size: 11px;
  opacity: 0.75;
}
</style>
EOF
echo "✅ TagList.vue 已覆寫"

echo "✅ 檔案已寫入完成"
git add -A
git commit -m "feat: 消費品項管理頁改為 chip 網格,加入最近使用分區與單一詳情面板"
echo "✅ 已 commit,請執行 'git push origin main',再到 server 跑 ./deploy.sh"
