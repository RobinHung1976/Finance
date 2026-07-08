#!/usr/bin/env bash
set -euo pipefail

FRONTEND=ledger-frontend
[ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

# ========== api/ledger.ts:補 updateCategory ==========
python3 << 'PYEOF'
path = "ledger-frontend/src/api/ledger.ts"
with open(path) as f:
    content = f.read()

old = """export function deleteCategory(id: string) {
  return apiClient.delete(`/categories/${id}`)
}"""
new = """export function updateCategory(id: string, payload: Partial<CategoryCreatePayload>) {
  return apiClient.patch<CategoryOut>(`/categories/${id}`, payload).then((r) => r.data)
}
export function deleteCategory(id: string) {
  return apiClient.delete(`/categories/${id}`)
}"""
if old not in content:
    raise SystemExit("❌ deleteCategory 錨點不符")
content = content.replace(old, new, 1)
with open(path, "w") as f:
    f.write(content)
print("✅ api/ledger.ts 已加入 updateCategory")
PYEOF

# ========== CategoryTreeNode.vue:加入改名功能(整檔覆寫) ==========
cat > "$FRONTEND/src/components/CategoryTreeNode.vue" << 'VUEEOF'
<script setup lang="ts">
import { computed, ref } from 'vue'
import type { CategoryOut } from '@/types/ledger'
defineOptions({ name: 'CategoryTreeNode' }) // 遞迴自我參照元件需要明確命名
const props = defineProps<{
  category: CategoryOut
  categories: CategoryOut[]
  depth: number
}>()
const emit = defineEmits<{ delete: [id: string]; rename: [id: string, name: string] }>()
const isExpanded = ref(false)
const children = computed(() => props.categories.filter((c) => c.parent_id === props.category.id))
const hasChildren = computed(() => children.value.length > 0)

const isEditing = ref(false)
const editName = ref('')
const editError = ref('')

function startEdit() {
  editName.value = props.category.name
  editError.value = ''
  isEditing.value = true
}
function cancelEdit() {
  isEditing.value = false
  editError.value = ''
}
function saveEdit() {
  const trimmed = editName.value.trim()
  if (!trimmed) {
    editError.value = '請輸入分類名稱'
    return
  }
  // 同層級(同一個 parent_id)重複名稱阻擋,邏輯與 CategoryPicker 新增時一致
  const isDuplicate = props.categories.some(
    (c) =>
      c.id !== props.category.id &&
      c.parent_id === props.category.parent_id &&
      c.name.trim().toLowerCase() === trimmed.toLowerCase()
  )
  if (isDuplicate) {
    editError.value = '此層級已有同名分類'
    return
  }
  emit('rename', props.category.id, trimmed)
  isEditing.value = false
}

function handleDelete(id: string) {
  emit('delete', id)
}
function handleRename(id: string, name: string) {
  emit('rename', id, name)
}
</script>
<template>
  <div>
    <div class="node-row" :style="{ paddingLeft: depth * 20 + 'px' }">
      <button
        v-if="hasChildren"
        type="button"
        class="expand-btn"
        :aria-expanded="isExpanded"
        @click="isExpanded = !isExpanded"
      >
        {{ isExpanded ? '▾' : '▸' }}
      </button>
      <span v-else class="expand-spacer"></span>

      <template v-if="!isEditing">
        <strong class="node-name">{{ category.name }}</strong>
        <span v-if="hasChildren" class="child-count">({{ children.length }})</span>
        <div class="node-actions">
          <button class="btn-text" @click="startEdit">改名</button>
          <button class="btn-text-danger" @click="handleDelete(category.id)">刪除</button>
        </div>
      </template>
      <template v-else>
        <input v-model="editName" type="text" maxlength="100" class="edit-input" @keyup.enter="saveEdit" />
        <div class="node-actions">
          <button class="btn-text" @click="saveEdit">儲存</button>
          <button class="btn-text" @click="cancelEdit">取消</button>
        </div>
      </template>
    </div>
    <div v-if="isEditing && editError" class="error-banner" :style="{ marginLeft: depth * 20 + 28 + 'px' }">
      {{ editError }}
    </div>
    <div v-if="hasChildren && isExpanded">
      <CategoryTreeNode
        v-for="child in children"
        :key="child.id"
        :category="child"
        :categories="categories"
        :depth="depth + 1"
        @delete="handleDelete"
        @rename="handleRename"
      />
    </div>
  </div>
</template>
<style scoped>
.node-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding-top: 8px;
  padding-bottom: 8px;
  border-bottom: 1px solid var(--color-border);
}
.expand-btn {
  background: none;
  border: none;
  color: #6b7a74;
  font-size: 12px;
  width: 20px;
  padding: 0;
  cursor: pointer;
}
.expand-spacer {
  display: inline-block;
  width: 20px;
}
.node-name {
  font-size: 14px;
}
.child-count {
  font-size: 12px;
  color: #6b7a74;
}
.node-actions {
  margin-left: auto;
  display: flex;
  gap: 4px;
}
.edit-input {
  flex: 1;
  padding: 4px 8px;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  font-size: 14px;
}
.btn-text {
  background: none;
  border: none;
  color: var(--color-primary);
  font-size: 13px;
  padding: 4px 8px;
}
.btn-text-danger {
  background: none;
  border: none;
  color: var(--color-danger);
  font-size: 13px;
  padding: 4px 8px;
}
</style>
VUEEOF

# ========== CategoryList.vue:加入 handleRename ==========
python3 << 'PYEOF'
path = "ledger-frontend/src/components/CategoryList.vue"
with open(path) as f:
    content = f.read()

old_import = "import { fetchCategories, deleteCategory } from '@/api/ledger'"
new_import = "import { fetchCategories, updateCategory, deleteCategory } from '@/api/ledger'"
if old_import not in content:
    raise SystemExit("❌ import 錨點不符")
content = content.replace(old_import, new_import, 1)

old_fn = """async function handleDelete(id: string) {
  if (!confirm('確定刪除此分類？')) return
  try {
    await deleteCategory(id)
    await load()
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    alert(axiosErr.response?.data?.detail ?? '刪除失敗(可能仍有子分類或交易紀錄使用中)')
  }
}"""
new_fn = """async function handleDelete(id: string) {
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
}"""
if old_fn not in content:
    raise SystemExit("❌ handleDelete 錨點不符")
content = content.replace(old_fn, new_fn, 1)

old_template = """    <CategoryTreeNode
      v-for="root in rootCategories"
      :key="root.id"
      :category="root"
      :categories="categories"
      :depth="0"
      @delete="handleDelete"
    />"""
new_template = """    <CategoryTreeNode
      v-for="root in rootCategories"
      :key="root.id"
      :category="root"
      :categories="categories"
      :depth="0"
      @delete="handleDelete"
      @rename="handleRename"
    />"""
if old_template not in content:
    raise SystemExit("❌ CategoryTreeNode 模板錨點不符")
content = content.replace(old_template, new_template, 1)

with open(path, "w") as f:
    f.write(content)
print("✅ CategoryList.vue 已加入 handleRename")
PYEOF

git add -A
git commit -m "feat: 分類管理頁新增改名功能,同層重複名稱阻擋"
echo "✅ 已 commit"