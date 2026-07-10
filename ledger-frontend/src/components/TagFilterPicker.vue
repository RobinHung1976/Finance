<script setup lang="ts">
import { computed, ref } from 'vue'
import type { TagOut } from '@/types/ledger'

const props = defineProps<{
  tags: TagOut[]
  modelValue: string[]
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string[]] }>()

const searchQuery = ref('')

const filteredTags = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  const list = q ? props.tags.filter((t) => t.name.toLowerCase().includes(q)) : props.tags
  return [...list].sort((a, b) => a.name.localeCompare(b.name)).slice(0, 50)
})

function isSelected(id: string) {
  return props.modelValue.includes(id)
}
function toggleTag(id: string) {
  const next = isSelected(id) ? props.modelValue.filter((v) => v !== id) : [...props.modelValue, id]
  emit('update:modelValue', next)
}
function clearSelection() {
  emit('update:modelValue', [])
}
</script>

<template>
  <div class="filter-picker-box">
    <input v-model="searchQuery" type="text" class="search-input" placeholder="搜尋消費品項…" />
    <div class="option-grid">
      <button type="button" class="option-btn" :class="{ selected: modelValue.length === 0 }" @click="clearSelection">
        所有品項
      </button>
      <button
        v-for="t in filteredTags"
        :key="t.id"
        type="button"
        class="option-btn"
        :class="{ selected: isSelected(t.id) }"
        @click="toggleTag(t.id)"
      >
        <span>{{ t.name }}</span>
        <span v-if="isSelected(t.id)" class="check-mark">✓</span>
      </button>
      <p v-if="filteredTags.length === 0" class="no-result">沒有符合的消費品項</p>
    </div>
  </div>
</template>

<style scoped>
.filter-picker-box {
  border: 1px solid var(--color-border);
  border-radius: 8px;
  padding: 10px;
  background: var(--color-bg);
}
.search-input {
  width: 100%;
  padding: 6px 10px;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  font-size: 13px;
  margin-bottom: 8px;
  box-sizing: border-box;
}
.option-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  max-height: 240px;
  overflow-y: auto;
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
.check-mark {
  color: var(--color-primary);
  font-weight: 700;
}
.no-result {
  font-size: 12px;
  color: #6b7a74;
  margin: 0;
}
</style>
