<script setup lang="ts">
import { onMounted, ref, computed, watch } from 'vue'
import { fetchAuditLogs } from '@/api/auth'
import type { AuditLogOut } from '@/types/api'

const logs = ref<AuditLogOut[]>([])
const total = ref(0)
const limit = 20
const offset = ref(0)
const isLoading = ref(true)
const loadError = ref('')

const filterAction = ref('')
const filterResourceType = ref('')
const filterStartDate = ref('')
const filterEndDate = ref('')

const actionOptions = [
  { value: '', label: '全部動作' },
  { value: 'login', label: '登入' },
  { value: 'create', label: '新增' },
  { value: 'update', label: '修改' },
  { value: 'delete', label: '刪除' },
]
const resourceOptions = [
  { value: '', label: '全部對象' },
  { value: 'account', label: '帳戶' },
  { value: 'category', label: '分類' },
  { value: 'transaction', label: '交易' },
  { value: 'member', label: '成員' },
  { value: 'user', label: '使用者' },
]
const actionLabel: Record<string, string> = { login: '登入', create: '新增', update: '修改', delete: '刪除' }
const resourceLabel: Record<string, string> = {
  account: '帳戶', category: '分類', transaction: '交易', member: '成員', user: '使用者',
}

const currentPage = computed(() => Math.floor(offset.value / limit) + 1)
const totalPages = computed(() => Math.max(1, Math.ceil(total.value / limit)))

function formatTime(iso: string) {
  return new Date(iso).toLocaleString('zh-TW', { hour12: false })
}

async function loadLogs() {
  isLoading.value = true
  try {
    const page = await fetchAuditLogs(limit, offset.value, {
      action: filterAction.value || undefined,
      resource_type: filterResourceType.value || undefined,
      start_date: filterStartDate.value || undefined,
      end_date: filterEndDate.value || undefined,
    })
    logs.value = page.items
    total.value = page.total
  } catch {
    loadError.value = '載入操作紀錄失敗'
  } finally {
    isLoading.value = false
  }
}

function goToPage(page: number) {
  if (page < 1 || page > totalPages.value) return
  offset.value = (page - 1) * limit
  loadLogs()
}

watch([filterAction, filterResourceType, filterStartDate, filterEndDate], () => {
  offset.value = 0
  loadLogs()
})

onMounted(loadLogs)
</script>

<template>
  <div style="max-width: 800px; margin: 0 auto; padding: 32px 24px">
    <header style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px">
      <h1 style="font-size: 20px; margin: 0">操作紀錄</h1>
      <router-link to="/" style="font-size: 13px; color: var(--color-primary); text-decoration: none">
        返回理財首頁
      </router-link>
    </header>

    <div style="display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 16px; font-size: 13px">
      <select v-model="filterAction" style="padding: 6px 8px">
        <option v-for="opt in actionOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
      </select>
      <select v-model="filterResourceType" style="padding: 6px 8px">
        <option v-for="opt in resourceOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
      </select>
      <input v-model="filterStartDate" type="date" style="padding: 6px 8px" />
      <span style="align-self: center">～</span>
      <input v-model="filterEndDate" type="date" style="padding: 6px 8px" />
    </div>

    <div v-if="loadError" class="error-banner">{{ loadError }}</div>

    <table v-if="!isLoading && logs.length" style="width: 100%; border-collapse: collapse; font-size: 13px">
      <thead>
        <tr style="text-align: left; color: #6b7a74; border-bottom: 1px solid var(--color-border)">
          <th style="padding: 8px">時間</th>
          <th style="padding: 8px">操作人</th>
          <th style="padding: 8px">動作</th>
          <th style="padding: 8px">對象</th>
          <th style="padding: 8px">說明</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="log in logs" :key="log.id" style="border-bottom: 1px solid var(--color-border)">
          <td style="padding: 8px; white-space: nowrap">{{ formatTime(log.created_at) }}</td>
          <td style="padding: 8px">{{ log.actor_name ?? '（已刪除成員）' }}</td>
          <td style="padding: 8px">{{ actionLabel[log.action] ?? log.action }}</td>
          <td style="padding: 8px">{{ resourceLabel[log.resource_type] ?? log.resource_type }}</td>
          <td style="padding: 8px">{{ log.detail ?? '-' }}</td>
        </tr>
      </tbody>
    </table>

    <p v-else-if="!isLoading" style="color: #6b7a74; font-size: 13px">查無符合條件的紀錄</p>

    <div v-if="!isLoading && total > 0" style="display: flex; justify-content: center; align-items: center; gap: 12px; margin-top: 16px; font-size: 13px">
      <button :disabled="currentPage === 1" @click="goToPage(currentPage - 1)" style="padding: 4px 10px; cursor: pointer">上一頁</button>
      <span>{{ currentPage }} / {{ totalPages }}（共 {{ total }} 筆）</span>
      <button :disabled="currentPage === totalPages" @click="goToPage(currentPage + 1)" style="padding: 4px 10px; cursor: pointer">下一頁</button>
    </div>
  </div>
</template>
