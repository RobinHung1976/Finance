<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { fetchMyHousehold } from '@/api/auth'
import type { HouseholdOut } from '@/types/api'
import AppIcon, { type IconName } from '@/components/AppIcon.vue'
import BrandBlock from '@/components/BrandBlock.vue'

const TIMEZONE = 'Asia/Taipei'

interface NavItem {
  to: string
  label: string
  icon: IconName
  adminOnly?: boolean
}

const NAV_GROUPS: { title: string; items: NavItem[] }[] = [
  {
    title: '報表',
    items: [
      { to: '/stats', label: '統計', icon: 'chart' },
      { to: '/transactions', label: '交易紀錄', icon: 'receipt' },
    ],
  },
  {
    title: '帳務設定',
    items: [
      { to: '/accounts', label: '帳戶', icon: 'wallet' },
      { to: '/categories', label: '分類', icon: 'folder' },
      { to: '/tags', label: '消費品項', icon: 'tag' },
      { to: '/transfer', label: '匯入/匯出', icon: 'transfer' },
    ],
  },
  {
    title: '帳本管理',
    items: [
      { to: '/members', label: '成員管理', icon: 'users' },
      { to: '/audit-logs', label: '操作紀錄', icon: 'history', adminOnly: true },
    ],
  },
]

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const household = ref<HouseholdOut | null>(null)

const visibleGroups = computed(() =>
  NAV_GROUPS.map((g) => ({ ...g, items: g.items.filter((i) => !i.adminOnly || auth.role === 'admin') })).filter(
    (g) => g.items.length > 0,
  ),
)
const pageTitle = computed(() => (route.meta.title as string | undefined) ?? '家庭理財')
const roleLabel = computed(() => (auth.role === 'admin' ? '管理者' : '使用者'))

// 側欄時鐘：固定顯示台北時間
const clockFormatter = new Intl.DateTimeFormat('sv-SE', {
  timeZone: TIMEZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  hour12: false,
})
const now = ref(clockFormatter.format(new Date()))
let clockTimer: number | undefined

onMounted(async () => {
  clockTimer = window.setInterval(() => {
    now.value = clockFormatter.format(new Date())
  }, 15_000)
  try {
    household.value = await fetchMyHousehold()
  } catch {
    // 失敗不阻斷畫面，側欄 fallback 顯示預設文字
  }
})

onBeforeUnmount(() => window.clearInterval(clockTimer))

function handleLogout() {
  auth.logout()
  router.push({ name: 'login' })
}
</script>

<template>
  <div class="layout">
    <aside class="sidebar">
      <BrandBlock />

      <div class="household-nav">
        <div class="nav-title">目前帳本</div>
        <div class="household-current" :title="household?.name">
          <AppIcon name="book" /><span>{{ household?.name ?? '載入中…' }}</span>
        </div>
      </div>

      <nav class="nav" aria-label="主選單">
        <div v-for="group in visibleGroups" :key="group.title" class="nav-group">
          <div class="nav-title">{{ group.title }}</div>
          <router-link v-for="item in group.items" :key="item.to" :to="item.to" active-class="active">
            <AppIcon :name="item.icon" />{{ item.label }}
          </router-link>
        </div>
      </nav>

      <div class="side-foot">
        <span class="clock" title="目前時間">
          <AppIcon name="clock" /><span class="tz">{{ TIMEZONE }}</span><time>{{ now }}</time>
        </span>
      </div>
    </aside>

    <div class="main">
      <header class="topbar">
        <h1>{{ pageTitle }}</h1>
        <span class="who">登入身分：<b>{{ roleLabel }}</b></span>
        <button class="btn sm" type="button" @click="handleLogout"><AppIcon name="logout" />登出</button>
      </header>
      <main class="content">
        <router-view />
      </main>
    </div>
  </div>
</template>
