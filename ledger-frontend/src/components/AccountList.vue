<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import AppIcon from './AppIcon.vue'
import { fetchAccounts, createAccount, updateAccount, deleteAccount } from '@/api/ledgerApi'
import { ACCOUNT_TYPE_LABEL, formatCurrency } from '@/utils/ledgerLabels'
import type { AccountOut, AccountType } from '@/types/ledger'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const emit = defineEmits<{ changed: [] }>()

const accounts = ref<AccountOut[]>([])
const isLoading = ref(true)
const loadError = ref('')

const showForm = ref(false)
const name = ref('')
const type = ref<AccountType>('cash')
const balance = ref(0)
const isDefaultExpense = ref(false)
const formError = ref('')
const isSubmitting = ref(false)

const totalBalance = computed(() => accounts.value.reduce((sum, a) => sum + a.balance, 0))

function toggleForm() {
  showForm.value = !showForm.value
  formError.value = ''
}

// 編輯既有帳戶餘額
const editingId = ref<string | null>(null)
const editBalance = ref(0)
const editError = ref('')
const isSavingEdit = ref(false)

async function load() {
  isLoading.value = true
  try {
    accounts.value = await fetchAccounts()
  } catch {
    loadError.value = '載入帳戶失敗'
  } finally {
    isLoading.value = false
  }
}

onMounted(load)

async function handleCreate() {
  formError.value = ''
  if (!Number.isFinite(balance.value)) {
    formError.value = '請輸入起始餘額(可為 0 或負數)'
    return
  }
  if (!name.value.trim()) {
    formError.value = '請輸入帳戶名稱'
    return
  }
  isSubmitting.value = true
  try {
    await createAccount({
      name: name.value.trim(),
      type: type.value,
      balance: balance.value,
      is_default_expense: isDefaultExpense.value,
    })
    name.value = ''
    balance.value = 0
    isDefaultExpense.value = false
    showForm.value = false
    await load()
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    formError.value = axiosErr.response?.data?.detail ?? '新增失敗'
  } finally {
    isSubmitting.value = false
  }
}

async function handleDelete(id: string) {
  if (!confirm('確定刪除此帳戶？此操作無法復原。')) return
  try {
    await deleteAccount(id)
    await load()
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    alert(axiosErr.response?.data?.detail ?? '刪除失敗')
  }
}

function startEdit(account: AccountOut) {
  editingId.value = account.id
  editBalance.value = account.balance
  editError.value = ''
}

function cancelEdit() {
  editingId.value = null
  editError.value = ''
}

async function saveEdit(id: string) {
  editError.value = ''
  if (!Number.isFinite(editBalance.value)) {
    editError.value = '請輸入餘額'
    return
  }
  isSavingEdit.value = true
  try {
    await updateAccount(id, { balance: editBalance.value })
    editingId.value = null
    await load()
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    editError.value = axiosErr.response?.data?.detail ?? '更新失敗'
  } finally {
    isSavingEdit.value = false
  }
}

async function setDefaultExpense(id: string) {
  try {
    await updateAccount(id, { is_default_expense: true })
    await load()
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    alert(axiosErr.response?.data?.detail ?? '設定失敗')
  }
}
</script>

<template>
  <section class="panel">
    <div class="panel-head">
      <h2><AppIcon name="wallet" />帳戶</h2>
      <span v-if="!isLoading" class="pill">{{ accounts.length }} 個</span>
      <span class="spacer"></span>
      <button type="button" class="btn primary" :class="{ on: showForm }" @click="toggleForm">
        <AppIcon :name="showForm ? 'x' : 'plus'" />{{ showForm ? '取消新增' : '新增帳戶' }}
      </button>
    </div>

    <div v-if="loadError" class="panel-body">
      <div class="error-banner">{{ loadError }}</div>
    </div>

    <form v-if="showForm" class="panel-body add-form" @submit.prevent="handleCreate">
      <div v-if="formError" class="error-banner" role="alert">{{ formError }}</div>
      <div class="form-grid">
        <div class="form-field">
          <label for="acc-name">帳戶名稱</label>
          <input id="acc-name" v-model="name" type="text" required maxlength="100" />
        </div>
        <div class="form-field">
          <label for="acc-type">類型</label>
          <select id="acc-type" v-model="type">
            <option value="cash">現金</option>
            <option value="bank">銀行</option>
            <option value="credit_card">信用卡</option>
          </select>
        </div>
        <div class="form-field">
          <label for="acc-balance">起始餘額</label>
          <input id="acc-balance" v-model.number="balance" type="number" step="1" />
        </div>
        <div class="form-field">
          <span class="label">預設支出帳戶</span>
          <label class="check"><input v-model="isDefaultExpense" type="checkbox" />新增交易時預設選取此帳戶</label>
        </div>
      </div>
      <div class="row form-actions">
        <button class="btn primary" type="submit" :disabled="isSubmitting">
          {{ isSubmitting ? '新增中…' : '確認新增' }}
        </button>
        <button class="btn" type="button" @click="toggleForm">取消</button>
      </div>
    </form>

    <div v-if="accounts.length" class="table-wrap">
      <table class="grid">
        <thead>
          <tr>
            <th>帳戶名稱</th>
            <th>類型</th>
            <th class="num">餘額</th>
            <th class="num">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="account in accounts" :key="account.id">
            <td>
              <b>{{ account.name }}</b>
              <span v-if="account.is_default_expense" class="pill ok default-pill">預設支出帳戶</span>
            </td>
            <td class="nowrap">{{ ACCOUNT_TYPE_LABEL[account.type] }}</td>
            <td class="num">
              <form v-if="editingId === account.id" class="edit-balance" @submit.prevent="saveEdit(account.id)">
                <input v-model.number="editBalance" type="number" step="1" aria-label="新餘額" />
                <button class="btn primary sm" type="submit" :disabled="isSavingEdit">
                  {{ isSavingEdit ? '儲存中…' : '儲存' }}
                </button>
                <button class="btn sm" type="button" @click="cancelEdit">取消</button>
                <div v-if="editError" class="field-error">{{ editError }}</div>
              </form>
              <span v-else class="amount" :class="{ expense: account.balance < 0 }">{{ formatCurrency(account.balance) }}</span>
            </td>
            <td class="actions">
              <template v-if="editingId !== account.id">
                <button v-if="!account.is_default_expense" type="button" class="btn sm" @click="setDefaultExpense(account.id)">
                  設為預設
                </button>
                <button type="button" class="btn sm" @click="startEdit(account)"><AppIcon name="edit" />調整餘額</button>
                <button type="button" class="btn danger sm" @click="handleDelete(account.id)"><AppIcon name="trash" />刪除</button>
              </template>
            </td>
          </tr>
        </tbody>
        <tfoot>
          <tr>
            <td colspan="2"><b>合計</b></td>
            <td class="num">
              <span class="amount" :class="{ expense: totalBalance < 0 }">{{ formatCurrency(totalBalance) }}</span>
            </td>
            <td></td>
          </tr>
        </tfoot>
      </table>
    </div>
    <p v-else-if="!isLoading && !loadError" class="empty">尚未建立任何帳戶。</p>
  </section>
</template>

<style scoped>
.add-form { border-bottom: 1px solid var(--line-soft); }
.form-actions { margin-top: 16px; }
.check { display: inline-flex; align-items: center; gap: 8px; min-height: var(--h-btn); cursor: pointer; }
.check input[type=checkbox] { width: 15px; flex: none; }
.default-pill { margin-left: 8px; }
.edit-balance { display: inline-flex; align-items: center; gap: 6px; flex-wrap: wrap; justify-content: flex-end; }
.edit-balance input { width: 140px; text-align: right; }
.field-error { flex-basis: 100%; color: var(--bad); font-size: 12px; text-align: right; }
tfoot td { border-top: 1px solid var(--line); background: rgb(255 255 255 / 40%); }
</style>
