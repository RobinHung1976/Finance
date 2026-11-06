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
  <section class="panel">
    <div class="panel-head">
      <div class="row filters">
        <select v-model="filterAction" aria-label="動作">
          <option v-for="opt in actionOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
        </select>
        <select v-model="filterResourceType" aria-label="對象">
          <option v-for="opt in resourceOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
        </select>
        <input v-model="filterStartDate" type="date" aria-label="開始日期" />
        <span class="sep">～</span>
        <input v-model="filterEndDate" type="date" aria-label="結束日期" />
      </div>
      <span class="spacer"></span>
      <span v-if="!isLoading" class="pill">共 {{ total }} 筆</span>
    </div>

    <div v-if="loadError" class="panel-body">
      <div class="error-banner">{{ loadError }}</div>
    </div>

    <div v-if="!isLoading && logs.length" class="table-wrap">
      <table class="grid">
        <thead>
          <tr>
            <th>時間</th>
            <th>操作人</th>
            <th>動作</th>
            <th>對象</th>
            <th>說明</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="log in logs" :key="log.id">
            <td class="nowrap">{{ formatTime(log.created_at) }}</td>
            <td>{{ log.actor_name ?? '（已刪除成員）' }}</td>
            <td class="nowrap">{{ actionLabel[log.action] ?? log.action }}</td>
            <td class="nowrap">{{ resourceLabel[log.resource_type] ?? log.resource_type }}</td>
            <td>{{ log.detail ?? '-' }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <p v-else-if="!isLoading" class="empty">查無符合條件的紀錄</p>

    <div v-if="!isLoading && total > 0" class="pager row">
      <button class="btn sm" type="button" :disabled="currentPage === 1" @click="goToPage(currentPage - 1)">上一頁</button>
      <span>{{ currentPage }} / {{ totalPages }}</span>
      <button class="btn sm" type="button" :disabled="currentPage === totalPages" @click="goToPage(currentPage + 1)">
        下一頁
      </button>
    </div>
  </section>
</template>

<style scoped>
.filters select { min-width: 120px; }
.sep { color: var(--muted); font-weight: 700; }
.pager { justify-content: center; padding: 14px; border-top: 1px solid var(--line-soft); font-size: 13px; }
</style>
