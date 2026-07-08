#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
FRONTEND=ledger-frontend
[ -d "$BACKEND" ] && [ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

# ========== api/ledger.ts:補 updateTag ==========
python3 << 'PYEOF'
path = "ledger-frontend/src/api/ledger.ts"
with open(path) as f:
    content = f.read()

old = """export function deleteTag(id: string) {
  return apiClient.delete(`/tags/${id}`)
}"""
new = """export function updateTag(id: string, payload: TagCreatePayload) {
  return apiClient.patch<TagOut>(`/tags/${id}`, payload).then((r) => r.data)
}
export function deleteTag(id: string) {
  return apiClient.delete(`/tags/${id}`)
}"""
if old not in content:
    raise SystemExit("❌ deleteTag 錨點不符")
content = content.replace(old, new, 1)
with open(path, "w") as f:
    f.write(content)
print("✅ api/ledger.ts 已加入 updateTag")
PYEOF

# ========== CategoryPicker.vue:同層重複直接擋掉 ==========
python3 << 'PYEOF'
path = "ledger-frontend/src/components/CategoryPicker.vue"
with open(path) as f:
    content = f.read()

old = """async function handleCreate() {
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
    })"""
new = """async function handleCreate() {
  createError.value = ''
  const trimmedName = newCategoryName.value.trim()
  if (!trimmedName) {
    createError.value = '請輸入分類名稱'
    return
  }
  const isDuplicate = currentLevelCategories.value.some(
    (c) => c.name.trim().toLowerCase() === trimmedName.toLowerCase()
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
      parent_id: currentParentId.value,
    })"""
if old not in content:
    raise SystemExit("❌ CategoryPicker handleCreate 錨點不符")
content = content.replace(old, new, 1)
with open(path, "w") as f:
    f.write(content)
print("✅ CategoryPicker.vue 已加入同層重複阻擋")
PYEOF

# ========== TagPicker.vue:重複時前端立即提示 ==========
python3 << 'PYEOF'
path = "ledger-frontend/src/components/TagPicker.vue"
with open(path) as f:
    content = f.read()

old = """async function handleCreate() {
  createError.value = ''
  if (!newTagName.value.trim()) {
    createError.value = '請輸入消費品項名稱'
    return
  }
  isCreating.value = true
  try {
    const created = await createTag({ name: newTagName.value.trim() })"""
new = """async function handleCreate() {
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
    const created = await createTag({ name: trimmedName })"""
if old not in content:
    raise SystemExit("❌ TagPicker handleCreate 錨點不符")
content = content.replace(old, new, 1)
with open(path, "w") as f:
    f.write(content)
print("✅ TagPicker.vue 已加入重複前端提示")
PYEOF

# ========== TagList.vue:加入重複阻擋 + 改名功能(整檔覆寫) ==========
cat > "$FRONTEND/src/components/TagList.vue" << 'VUEEOF'
<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { fetchTags, createTag, updateTag, deleteTag } from '@/api/ledger'
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

const editingId = ref<string | null>(null)
const editName = ref('')
const editError = ref('')
const isSavingEdit = ref(false)

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
      <template v-if="editingId !== t.id">
        <span>{{ t.name }}</span>
        <div style="display: flex; gap: 12px">
          <button class="btn-text" @click="startEdit(t)">改名</button>
          <button class="btn-text-danger" @click="handleDelete(t.id)">刪除</button>
        </div>
      </template>
      <form v-else style="display: flex; gap: 8px; align-items: center; width: 100%" @submit.prevent="saveEdit(t.id)">
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
      <div v-if="editingId === t.id && editError" class="error-banner" style="width: 100%; margin-top: 4px">
        {{ editError }}
      </div>
    </div>
  </div>
</template>
VUEEOF

git add -A
git commit -m "fix: CategoryPicker/TagPicker/TagList 加入重複名稱阻擋,TagList 新增改名功能"
echo "✅ 已 commit,請 push + deploy"
