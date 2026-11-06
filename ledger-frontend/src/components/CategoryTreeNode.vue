<script setup lang="ts">
import { computed, ref } from 'vue'
import type { CategoryOut } from '@/types/ledger'
import AppIcon from './AppIcon.vue'
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
    <div class="node-row" :class="{ root: depth === 0 }" :style="{ paddingLeft: 16 + depth * 22 + 'px' }">
      <button
        v-if="hasChildren"
        type="button"
        class="expand-btn"
        :aria-expanded="isExpanded"
        :aria-label="isExpanded ? '收合' : '展開'"
        @click="isExpanded = !isExpanded"
      >
        {{ isExpanded ? '▾' : '▸' }}
      </button>
      <span v-else class="expand-spacer"></span>

      <template v-if="!isEditing">
        <span class="node-name">{{ category.name }}</span>
        <span v-if="hasChildren" class="pill child-count">{{ children.length }}</span>
        <div class="node-actions">
          <button type="button" class="btn sm" @click="startEdit"><AppIcon name="edit" />改名</button>
          <button type="button" class="btn danger sm" @click="handleDelete(category.id)"><AppIcon name="trash" />刪除</button>
        </div>
      </template>
      <template v-else>
        <input v-model="editName" type="text" maxlength="100" class="edit-input" aria-label="新名稱" @keyup.enter="saveEdit" />
        <div class="node-actions">
          <button type="button" class="btn primary sm" @click="saveEdit">儲存</button>
          <button type="button" class="btn sm" @click="cancelEdit">取消</button>
        </div>
      </template>
    </div>
    <div v-if="isEditing && editError" class="node-error" :style="{ paddingLeft: 16 + depth * 22 + 28 + 'px' }">
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
  min-height: 46px;
  padding-right: 16px;
  border-bottom: 1px solid var(--line-soft);
}
.node-row:hover { background: rgb(255 255 255 / 45%); }
.node-row.root .node-name { font-weight: 700; }
.expand-btn {
  width: 22px;
  height: 22px;
  padding: 0;
  font-size: 12px;
  line-height: 1;
  color: var(--text-2);
  border: 1px solid #a9b0b8;
  border-radius: 4px;
  background: var(--metal-key);
  box-shadow: inset 0 1px 0 #fff;
}
.expand-btn:hover { background: var(--metal-key-hover); }
.expand-spacer { display: inline-block; width: 22px; }
.node-name { font-size: 14px; }
.child-count { font-size: 11px; padding: 0 7px; }
.node-actions { margin-left: auto; display: flex; gap: 6px; }
.edit-input { flex: 1; max-width: 320px; }
.node-error { padding: 4px 0 8px; color: var(--bad); font-size: 12px; }
</style>
