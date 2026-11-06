import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/login',
      name: 'login',
      component: () => import('@/views/LoginView.vue'),
      meta: { public: true },
    },
    {
      path: '/register',
      name: 'register',
      component: () => import('@/views/RegisterHouseholdView.vue'),
      meta: { public: true },
    },
    // PAUSED: 忘記密碼功能已就緒,待 SMTP 基礎建設驗證後開放
    {
      path: '/forgot-password',
      name: 'forgot-password',
      component: () => import('@/views/ForgotPasswordView.vue'),
      meta: { public: true },
    },
    {
      path: '/reset-password',
      name: 'reset-password',
      component: () => import('@/views/ResetPasswordView.vue'),
      meta: { public: true },
    },
    {
      // 登入後的頁面共用 AppLayout(側欄 + 頂部列),原 Dashboard 的分頁改為子路由
      path: '/',
      component: () => import('@/layouts/AppLayout.vue'),
      children: [
        // 保留 name 'dashboard':LoginView、路由守衛都以此導向首頁
        { path: '', name: 'dashboard', redirect: { name: 'stats' } },
        { path: 'stats', name: 'stats', component: () => import('@/views/StatsView.vue'), meta: { title: '統計' } },
        {
          path: 'transactions',
          name: 'transactions',
          component: () => import('@/views/TransactionsView.vue'),
          meta: { title: '交易紀錄' },
        },
        { path: 'accounts', name: 'accounts', component: () => import('@/views/AccountsView.vue'), meta: { title: '帳戶' } },
        {
          path: 'categories',
          name: 'categories',
          component: () => import('@/views/CategoriesView.vue'),
          meta: { title: '分類' },
        },
        { path: 'tags', name: 'tags', component: () => import('@/views/TagsView.vue'), meta: { title: '消費品項' } },
        {
          path: 'transfer',
          name: 'transfer',
          component: () => import('@/views/TransferView.vue'),
          meta: { title: '匯入/匯出' },
        },
        { path: 'members', name: 'members', component: () => import('@/views/MembersView.vue'), meta: { title: '成員管理' } },
        {
          path: 'audit-logs',
          name: 'audit-logs',
          component: () => import('@/views/AuditLogView.vue'),
          meta: { title: '操作紀錄', requiresAdmin: true },
        },
      ],
    },
    // 未知路徑導回首頁(避免舊書籤或打錯網址出現空白頁)
    { path: '/:pathMatch(.*)*', redirect: { name: 'dashboard' } },
  ],
})

router.beforeEach((to) => {
  const auth = useAuthStore()
  if (!to.meta.public && !auth.isAuthenticated()) {
    return { name: 'login' }
  }
  if (to.meta.public && auth.isAuthenticated()) {
    return { name: 'dashboard' }
  }
  if (to.meta.requiresAdmin && auth.role !== 'admin') {
    return { name: 'dashboard' }
  }
  return true
})

export default router
