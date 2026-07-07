<script setup lang="ts">
const startDate = defineModel<string>('startDate', { required: true })
const endDate = defineModel<string>('endDate', { required: true })

function thisYear() {
  const today = new Date()
  startDate.value = `${today.getFullYear()}-01-01`
  endDate.value = today.toISOString().slice(0, 10)
}
</script>

<template>
  <div class="date-range">
    <input type="date" v-model="startDate" :max="endDate" />
    <span class="sep">~</span>
    <input type="date" v-model="endDate" :min="startDate" />
    <button class="reset-btn" @click="thisYear">今年</button>
  </div>
</template>

<style scoped>
.date-range { display: flex; align-items: center; gap: 6px; font-size: 0.85rem; }
.date-range input[type='date'] {
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  padding: 4px 8px;
  font-size: 0.85rem;
}
.sep { color: #9ca3af; }
.reset-btn {
  background: #f3f4f6;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  padding: 4px 10px;
  font-size: 0.8rem;
  color: #4b5563;
  cursor: pointer;
}
.reset-btn:hover { background: #e5e7eb; }
</style>
