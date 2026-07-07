<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { fetchAccounts, createAccount, updateAccount, deleteAccount } from '@/api/ledger'
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
  <div>
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px">
      <h2 style="font-size: 15px; color: #6b7a74; text-transform: uppercase; letter-spacing: 0.04em; margin: 0">
        帳戶
      </h2>
      <button
        class="btn-primary"
        style="width: auto; padding: 6px 14px; font-size: 13px"
        @click="showForm = !showForm"
      >
        {{ showForm ? '取消' : '+ 新增帳戶' }}
      </button>
    </div>

    <div v-if="loadError" class="error-banner">{{ loadError }}</div>

    <form v-if="showForm" class="inline-card" @submit.prevent="handleCreate">
      <div v-if="formError" class="error-banner">{{ formError }}</div>
      <div class="field">
        <label for="acc-name">帳戶名稱</label>
        <input id="acc-name" v-model="name" type="text" required maxlength="100" />
      </div>
      <div class="field">
        <label for="acc-type">類型</label>
        <select id="acc-type" v-model="type" class="select-input">
          <option value="cash">現金</option>
          <option value="bank">銀行</option>
          <option value="credit_card">信用卡</option>
        </select>
      </div>
      <div class="field">
        <label for="acc-balance">起始餘額</label>
        <input id="acc-balance" v-model.number="balance" type="number" step="1" />
      </div>
      <div class="field" style="display: flex; align-items: center; gap: 8px">
        <input id="acc-default" v-model="isDefaultExpense" type="checkbox" style="width: auto" />
        <label for="acc-default" style="margin: 0">設為預設支出帳戶</label>
      </div>
      <button class="btn-primary" type="submit" :disabled="isSubmitting">
        {{ isSubmitting ? '新增中…' : '確認新增' }}
      </button>
    </form>

    <p v-if="!isLoading && accounts.length === 0" style="color: #6b7a74; font-size: 13px">
      尚未建立任何帳戶。
    </p>

    <ul style="list-style: none; padding: 0; margin: 0">
      <li v-for="account in accounts" :key="account.id" class="row-card" style="flex-direction: column; align-items: stretch">
        <div style="display: flex; justify-content: space-between; align-items: center">
          <div>
            <strong>{{ account.name }}</strong>
            <span style="color: #6b7a74; font-size: 12px; margin-left: 8px">
              {{ ACCOUNT_TYPE_LABEL[account.type] }}
            </span>
            <span v-if="account.is_default_expense" class="default-badge">預設支出帳戶</span>
          </div>
          <div style="display: flex; align-items: center; gap: 12px">
            <template v-if="editingId !== account.id">
              <span :style="{ color: account.balance < 0 ? 'var(--color-danger)' : 'var(--color-ink)' }">
                {{ formatCurrency(account.balance) }}
              </span>
              <button v-if="!account.is_default_expense" class="btn-text" @click="setDefaultExpense(account.id)">
                設為預設
              </button>
              <button class="btn-text" @click="startEdit(account)">調整餘額</button>
              <button class="btn-text-danger" @click="handleDelete(account.id)">刪除</button>
            </template>
          </div>
        </div>

        <div v-if="editingId === account.id" class="edit-balance-row">
          <div v-if="editError" class="error-banner" style="margin: 8px 0">{{ editError }}</div>
          <input v-model.number="editBalance" type="number" step="1" class="balance-input" />
          <button class="btn-primary" style="width: auto; padding: 6px 14px" :disabled="isSavingEdit" @click="saveEdit(account.id)">
            {{ isSavingEdit ? '儲存中…' : '儲存' }}
          </button>
          <button class="btn-text" @click="cancelEdit">取消</button>
        </div>
      </li>
    </ul>
  </div>
</template>

<style scoped>
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

.default-badge {
  display: inline-block;
  background: var(--color-primary);
  color: #fff;
  font-size: 11px;
  padding: 2px 8px;
  border-radius: 999px;
  margin-left: 8px;
}

.btn-text {
  background: none;
  border: none;
  color: var(--color-primary);
  font-size: 13px;
  padding: 4px 8px;
}

.edit-balance-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 8px;
  padding-top: 8px;
  border-top: 1px solid var(--color-border);
}

.balance-input {
  flex: 1;
  padding: 8px 10px;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  font-size: 14px;
}
</style>
