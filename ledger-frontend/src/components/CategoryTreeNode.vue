<script setup lang="ts">
import { computed, ref } from 'vue'
import type { CategoryOut } from '@/types/ledger'

defineOptions({ name: 'CategoryTreeNode' }) // 遞迴自我參照元件需要明確命名

const props = defineProps<{
  category: CategoryOut
  categories: CategoryOut[]
  depth: number
}>()

const emit = defineEmits<{ delete: [id: string] }>()

const isExpanded = ref(false)

const children = computed(() => props.categories.filter((c) => c.parent_id === props.category.id))
const hasChildren = computed(() => children.value.length > 0)

function handleDelete(id: string) {
  emit('delete', id)
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

      <strong class="node-name">{{ category.name }}</strong>
      <span v-if="hasChildren" class="child-count">({{ children.length }})</span>

      <button class="btn-text-danger node-delete" @click="handleDelete(category.id)">刪除</button>
    </div>

    <div v-if="hasChildren && isExpanded">
      <CategoryTreeNode
        v-for="child in children"
        :key="child.id"
        :category="child"
        :categories="categories"
        :depth="depth + 1"
        @delete="handleDelete"
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

.node-delete {
  margin-left: auto;
}

.btn-text-danger {
  background: none;
  border: none;
  color: var(--color-danger);
  font-size: 13px;
  padding: 4px 8px;
}
</style>
