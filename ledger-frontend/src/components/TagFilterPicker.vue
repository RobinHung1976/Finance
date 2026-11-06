<script setup lang="ts">
import { ref, computed } from 'vue'
import type { TagOut } from '@/types/ledger'

const RECENT_LIMIT = 8

const props = defineProps<{
  modelValue: string[]
  tags: TagOut[]
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string[]] }>()

const searchQuery = ref('')
const isSearching = computed(() => searchQuery.value.trim().length > 0)

const filteredTags = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return props.tags
  return props.tags.filter((t) => t.name.toLowerCase().includes(q))
})

const recentTags = computed(() => {
  return props.tags
    .filter((t) => t.last_used_date)
    .sort((a, b) => (b.last_used_date! < a.last_used_date! ? -1 : 1))
    .slice(0, RECENT_LIMIT)
})

const otherTags = computed(() => {
  const recentIds = new Set(recentTags.value.map((t) => t.id))
  return props.tags.filter((t) => !recentIds.has(t.id))
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
  <div class="filter-picker-box tags">
    <input v-model="searchQuery" type="search" class="search-input" placeholder="搜尋消費品項…" />

    <div class="option-grid">
      <button type="button" class="option-btn" :class="{ selected: modelValue.length === 0 }" @click="clearSelection">
        所有品項
      </button>
    </div>

    <template v-if="!isSearching">
      <div v-if="recentTags.length" class="tag-section-label">最近使用</div>
      <div v-if="recentTags.length" class="option-grid">
        <button
          v-for="t in recentTags"
          :key="t.id"
          type="button"
          class="option-btn"
          :class="{ selected: isSelected(t.id) }"
          @click="toggleTag(t.id)"
        >
          {{ t.name }}
        </button>
      </div>

      <div v-if="recentTags.length && otherTags.length" class="tag-section-label">全部品項</div>
      <div class="option-grid">
        <button
          v-for="t in otherTags"
          :key="t.id"
          type="button"
          class="option-btn"
          :class="{ selected: isSelected(t.id) }"
          @click="toggleTag(t.id)"
        >
          {{ t.name }}
        </button>
      </div>
    </template>

    <template v-else>
      <div class="option-grid">
        <button
          v-for="t in filteredTags"
          :key="t.id"
          type="button"
          class="option-btn"
          :class="{ selected: isSelected(t.id) }"
          @click="toggleTag(t.id)"
        >
          {{ t.name }}
        </button>
        <p v-if="filteredTags.length === 0" class="no-result">沒有符合的消費品項</p>
      </div>
    </template>
  </div>
</template>
