<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import AccountList from '@/components/AccountList.vue'
import CategoryList from '@/components/CategoryList.vue'
import TransactionList from '@/components/TransactionList.vue'
import MonthlyTrendChart from '@/components/MonthlyTrendChart.vue'

const router = useRouter()
const auth = useAuthStore()

type Tab = 'stats' | 'transactions' | 'accounts' | 'categories'
const activeTab = ref<Tab>('stats')

// 帳戶/分類異動時遞增,通知 TransactionList 重新載入下拉選單資料
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
  <div style="max-width: 800px; margin: 0 auto; padding: 32px 24px">
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
      <MonthlyTrendChart v-if="activeTab === 'stats'" />
      <TransactionList v-else-if="activeTab === 'transactions'" :refresh-key="refreshKey" />
      <AccountList v-else-if="activeTab === 'accounts'" @changed="handleReferenceDataChanged" />
      <CategoryList v-else-if="activeTab === 'categories'" @changed="handleReferenceDataChanged" />
    </section>
  </div>
</template>

<style scoped>
.tab-bar {
  display: flex;
  gap: 4px;
  border-bottom: 1px solid var(--color-border);
}

.tab-bar button {
  background: none;
  border: none;
  padding: 10px 16px;
  font-size: 14px;
  color: #6b7a74;
  border-bottom: 2px solid transparent;
  margin-bottom: -1px;
  cursor: pointer;
}

.tab-bar button.active {
  color: var(--color-primary);
  border-bottom-color: var(--color-primary);
  font-weight: 600;
}
</style>
