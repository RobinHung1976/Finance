import { defineStore } from 'pinia'
import { ref } from 'vue'
import { presetRange } from '@/utils/date'

export type StatsSubTab = 'trend' | 'breakdown' | 'tagBreakdown' | 'topTransactions'

// 統計頁的篩選狀態：放在 store，切到其他頁再回來時保留（原本單頁分頁時的行為）
export const useStatsFilterStore = defineStore('statsFilter', () => {
  const initial = presetRange('thisYear')
  const startDate = ref(initial.start)
  const endDate = ref(initial.end)
  const subTab = ref<StatsSubTab>('trend')
  return { startDate, endDate, subTab }
})
