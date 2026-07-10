<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import type { TagOut } from '@/types/ledger'

const props = defineProps<{
  tags: TagOut[]
  modelValue: string[]
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string[]] }>()

const rootEl = ref<HTMLElement | null>(null)
const isOpen = ref(false)
const searchQuery = ref('')

const selectedLabel = computed(() => {
  if (props.modelValue.length === 0) return '所有品項'
  const names = props.modelValue
    .map((id) => props.tags.find((t) => t.id === id)?.name)
    .filter((n): n is string => !!n)
  if (names.length === 0) return '所有品項'
  if (names.length <= 2) return names.join('、')
  return `已選 ${names.length} 項`
})

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
function toggleOpen() {
  isOpen.value = !isOpen.value
  if (isOpen.value) searchQuery.value = ''
}
function clearSelection() {
  emit('update:modelValue', [])
}

function handleOutsideClick(e: MouseEvent) {
  if (rootEl.value && !rootEl.value.contains(e.target as Node)) {
    isOpen.value = false
  }
}
onMounted(() => document.addEventListener('click', handleOutsideClick))
onBeforeUnmount(() => document.removeEventListener('click', handleOutsideClick))
</script>

<template>
  <div ref="rootEl" class="tag-filter-picker">
    <button type="button" class="filter-input picker-trigger" @click="toggleOpen">
      {{ selectedLabel }}
    </button>
    <div v-if="isOpen" class="dropdown-panel">
      <input v-model="searchQuery" type="text" class="search-input" placeholder="搜尋消費品項…" autofocus />
      <div class="result-list">
        <button type="button" class="result-item" :class="{ selected: modelValue.length === 0 }" @click="clearSelection">
          所有品項
        </button>
        <button
          v-for="t in filteredTags"
          :key="t.id"
          type="button"
          class="result-item"
          :class="{ selected: isSelected(t.id) }"
          @click="toggleTag(t.id)"
        >
          <span>{{ t.name }}</span>
          <span v-if="isSelected(t.id)" class="check-mark">✓</span>
        </button>
        <p v-if="filteredTags.length === 0" class="no-result">沒有符合的消費品項</p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.tag-filter-picker {
  position: relative;
}
.picker-trigger {
  cursor: pointer;
  text-align: left;
  min-width: 140px;
  max-width: 220px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.dropdown-panel {
  position: absolute;
  top: calc(100% + 4px);
  left: 0;
  z-index: 20;
  width: 260px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  padding: 8px;
}
.search-input {
  width: 100%;
  padding: 6px 10px;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  font-size: 13px;
  margin-bottom: 6px;
  box-sizing: border-box;
}
.result-list {
  max-height: 280px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.result-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  text-align: left;
  background: none;
  border: none;
  padding: 6px 8px;
  font-size: 13px;
  cursor: pointer;
  border-radius: 6px;
}
.result-item:hover {
  background: var(--color-bg);
}
.result-item.selected {
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
  padding: 6px 8px;
  margin: 0;
}
</style>
