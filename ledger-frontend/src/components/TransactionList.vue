<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import type { AxiosError } from 'axios'
import AppIcon from './AppIcon.vue'
import CategoryFilterPicker from './CategoryFilterPicker.vue'
import AccountFilterPicker from './AccountFilterPicker.vue'
import TagFilterPicker from './TagFilterPicker.vue'
import TransactionFormDialog from './TransactionFormDialog.vue'
import { fetchAccounts, fetchCategories, fetchTags, fetchTransactions, deleteTransaction } from '@/api/ledgerApi'
import { formatCurrency, ENTRY_TYPE_LABEL } from '@/utils/ledgerLabels'
import { presetRange, toLocalISODate, todayLocal, type RangePreset } from '@/utils/date'
import { toCsv, downloadCsv } from '@/utils/csv'
import type { AccountOut, CategoryOut, EntryType, TagOut, TransactionOut } from '@/types/ledger'
import type { ApiError } from '@/types/api'

const PRESETS: { key: RangePreset; label: string }[] = [
  { key: 'thisMonth', label: '本月' },
  { key: 'lastMonth', label: '上月' },
  { key: 'last3Months', label: '近 3 個月' },
  { key: 'thisYear', label: '今年' },
]

const accounts = ref<AccountOut[]>([])
const categories = ref<CategoryOut[]>([])
const tags = ref<TagOut[]>([])
const transactions = ref<TransactionOut[]>([])
const isLoading = ref(true)
const loadError = ref('')

// ---------- 查詢條件(後端篩選,條件一變就重新查詢) ----------
const initialRange = presetRange('thisMonth')
const filterStartDate = ref(initialRange.start)
const filterEndDate = ref(initialRange.end)
const filterAccountId = ref('')
const filterCategoryId = ref('')
const filterTagIds = ref<string[]>([])
const filterMinAmount = ref<number | null>(null)
const filterMaxAmount = ref<number | null>(null)
const showAdvancedFilter = ref(false)

// ---------- 結果篩選(前端,不重新查詢) ----------
const typeFilter = ref<Record<EntryType, boolean>>({ expense: true, income: true })
const searchText = ref('')
type SortKey = 'date' | 'amount'
const sortKey = ref<SortKey>('date')
const sortDesc = ref(true)

const formDialog = ref<InstanceType<typeof TransactionFormDialog> | null>(null)

// ---------- 名稱查表 ----------
const accountById = computed(() => new Map(accounts.value.map((a) => [a.id, a])))
const categoryById = computed(() => new Map(categories.value.map((c) => [c.id, c])))

function accountName(id: string): string {
  return accountById.value.get(id)?.name ?? '（已刪除帳戶）'
}
function categoryName(id: string): string {
  const names: string[] = []
  const seen = new Set<string>() // 防呆:資料若出現循環 parent 不會卡死
  let current = categoryById.value.get(id)
  while (current && !seen.has(current.id)) {
    seen.add(current.id)
    names.unshift(current.name)
    current = current.parent_id ? categoryById.value.get(current.parent_id) : undefined
  }
  return names.length > 0 ? names.join(' - ') : '（已刪除分類）'
}

// ---------- 載入 ----------
async function loadReferenceData() {
  const [accountsData, categoriesData, tagsData] = await Promise.all([fetchAccounts(), fetchCategories(), fetchTags()])
  accounts.value = accountsData
  categories.value = categoriesData
  tags.value = tagsData
}

let requestSeq = 0 // 條件快速連續變動時,只採用最後一次查詢的結果
async function loadTransactions() {
  const seq = ++requestSeq
  isLoading.value = true
  loadError.value = ''
  try {
    const data = await fetchTransactions({
      start_date: filterStartDate.value || undefined,
      end_date: filterEndDate.value || undefined,
      account_id: filterAccountId.value || undefined,
      category_id: filterCategoryId.value || undefined,
      tag_ids: filterTagIds.value.length ? filterTagIds.value : undefined,
      min_amount: filterMinAmount.value ?? undefined,
      max_amount: filterMaxAmount.value ?? undefined,
    })
    if (seq === requestSeq) transactions.value = data
  } catch {
    if (seq === requestSeq) loadError.value = '載入交易紀錄失敗'
  } finally {
    if (seq === requestSeq) isLoading.value = false
  }
}

async function reloadAll() {
  try {
    await loadReferenceData()
  } catch {
    loadError.value = '載入帳戶/分類資料失敗'
  }
  await loadTransactions()
}

onMounted(reloadAll)

watch(
  [filterStartDate, filterEndDate, filterAccountId, filterCategoryId, filterTagIds, filterMinAmount, filterMaxAmount],
  loadTransactions,
)

// ---------- 查詢條件操作 ----------
function applyPreset(key: RangePreset) {
  const r = presetRange(key)
  filterStartDate.value = r.start
  filterEndDate.value = r.end
}
function isPresetActive(key: RangePreset): boolean {
  const r = presetRange(key)
  return r.start === filterStartDate.value && r.end === filterEndDate.value
}

const activeAdvancedFilterCount = computed(
  () => [filterAccountId.value, filterCategoryId.value, filterTagIds.value.length].filter(Boolean).length,
)

function toggleType(t: EntryType) {
  typeFilter.value = { ...typeFilter.value, [t]: !typeFilter.value[t] }
}

function clearFilters() {
  filterAccountId.value = ''
  filterCategoryId.value = ''
  filterTagIds.value = []
  filterMinAmount.value = null
  filterMaxAmount.value = null
  typeFilter.value = { expense: true, income: true }
  searchText.value = ''
}

// ---------- 結果 ----------
function searchableText(tx: TransactionOut): string {
  return [categoryName(tx.category_id), accountName(tx.account_id), tx.note ?? '', ...tx.tags.map((t) => t.name), String(tx.amount)]
    .join(' ')
    .toLowerCase()
}

const visibleTransactions = computed(() => {
  const keyword = searchText.value.trim().toLowerCase()
  const rows = transactions.value.filter(
    (tx) => typeFilter.value[tx.type] && (!keyword || searchableText(tx).includes(keyword)),
  )
  const dir = sortDesc.value ? -1 : 1
  // 後端已依日期新到舊排序;排序穩定(相同值維持原順序)
  return rows
    .map((tx, i) => ({ tx, i }))
    .sort((a, b) => {
      const diff =
        sortKey.value === 'amount' ? a.tx.amount - b.tx.amount : a.tx.date.localeCompare(b.tx.date)
      return diff !== 0 ? diff * dir : a.i - b.i
    })
    .map(({ tx }) => tx)
})

function setSort(key: SortKey) {
  if (sortKey.value === key) {
    sortDesc.value = !sortDesc.value
  } else {
    sortKey.value = key
    sortDesc.value = true
  }
}
function sortMark(key: SortKey): string {
  return sortKey.value === key ? (sortDesc.value ? ' ▼' : ' ▲') : ''
}

const totalIncome = computed(() =>
  visibleTransactions.value.filter((t) => t.type === 'income').reduce((sum, t) => sum + t.amount, 0),
)
const totalExpense = computed(() =>
  visibleTransactions.value.filter((t) => t.type === 'expense').reduce((sum, t) => sum + t.amount, 0),
)
const totalBalance = computed(() => accounts.value.reduce((sum, a) => sum + a.balance, 0))

function dateHint(isoDate: string): string {
  if (isoDate === todayLocal()) return '今天'
  const y = new Date()
  y.setDate(y.getDate() - 1)
  return isoDate === toLocalISODate(y) ? '昨天' : ''
}

// ---------- 新增 / 編輯 / 刪除 ----------
function openCreate() {
  formDialog.value?.openCreate()
}
function openEdit(tx: TransactionOut) {
  formDialog.value?.openEdit(tx)
}

async function handleDelete(tx: TransactionOut) {
  const label = `${tx.date} ${categoryName(tx.category_id)} ${formatCurrency(tx.amount)}`
  if (!confirm(`確定刪除此筆交易？\n${label}\n帳戶餘額將會回復。`)) return
  try {
    await deleteTransaction(tx.id)
    await reloadAll() // 帳戶餘額已變動
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    alert(axiosErr.response?.data?.detail ?? '刪除失敗')
  }
}

// ---------- 匯出 CSV(目前畫面上的結果,含前端篩選與排序) ----------
function exportCsv() {
  const header = ['日期', '類型', '分類', '帳戶', '消費品項', '備註', '金額', '收支(支出為負)']
  const rows = visibleTransactions.value.map((tx) => [
    tx.date,
    ENTRY_TYPE_LABEL[tx.type],
    categoryName(tx.category_id),
    accountName(tx.account_id),
    tx.tags.map((t) => t.name).join('、'),
    tx.note ?? '',
    tx.amount,
    tx.type === 'expense' ? -tx.amount : tx.amount,
  ])
  downloadCsv(`交易紀錄_${filterStartDate.value || '起'}_${filterEndDate.value || '今'}.csv`, toCsv(header, rows))
}
</script>

<template>
  <!-- ========== 查詢 ========== -->
  <section class="panel">
    <div class="panel-head">
      <h2><AppIcon name="search" />交易查詢</h2>
      <span class="spacer"></span>
      <button type="button" class="btn primary" @click="openCreate"><AppIcon name="plus" />新增交易</button>
    </div>
    <div class="panel-body">
      <div class="form-grid">
        <div class="form-field">
          <label for="q-start">開始日期</label>
          <input id="q-start" v-model="filterStartDate" type="date" :max="filterEndDate || undefined" />
        </div>
        <div class="form-field">
          <label for="q-end">結束日期</label>
          <input id="q-end" v-model="filterEndDate" type="date" :min="filterStartDate || undefined" />
        </div>
        <div class="form-field span2">
          <span class="label">快速選擇</span>
          <div class="row">
            <button
              v-for="p in PRESETS"
              :key="p.key"
              type="button"
              class="btn sm"
              :class="{ on: isPresetActive(p.key) }"
              :aria-pressed="isPresetActive(p.key)"
              @click="applyPreset(p.key)"
            >
              {{ p.label }}
            </button>
          </div>
        </div>

        <div class="form-field span2">
          <span class="label">類型</span>
          <div class="keypad" role="group" aria-label="收支類型">
            <button
              type="button"
              class="key"
              :class="{ active: typeFilter.expense }"
              :aria-pressed="typeFilter.expense"
              @click="toggleType('expense')"
            >
              <AppIcon name="expense" class="ic-expense" />支出
            </button>
            <button
              type="button"
              class="key"
              :class="{ active: typeFilter.income }"
              :aria-pressed="typeFilter.income"
              @click="toggleType('income')"
            >
              <AppIcon name="income" class="ic-income" />收入
            </button>
          </div>
        </div>
        <div class="form-field span2">
          <span class="label">金額區間</span>
          <div class="row nowrap">
            <input v-model.number="filterMinAmount" type="number" min="0" placeholder="最低金額" aria-label="最低金額" />
            <span class="sep">~</span>
            <input v-model.number="filterMaxAmount" type="number" min="0" placeholder="最高金額" aria-label="最高金額" />
          </div>
        </div>
      </div>

      <div class="row adv-row">
        <button
          type="button"
          class="btn sm"
          :class="{ on: showAdvancedFilter }"
          :aria-expanded="showAdvancedFilter"
          @click="showAdvancedFilter = !showAdvancedFilter"
        >
          <AppIcon name="filter" />進階篩選<template v-if="activeAdvancedFilterCount">（{{ activeAdvancedFilterCount }}）</template>
        </button>
        <span class="hint">帳戶、分類、消費品項</span>
        <span class="spacer"></span>
        <button type="button" class="btn ghost sm" @click="clearFilters"><AppIcon name="x" />清除條件</button>
      </div>

      <div v-if="showAdvancedFilter" class="adv-grid">
        <div class="form-field">
          <span class="label">帳戶</span>
          <AccountFilterPicker v-model="filterAccountId" :accounts="accounts" />
        </div>
        <div class="form-field">
          <span class="label">分類</span>
          <CategoryFilterPicker v-model="filterCategoryId" :categories="categories" />
        </div>
        <div class="form-field">
          <span class="label">消費品項</span>
          <TagFilterPicker v-model="filterTagIds" :tags="tags" />
        </div>
      </div>
    </div>
  </section>

  <!-- ========== 結果 ========== -->
  <section class="panel">
    <div class="panel-head">
      <h2><AppIcon name="table" />交易明細</h2>
      <span class="pill">{{ filterStartDate || '起' }} ~ {{ filterEndDate || '今' }}・{{ visibleTransactions.length }} 筆</span>
      <span class="spacer"></span>
      <button type="button" class="btn sm" :disabled="visibleTransactions.length === 0" @click="exportCsv">
        <AppIcon name="download" />匯出 CSV
      </button>
    </div>

    <div class="panel-body summary">
      <div class="stat-grid">
        <div class="stat">
          <div class="stat-label">筆數</div>
          <div class="stat-value">{{ visibleTransactions.length }}</div>
        </div>
        <div class="stat">
          <div class="stat-label">收入</div>
          <div class="stat-value income">{{ formatCurrency(totalIncome) }}</div>
        </div>
        <div class="stat">
          <div class="stat-label">支出</div>
          <div class="stat-value expense">{{ formatCurrency(totalExpense) }}</div>
        </div>
        <div class="stat">
          <div class="stat-label">結餘（收入 − 支出）</div>
          <div class="stat-value" :class="totalIncome - totalExpense < 0 ? 'expense' : 'income'">
            {{ formatCurrency(totalIncome - totalExpense) }}
          </div>
        </div>
        <div class="stat">
          <div class="stat-label">帳戶總餘額（目前）</div>
          <div class="stat-value">{{ formatCurrency(totalBalance) }}</div>
        </div>
      </div>
      <div v-if="accounts.length" class="row balances">
        <span class="hint">帳戶餘額</span>
        <span v-for="a in accounts" :key="a.id" class="pill" :class="{ bad: a.balance < 0 }">
          {{ a.name }}：<b>{{ formatCurrency(a.balance) }}</b>
        </span>
      </div>
    </div>

    <div class="toolbar">
      <input v-model="searchText" type="search" placeholder="搜尋 分類 / 帳戶 / 品項 / 備註 / 金額" aria-label="搜尋" />
      <span v-if="isLoading" class="hint">載入中…</span>
    </div>

    <div v-if="loadError" class="panel-body">
      <div class="error-banner">{{ loadError }}</div>
    </div>

    <div v-if="visibleTransactions.length" class="table-wrap">
      <table class="grid">
        <thead>
          <tr>
            <th class="sortable" @click="setSort('date')">日期{{ sortMark('date') }}</th>
            <th>類型</th>
            <th>分類</th>
            <th>帳戶</th>
            <th>消費品項</th>
            <th>備註</th>
            <th class="num sortable" @click="setSort('amount')">金額{{ sortMark('amount') }}</th>
            <th class="num">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="tx in visibleTransactions" :key="tx.id">
            <td class="nowrap">
              {{ tx.date }}<span v-if="dateHint(tx.date)" class="date-hint">{{ dateHint(tx.date) }}</span>
            </td>
            <td><span class="badge" :class="tx.type">{{ ENTRY_TYPE_LABEL[tx.type] }}</span></td>
            <td class="cat">{{ categoryName(tx.category_id) }}</td>
            <td class="nowrap">{{ accountName(tx.account_id) }}</td>
            <td class="tags"><span v-for="t in tx.tags" :key="t.id" class="chip">{{ t.name }}</span></td>
            <td class="note">{{ tx.note ?? '' }}</td>
            <td class="num">
              <span class="amount" :class="tx.type">
                {{ tx.type === 'income' ? '+' : '-' }}{{ formatCurrency(tx.amount) }}
              </span>
            </td>
            <td class="actions">
              <button type="button" class="btn sm" @click="openEdit(tx)"><AppIcon name="edit" />編輯</button>
              <button type="button" class="btn danger sm" @click="handleDelete(tx)"><AppIcon name="trash" />刪除</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p v-else-if="!isLoading && !loadError" class="empty">沒有符合條件的交易紀錄。</p>
  </section>

  <TransactionFormDialog
    ref="formDialog"
    :accounts="accounts"
    :categories="categories"
    :tags="tags"
    @saved="reloadAll"
    @category-created="(c: CategoryOut) => categories.push(c)"
    @tag-created="(t: TagOut) => tags.push(t)"
  />
</template>

<style scoped>
.keypad { padding: 0; }
.ic-expense { color: var(--c-expense); }
.ic-income { color: var(--c-income); }
.row.nowrap { flex-wrap: nowrap; }
.row.nowrap input { min-width: 0; flex: 1; }
.sep { color: var(--muted); font-weight: 700; }
.adv-row { margin-top: 16px; padding-top: 14px; border-top: 1px dashed var(--line); }
.adv-row .spacer { flex: 1; }
.adv-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 16px; margin-top: 14px; }
.summary { padding-bottom: 14px; }
.balances { margin-top: 12px; }
.balances b { font-variant-numeric: tabular-nums; }
.date-hint { margin-left: 6px; font-size: 11.5px; font-weight: 700; color: var(--accent); }
.cat { min-width: 120px; }
.tags { min-width: 90px; }
.note { min-width: 120px; max-width: 320px; white-space: normal; word-break: break-word; color: var(--text-2); }
</style>
