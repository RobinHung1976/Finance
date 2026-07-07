<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import CategoryPicker from './CategoryPicker.vue'
import { fetchAccounts, fetchCategories, fetchTransactions, createTransaction, updateTransaction, deleteTransaction } from '@/api/ledger'
import { formatCurrency } from '@/utils/ledgerLabels'
import type { AccountOut, CategoryOut, EntryType, TransactionOut } from '@/types/ledger'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

function todayLocalISODate(): string {
  const d = new Date()
  const year = d.getFullYear()
  const month = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

function firstDayOfMonthISODate(): string {
  const d = new Date()
  const year = d.getFullYear()
  const month = String(d.getMonth() + 1).padStart(2, '0')
  return `${year}-${month}-01`
}

const props = defineProps<{ refreshKey: number }>()

const accounts = ref<AccountOut[]>([])
const categories = ref<CategoryOut[]>([])
const transactions = ref<TransactionOut[]>([])
const isLoading = ref(true)
const loadError = ref('')

// 篩選條件
const filterStartDate = ref(firstDayOfMonthISODate())
const filterEndDate = ref(todayLocalISODate())
const filterAccountId = ref('')
const filterCategoryId = ref('')

// 新增表單
const showForm = ref(false)
const formType = ref<EntryType>('expense')
const formAccountId = ref('')
const formCategoryId = ref('')
const formAmount = ref<number | null>(null)
const formDate = ref(todayLocalISODate())
const formNote = ref('')
const formError = ref('')
const isSubmitting = ref(false)

// 編輯既有交易(null = 非編輯模式)
const editingId = ref<string | null>(null)
const editAccountId = ref('')
const editCategoryId = ref('')
const editAmount = ref<number | null>(null)
const editType = ref<EntryType>('expense')
const editDate = ref('')
const editNote = ref('')
const editError = ref('')
const isSavingEdit = ref(false)


function accountName(id: string): string {
  return accounts.value.find((a) => a.id === id)?.name ?? '（已刪除帳戶）'
}
function categoryName(id: string): string {
  const names: string[] = []
  let current = categories.value.find((c) => c.id === id)
  while (current) {
    names.unshift(current.name)
    const parentId: string | null = current.parent_id
    current = parentId ? categories.value.find((c) => c.id === parentId) : undefined
  }
  return names.length > 0 ? names.join(' - ') : '（已刪除分類）'
}


async function loadReferenceData() {
  const [accountsData, categoriesData] = await Promise.all([fetchAccounts(), fetchCategories()])
  accounts.value = accountsData
  categories.value = categoriesData
}

async function loadTransactions() {
  isLoading.value = true
  loadError.value = ''
  try {
    transactions.value = await fetchTransactions({
      start_date: filterStartDate.value || undefined,
      end_date: filterEndDate.value || undefined,
      account_id: filterAccountId.value || undefined,
      category_id: filterCategoryId.value || undefined,
    })
  } catch {
    loadError.value = '載入交易紀錄失敗'
  } finally {
    isLoading.value = false
  }
}

onMounted(async () => {
  await loadReferenceData()
  await loadTransactions()
})

// 帳戶/分類在其他頁籤變動時(refreshKey 改變)重新載入參照資料
watch(
  () => props.refreshKey,
  async () => {
    await loadReferenceData()
  }
)

watch([filterStartDate, filterEndDate, filterAccountId, filterCategoryId], loadTransactions)

const totalExpense = computed(() =>
  transactions.value.filter((t) => t.type === 'expense').reduce((sum, t) => sum + t.amount, 0)
)
const totalIncome = computed(() =>
  transactions.value.filter((t) => t.type === 'income').reduce((sum, t) => sum + t.amount, 0)
)
const totalBalance = computed(() => accounts.value.reduce((sum, a) => sum + a.balance, 0))

// 依日期分組(後端已依日期新到舊排序,這裡只是分段插入標題)
const groupedTransactions = computed(() => {
  const groups: { date: string; items: TransactionOut[] }[] = []
  for (const tx of transactions.value) {
    const lastGroup = groups[groups.length - 1]
    if (lastGroup && lastGroup.date === tx.date) {
      lastGroup.items.push(tx)
    } else {
      groups.push({ date: tx.date, items: [tx] })
    }
  }
  return groups
})

function formatDateHeader(isoDate: string): string {
  const today = todayLocalISODate()
  const yesterday = new Date()
  yesterday.setDate(yesterday.getDate() - 1)
  const yesterdayStr = `${yesterday.getFullYear()}-${String(yesterday.getMonth() + 1).padStart(2, '0')}-${String(yesterday.getDate()).padStart(2, '0')}`

  if (isoDate === today) return '今天'
  if (isoDate === yesterdayStr) return '昨天'

  const [, month, day] = isoDate.split('-')
  return `${Number(month)}月${Number(day)}日`
}

function openAddForm() {
  formDate.value = todayLocalISODate() // 每次開啟都重設為今天,避免舊值殘留
  if (formType.value === 'expense' && !formAccountId.value) {
    const defaultAccount = accounts.value.find((a) => a.is_default_expense)
    if (defaultAccount) formAccountId.value = defaultAccount.id
  }
  showForm.value = !showForm.value
}

function handleCategoryCreated(category: CategoryOut) {
  categories.value.push(category)
}

async function handleCreate() {
  formError.value = ''

  if (!formAccountId.value) {
    formError.value = '請選擇帳戶'
    return
  }
  if (!formCategoryId.value) {
    formError.value = '請選擇分類'
    return
  }
  if (!formAmount.value || formAmount.value <= 0) {
    formError.value = '金額必須大於 0'
    return
  }

  isSubmitting.value = true
  try {
    await createTransaction({
      account_id: formAccountId.value,
      category_id: formCategoryId.value,
      amount: formAmount.value,
      type: formType.value,
      date: formDate.value,
      note: formNote.value.trim() || null,
    })
    formAmount.value = null
    formNote.value = ''
    showForm.value = false
    await loadReferenceData() // 帳戶餘額已變動
    await loadTransactions()
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    formError.value = axiosErr.response?.data?.detail ?? '新增失敗'
  } finally {
    isSubmitting.value = false
  }
}

async function handleDelete(id: string) {
  if (!confirm('確定刪除此筆交易？帳戶餘額將會回復。')) return
  try {
    await deleteTransaction(id)
    await loadReferenceData()
    await loadTransactions()
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    alert(axiosErr.response?.data?.detail ?? '刪除失敗')
  }
}

function startEdit(tx: TransactionOut) {
  editingId.value = tx.id
  editAccountId.value = tx.account_id
  editCategoryId.value = tx.category_id
  editAmount.value = tx.amount
  editType.value = tx.type
  editDate.value = tx.date
  editNote.value = tx.note ?? ''
  editError.value = ''
}

function cancelEdit() {
  editingId.value = null
  editError.value = ''
}

async function saveEdit(id: string) {
  editError.value = ''

  if (!editAmount.value || editAmount.value <= 0) {
    editError.value = '金額必須大於 0'
    return
  }

  isSavingEdit.value = true
  try {
    await updateTransaction(id, {
      account_id: editAccountId.value,
      category_id: editCategoryId.value,
      amount: editAmount.value,
      type: editType.value,
      date: editDate.value,
      note: editNote.value.trim() || null,
    })
    editingId.value = null
    await loadReferenceData() // 帳戶餘額已因金額/類型變動而重新計算
    await loadTransactions()
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    editError.value = axiosErr.response?.data?.detail ?? '更新失敗'
  } finally {
    isSavingEdit.value = false
  }
}
</script>

<template>
  <div>
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px">
      <h2 style="font-size: 15px; color: #6b7a74; text-transform: uppercase; letter-spacing: 0.04em; margin: 0">
        交易紀錄
      </h2>
      <button
        class="btn-primary"
        style="width: auto; padding: 6px 14px; font-size: 13px"
        @click="openAddForm"
      >
        {{ showForm ? '取消' : '+ 新增交易' }}
      </button>
    </div>

    <!-- 篩選列 -->
    <div class="filter-bar">
      <input v-model="filterStartDate" type="date" class="filter-input" title="開始日期" />
      <span style="color: #6b7a74">至</span>
      <input v-model="filterEndDate" type="date" class="filter-input" title="結束日期" />
      <select v-model="filterAccountId" class="filter-input">
        <option value="">所有帳戶</option>
        <option v-for="a in accounts" :key="a.id" :value="a.id">{{ a.name }}</option>
      </select>
      <select v-model="filterCategoryId" class="filter-input">
        <option value="">所有分類</option>
        <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
      </select>
    </div>

    <div v-if="loadError" class="error-banner">{{ loadError }}</div>

    <!-- 新增表單 -->
    <form v-if="showForm" class="inline-card" @submit.prevent="handleCreate">
      <div v-if="formError" class="error-banner">{{ formError }}</div>

      <div class="field">
        <label for="tx-type">收支類型</label>
        <select id="tx-type" v-model="formType" class="select-input">
          <option value="expense">支出</option>
          <option value="income">收入</option>
        </select>
      </div>
      <div class="field">
        <label for="tx-account">帳戶</label>
        <select id="tx-account" v-model="formAccountId" class="select-input" required>
          <option value="" disabled>請選擇帳戶</option>
          <option v-for="a in accounts" :key="a.id" :value="a.id">{{ a.name }}</option>
        </select>
      </div>
      <div class="field">
        <label>分類</label>
        <CategoryPicker
          v-model="formCategoryId"
          :type="formType"
          :categories="categories"
          @created="handleCategoryCreated"
        />
      </div>
      <div class="field">
        <label for="tx-amount">金額</label>
        <input id="tx-amount" v-model.number="formAmount" type="number" min="1" step="1" required />
      </div>
      <div class="field">
        <label for="tx-date">日期</label>
        <input id="tx-date" v-model="formDate" type="date" required />
      </div>
      <div class="field">
        <label for="tx-note">備註（選填）</label>
        <input id="tx-note" v-model="formNote" type="text" maxlength="500" />
      </div>
      <button class="btn-primary" type="submit" :disabled="isSubmitting">
        {{ isSubmitting ? '新增中…' : '確認新增' }}
      </button>
    </form>

    <!-- 帳戶餘額總覽 -->
    <div v-if="!isLoading && accounts.length > 0">
      <h3 class="section-label">帳戶餘額</h3>
      <div class="account-balance-bar">
        <span v-for="a in accounts" :key="a.id" class="balance-chip">
          {{ a.name }}：<strong>{{ formatCurrency(a.balance) }}</strong>
        </span>
        <span class="balance-chip total-chip">
          總計：<strong>{{ formatCurrency(totalBalance) }}</strong>
        </span>
      </div>
    </div>

    <!-- 統計摘要 -->
    <div v-if="!isLoading">
      <h3 class="section-label">
        本期收支
        <span class="date-range">（{{ filterStartDate || '起' }} ～ {{ filterEndDate || '今' }}）</span>
      </h3>
      <div class="summary-bar">
        <span>收入 <strong style="color: var(--color-primary)">{{ formatCurrency(totalIncome) }}</strong></span>
        <span>支出 <strong style="color: var(--color-danger)">{{ formatCurrency(totalExpense) }}</strong></span>
        <span>結餘 <strong>{{ formatCurrency(totalIncome - totalExpense) }}</strong></span>
      </div>
    </div>

    <p v-if="!isLoading && transactions.length === 0" style="color: #6b7a74; font-size: 13px">
      沒有符合條件的交易紀錄。
    </p>

    <div v-for="group in groupedTransactions" :key="group.date" class="date-group">
      <h4 class="date-header">{{ formatDateHeader(group.date) }}</h4>

      <div
        v-for="tx in group.items"
        :key="tx.id"
        class="tx-card"
      >
        <template v-if="editingId !== tx.id">
          <div class="tx-card-main">
            <div class="tx-card-info">
              <strong class="tx-category">{{ categoryName(tx.category_id) }}</strong>
              <span class="tx-sub">{{ accountName(tx.account_id) }}<template v-if="tx.note"> · {{ tx.note }}</template></span>
            </div>
            <span
              class="tx-amount"
              :style="{ color: tx.type === 'income' ? 'var(--color-primary)' : 'var(--color-danger)' }"
            >
              {{ tx.type === 'income' ? '+' : '-' }}{{ formatCurrency(tx.amount) }}
            </span>
          </div>
          <div class="tx-card-actions">
            <button class="btn-edit" @click="startEdit(tx)">編輯</button>
            <button class="btn-delete" @click="handleDelete(tx.id)">刪除</button>
          </div>
        </template>

        <form v-else class="edit-tx-form" @submit.prevent="saveEdit(tx.id)">
          <div v-if="editError" class="error-banner">{{ editError }}</div>
          <div class="edit-tx-grid">
            <select v-model="editType" class="select-input">
              <option value="expense">支出</option>
              <option value="income">收入</option>
            </select>
            <select v-model="editAccountId" class="select-input">
              <option v-for="a in accounts" :key="a.id" :value="a.id">{{ a.name }}</option>
            </select>
            <input v-model.number="editAmount" type="number" min="1" step="1" class="select-input" />
            <input v-model="editDate" type="date" class="select-input" />
            <input v-model="editNote" type="text" maxlength="500" placeholder="備註" class="select-input" style="grid-column: span 2" />
          </div>
          <div style="margin-top: 8px">
            <CategoryPicker
              v-model="editCategoryId"
              :type="editType"
              :categories="categories"
              @created="handleCategoryCreated"
            />
          </div>
          <div style="display: flex; gap: 8px; margin-top: 8px">
            <button class="btn-primary" type="submit" style="width: auto; padding: 6px 14px" :disabled="isSavingEdit">
              {{ isSavingEdit ? '儲存中…' : '儲存' }}
            </button>
            <button type="button" class="btn-text" @click="cancelEdit">取消</button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<style scoped>
.date-group {
  margin-bottom: 16px;
}

.date-header {
  font-size: 12px;
  color: #6b7a74;
  font-weight: 600;
  margin: 0 0 8px;
  padding-bottom: 4px;
  border-bottom: 1px solid var(--color-border);
}

.tx-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 10px;
  padding: 14px 16px;
  margin-bottom: 10px;
}

.tx-card-main {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
}

.tx-card-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.tx-category {
  font-size: 15px;
  white-space: normal;
  word-break: break-word;
}

.tx-sub {
  font-size: 12px;
  color: #6b7a74;
}

.tx-amount {
  font-size: 17px;
  font-weight: 700;
  white-space: nowrap;
}

.tx-card-actions {
  display: flex;
  justify-content: space-between;
  margin-top: 12px;
  padding-top: 10px;
  border-top: 1px solid var(--color-border);
}

/* 編輯放左、刪除放右,顏色明顯區隔,並保留足夠間距避免手機誤觸 */
.btn-edit {
  background: none;
  border: 1.5px solid var(--color-primary);
  color: var(--color-primary);
  font-size: 13px;
  font-weight: 600;
  padding: 6px 16px;
  border-radius: 6px;
}

.btn-delete {
  background: var(--color-danger);
  border: 1.5px solid var(--color-danger);
  color: #fff;
  font-size: 13px;
  font-weight: 600;
  padding: 6px 16px;
  border-radius: 6px;
}

.inline-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  padding: 16px;
  margin-bottom: 12px;
}

.select-input {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid var(--color-border);
  border-radius: 8px;
  font-size: 14px;
  background: var(--color-bg);
}

.filter-bar {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 12px;
  align-items: center;
}

.filter-input {
  padding: 6px 10px;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  font-size: 13px;
  background: var(--color-surface);
}

.summary-bar {
  display: flex;
  gap: 20px;
  font-size: 13px;
  color: #445048;
  padding: 10px 0;
  margin-bottom: 8px;
  border-bottom: 1px solid var(--color-border);
}

.account-balance-bar {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-bottom: 12px;
}

.section-label {
  font-size: 12px;
  color: #6b7a74;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  margin: 0 0 6px;
  font-weight: 600;
}

.date-range {
  text-transform: none;
  letter-spacing: normal;
  font-weight: 400;
}

.balance-chip {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 999px;
  padding: 6px 14px;
  font-size: 13px;
  color: #445048;
}

.total-chip {
  background: var(--color-primary);
  color: #fff;
  border-color: var(--color-primary);
}

.btn-text {
  background: none;
  border: none;
  color: var(--color-primary);
  font-size: 13px;
  padding: 4px 8px;
}

.edit-tx-form {
  padding: 8px 0;
}

.edit-tx-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 8px;
}

.row-card {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  margin-bottom: 8px;
}

.btn-text-danger {
  background: none;
  border: none;
  color: var(--color-danger);
  font-size: 13px;
  padding: 4px 8px;
}
</style>
