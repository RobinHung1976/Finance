<script setup lang="ts">
import { presetRange, type RangePreset } from '@/utils/date'

const startDate = defineModel<string>('startDate', { required: true })
const endDate = defineModel<string>('endDate', { required: true })

const PRESETS: { key: RangePreset; label: string }[] = [
  { key: 'thisMonth', label: '本月' },
  { key: 'lastMonth', label: '上月' },
  { key: 'last3Months', label: '近 3 個月' },
  { key: 'thisYear', label: '今年' },
]

function apply(key: RangePreset) {
  const r = presetRange(key)
  startDate.value = r.start
  endDate.value = r.end
}

function isActive(key: RangePreset): boolean {
  const r = presetRange(key)
  return r.start === startDate.value && r.end === endDate.value
}
</script>

<template>
  <div class="date-range">
    <input type="date" v-model="startDate" :max="endDate" aria-label="開始日期" />
    <span class="sep">~</span>
    <input type="date" v-model="endDate" :min="startDate" aria-label="結束日期" />
    <span class="presets">
      <button
        v-for="p in PRESETS"
        :key="p.key"
        type="button"
        class="btn sm"
        :class="{ on: isActive(p.key) }"
        :aria-pressed="isActive(p.key)"
        @click="apply(p.key)"
      >
        {{ p.label }}
      </button>
    </span>
  </div>
</template>

<style scoped>
.date-range { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.sep { color: var(--muted); font-weight: 700; }
.presets { display: inline-flex; gap: 6px; margin-left: 6px; }
</style>
