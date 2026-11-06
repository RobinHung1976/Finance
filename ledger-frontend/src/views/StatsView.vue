<script setup lang="ts">
import { storeToRefs } from 'pinia'
import AppIcon, { type IconName } from '@/components/AppIcon.vue'
import DateRangePicker from '@/components/DateRangePicker.vue'
import MonthlyTrendChart from '@/components/MonthlyTrendChart.vue'
import CategoryBreakdownChart from '@/components/CategoryBreakdownChart.vue'
import TagBreakdownChart from '@/components/TagBreakdownChart.vue'
import TopTransactionsList from '@/components/TopTransactionsList.vue'
import { useStatsFilterStore, type StatsSubTab } from '@/stores/statsFilter'

const SUB_TABS: { key: StatsSubTab; label: string; icon: IconName }[] = [
  { key: 'trend', label: '月收支趨勢', icon: 'trend' },
  { key: 'breakdown', label: '支出分類統計', icon: 'pie' },
  { key: 'tagBreakdown', label: '消費品項排行', icon: 'tag' },
  { key: 'topTransactions', label: '最大單筆排行', icon: 'ranking' },
]

// 四張圖表共用同一組日期區間
const { startDate, endDate, subTab } = storeToRefs(useStatsFilterStore())
</script>

<template>
  <section class="panel">
    <div class="panel-head">
      <div class="keypad" role="tablist" aria-label="統計項目">
        <button
          v-for="t in SUB_TABS"
          :key="t.key"
          type="button"
          role="tab"
          class="key"
          :class="{ active: subTab === t.key }"
          :aria-selected="subTab === t.key"
          @click="subTab = t.key"
        >
          <AppIcon :name="t.icon" />{{ t.label }}
        </button>
      </div>
      <span class="spacer"></span>
      <DateRangePicker v-model:start-date="startDate" v-model:end-date="endDate" />
    </div>
    <div class="panel-body" role="tabpanel">
      <MonthlyTrendChart v-if="subTab === 'trend'" :start-date="startDate" :end-date="endDate" />
      <CategoryBreakdownChart
        v-else-if="subTab === 'breakdown'"
        type="expense"
        :start-date="startDate"
        :end-date="endDate"
      />
      <TagBreakdownChart v-else-if="subTab === 'tagBreakdown'" :start-date="startDate" :end-date="endDate" />
      <TopTransactionsList v-else :start-date="startDate" :end-date="endDate" />
    </div>
  </section>
</template>

<style scoped>
.panel-head { padding-top: 14px; padding-bottom: 12px; }
.keypad { padding: 0; }
</style>
