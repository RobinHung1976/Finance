<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import AccountList from '@/components/AccountList.vue'
import CategoryList from '@/components/CategoryList.vue'
import TransactionList from '@/components/TransactionList.vue'
import MonthlyTrendChart from '@/components/MonthlyTrendChart.vue'
import CategoryBreakdownChart from '@/components/CategoryBreakdownChart.vue'
import DateRangePicker from '@/components/DateRangePicker.vue'

const router = useRouter()
const auth = useAuthStore()

type Tab = 'stats' | 'transactions' | 'accounts' | 'categories'
const activeTab = ref<Tab>('stats')

// 統計頁日期區間,預設今年 1/1 ~ 今天,兩張圖表共用同一組區間
const today = new Date()
const startDate = ref(`${today.getFullYear()}-01-01`)
const endDate = ref(today.toISOString().slice(0, 10))

const refreshKey = ref(0)
function handleReferenceDataChanged() {
  refreshKey.value += 1
}

function handleLogout() {
  auth.logout()
  router.push({ name: 'login' })
}
</script>

<template>
  <div style="max-width: 1000px; margin: 0 auto; padding: 32px 24px">
    <header style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px">
      <h1 style="font-size: 20px; margin: 0">家庭理財</h1>
      <div style="display: flex; gap: 12px; align-items: center">
        <router-link to="/members" style="font-size: 13px; color: var(--color-primary); text-decoration: none">
          成員管理
        </router-link>
        <button class="btn-primary" style="width: auto; padding: 6px 14px; font-size: 13px" @click="handleLogout">
          登出
        </button>
      </div>
    </header>

    <nav class="tab-bar">
      <button :class="{ active: activeTab === 'stats' }" @click="activeTab = 'stats'">統計</button>
      <button :class="{ active: activeTab === 'transactions' }" @click="activeTab = 'transactions'">
        交易紀錄
      </button>
      <button :class="{ active: activeTab === 'accounts' }" @click="activeTab = 'accounts'">帳戶</button>
      <button :class="{ active: activeTab === 'categories' }" @click="activeTab = 'categories'">分類</button>
    </nav>

    <section style="margin-top: 20px">
      <div v-if="activeTab === 'stats'">
        <div class="stats-toolbar">
          <DateRangePicker v-model:start-date="startDate" v-model:end-date="endDate" />
        </div>
        <div class="stats-grid">
          <div class="stats-panel">
            <h3>月收支趨勢</h3>
            <MonthlyTrendChart :start-date="startDate" :end-date="endDate" />
          </div>
          <div class="stats-panel">
            <h3>支出分類統計</h3>
            <CategoryBreakdownChart type="expense" :start-date="startDate" :end-date="endDate" />
          </div>
        </div>
      </div>
      <TransactionList v-else-if="activeTab === 'transactions'" :refresh-key="refreshKey" />
      <AccountList v-else-if="activeTab === 'accounts'" @changed="handleReferenceDataChanged" />
      <CategoryList v-else-if="activeTab === 'categories'" @changed="handleReferenceDataChanged" />
    </section>
  </div>
</template>

<style scoped>
.tab-bar { display: flex; gap: 4px; border-bottom: 1px solid var(--color-border); }
.tab-bar button {
  background: none; border: none; padding: 10px 16px; font-size: 14px;
  color: #6b7a74; border-bottom: 2px solid transparent; margin-bottom: -1px; cursor: pointer;
}
.tab-bar button.active { color: var(--color-primary); border-bottom-color: var(--color-primary); font-weight: 600; }

.stats-toolbar { display: flex; justify-content: flex-end; margin-bottom: 12px; }

/* 3fr:2fr — 折線圖需要橫向空間畫時間軸,圓餅圖不需要太寬 */
.stats-grid { display: grid; grid-template-columns: 3fr 2fr; gap: 1.5rem; align-items: stretch; }
/* 若想改上下堆疊,改成: grid-template-columns: 1fr; */

.stats-panel { background: #fff; border-radius: 8px; padding: 1rem; box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1); display: flex; flex-direction: column; }
.stats-panel h3 { margin: 0 0 12px; font-size: 15px; }
@media (max-width: 900px) { .stats-grid { grid-template-columns: 1fr; } }
</style>
