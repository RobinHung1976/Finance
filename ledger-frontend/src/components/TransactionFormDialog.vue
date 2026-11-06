<script setup lang="ts">
import { computed, ref } from 'vue'
import type { AxiosError } from 'axios'
import AppIcon from './AppIcon.vue'
import CategoryPicker from './CategoryPicker.vue'
import TagPicker from './TagPicker.vue'
import { createTransaction, updateTransaction } from '@/api/ledgerApi'
import { todayLocal } from '@/utils/date'
import type { AccountOut, CategoryOut, EntryType, TagOut, TransactionOut } from '@/types/ledger'
import type { ApiError } from '@/types/api'

const props = defineProps<{
  accounts: AccountOut[]
  categories: CategoryOut[]
  tags: TagOut[]
}>()

const emit = defineEmits<{
  saved: []
  categoryCreated: [category: CategoryOut]
  tagCreated: [tag: TagOut]
}>()

const dialogRef = ref<HTMLDialogElement | null>(null)
const editingId = ref<string | null>(null) // null = 新增模式

const type = ref<EntryType>('expense')
const accountId = ref('')
const categoryId = ref('')
const amount = ref<number | null>(null)
const date = ref(todayLocal())
const note = ref('')
const tagIds = ref<string[]>([])
const error = ref('')
const isSaving = ref(false)

const isEdit = computed(() => editingId.value !== null)

// 新增:沿用上一次新增的類型/帳戶/分類(連續記帳較快),其餘清空、日期重設為今天
function openCreate() {
  editingId.value = null
  date.value = todayLocal()
  amount.value = null
  note.value = ''
  tagIds.value = []
  error.value = ''
  if (!accountId.value || !props.accounts.some((a) => a.id === accountId.value)) {
    accountId.value = props.accounts.find((a) => a.is_default_expense)?.id ?? ''
  }
  dialogRef.value?.showModal()
}

function openEdit(tx: TransactionOut) {
  editingId.value = tx.id
  type.value = tx.type
  accountId.value = tx.account_id
  categoryId.value = tx.category_id
  amount.value = tx.amount
  date.value = tx.date
  note.value = tx.note ?? ''
  tagIds.value = tx.tags.map((t) => t.id)
  error.value = ''
  dialogRef.value?.showModal()
}

function close() {
  dialogRef.value?.close()
}

function setType(next: EntryType) {
  if (type.value === next) return
  type.value = next
  categoryId.value = '' // 收支類型的分類樹不同,切換後需重選
}

function validate(): string {
  if (!accountId.value) return '請選擇帳戶'
  if (!categoryId.value) return '請選擇分類'
  if (!amount.value || amount.value <= 0 || !Number.isInteger(amount.value)) return '金額必須是大於 0 的整數'
  if (!date.value) return '請選擇日期'
  return ''
}

async function handleSubmit() {
  error.value = validate()
  if (error.value) return

  const payload = {
    account_id: accountId.value,
    category_id: categoryId.value,
    amount: amount.value as number,
    type: type.value,
    date: date.value,
    note: note.value.trim() || null,
    tag_ids: tagIds.value,
  }

  isSaving.value = true
  try {
    if (editingId.value) {
      await updateTransaction(editingId.value, payload)
    } else {
      await createTransaction(payload)
    }
    close()
    emit('saved')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    error.value = axiosErr.response?.data?.detail ?? (isEdit.value ? '更新失敗' : '新增失敗')
  } finally {
    isSaving.value = false
  }
}

defineExpose({ openCreate, openEdit })
</script>

<template>
  <dialog ref="dialogRef" class="modal" aria-labelledby="tx-dialog-title">
    <form @submit.prevent="handleSubmit">
      <div class="panel-head">
        <h2 id="tx-dialog-title"><AppIcon :name="isEdit ? 'edit' : 'plus'" />{{ isEdit ? '編輯交易' : '新增交易' }}</h2>
        <span class="spacer"></span>
        <button type="button" class="btn ghost sm" aria-label="關閉" @click="close"><AppIcon name="x" /></button>
      </div>

      <div class="panel-body">
        <div v-if="error" class="error-banner" role="alert">{{ error }}</div>

        <div class="form-grid">
          <div class="form-field wide">
            <span class="label">收支類型</span>
            <div class="keypad" role="radiogroup" aria-label="收支類型">
              <button
                type="button"
                role="radio"
                class="key"
                :class="{ active: type === 'expense' }"
                :aria-checked="type === 'expense'"
                @click="setType('expense')"
              >
                <AppIcon name="expense" class="ic-expense" />支出
              </button>
              <button
                type="button"
                role="radio"
                class="key"
                :class="{ active: type === 'income' }"
                :aria-checked="type === 'income'"
                @click="setType('income')"
              >
                <AppIcon name="income" class="ic-income" />收入
              </button>
            </div>
          </div>

          <div class="form-field">
            <label for="tx-amount">金額</label>
            <input id="tx-amount" v-model.number="amount" type="number" min="1" step="1" required inputmode="numeric" />
          </div>
          <div class="form-field">
            <label for="tx-date">日期</label>
            <input id="tx-date" v-model="date" type="date" required />
          </div>
          <div class="form-field">
            <label for="tx-account">帳戶</label>
            <select id="tx-account" v-model="accountId" required>
              <option value="" disabled>請選擇帳戶</option>
              <option v-for="a in accounts" :key="a.id" :value="a.id">{{ a.name }}</option>
            </select>
          </div>
          <div class="form-field">
            <label for="tx-note">備註 <span class="hint">（選填）</span></label>
            <input id="tx-note" v-model="note" type="text" maxlength="500" />
          </div>

          <div class="form-field wide">
            <span class="label">分類</span>
            <CategoryPicker
              v-model="categoryId"
              :type="type"
              :categories="categories"
              @created="(c: CategoryOut) => emit('categoryCreated', c)"
            />
          </div>
          <div class="form-field wide">
            <span class="label">消費品項 <span class="hint">（選填）</span></span>
            <TagPicker v-model="tagIds" :tags="tags" @created="(t: TagOut) => emit('tagCreated', t)" />
          </div>
        </div>
      </div>

      <div class="modal-foot">
        <button type="button" class="btn" @click="close">取消</button>
        <button type="submit" class="btn primary" :disabled="isSaving">
          {{ isSaving ? '儲存中…' : isEdit ? '儲存' : '確認新增' }}
        </button>
      </div>
    </form>
  </dialog>
</template>

<style scoped>
.form-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
.keypad { padding: 0; }
.ic-expense { color: #b8391a; }
.ic-income { color: #1f8a4c; }
</style>
