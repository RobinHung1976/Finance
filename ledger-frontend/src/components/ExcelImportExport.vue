<template>
  <section class="panel">
    <div class="panel-head">
      <h2><AppIcon name="download" />匯出 Excel</h2>
    </div>
    <div class="panel-body">
      <div class="row">
        <label for="export-year" class="lbl">年份</label>
        <select id="export-year" v-model.number="exportYear">
          <option v-for="y in availableYears" :key="y" :value="y">{{ y }}</option>
        </select>
        <button type="button" class="btn primary" :disabled="exporting" @click="handleExport">
          <AppIcon name="download" />{{ exporting ? '匯出中…' : '下載 Excel' }}
        </button>
        <span class="hint">依年份輸出各月分頁,格式對齊舊版記帳 Excel</span>
      </div>
    </div>
  </section>

  <section class="panel">
    <div class="panel-head">
      <h2><AppIcon name="transfer" />匯入 Excel</h2>
      <span class="hint">先預覽,確認後才寫入</span>
    </div>
    <div class="panel-body">
      <div v-if="accountsError" class="error-banner">{{ accountsError }}</div>
      <div class="form-grid">
        <div class="form-field">
          <label for="import-account">目標帳戶</label>
          <select id="import-account" v-model="selectedAccountId">
            <option v-for="acc in accounts" :key="acc.id" :value="acc.id">
              {{ acc.name }}{{ acc.is_default_expense ? '(預設)' : '' }} - {{ ACCOUNT_TYPE_LABEL[acc.type] }}
            </option>
          </select>
        </div>
        <div class="form-field span2">
          <label for="import-file">Excel 檔案 <span class="hint">(.xlsx)</span></label>
          <div class="row nowrap">
            <input id="import-file" ref="fileInput" type="file" accept=".xlsx" class="file" @change="handleFileSelect" />
            <button
              v-if="selectedFile && !preview"
              type="button"
              class="btn primary"
              :disabled="!selectedAccountId || loading"
              @click="handlePreview"
            >
              {{ loading ? '解析中…' : '預覽' }}
            </button>
          </div>
        </div>
      </div>

      <div v-if="commitResult" class="flash result">
        已匯入 <b>{{ commitResult.imported }}</b> 筆,跳過重複 {{ commitResult.skipped_duplicates }} 筆,
        跳過錯誤 {{ commitResult.skipped_errors }} 筆,新建分類 {{ commitResult.created_categories }} 個
      </div>
    </div>

    <template v-if="preview">
      <div class="panel-body preview-summary">
        <div class="stat-grid">
          <div class="stat"><div class="stat-label">總筆數</div><div class="stat-value">{{ preview.total_rows }}</div></div>
          <div class="stat"><div class="stat-label">有效</div><div class="stat-value">{{ preview.valid_rows }}</div></div>
          <div class="stat"><div class="stat-label">重複</div><div class="stat-value">{{ duplicateCount }}</div></div>
          <div class="stat">
            <div class="stat-label">錯誤(不會匯入)</div>
            <div class="stat-value" :class="{ expense: preview.errors.length > 0 }">{{ preview.errors.length }}</div>
          </div>
          <div class="stat"><div class="stat-label">將匯入</div><div class="stat-value income">{{ finalImportCount }}</div></div>
        </div>

        <details v-if="preview.new_categories.length" class="detail-box">
          <summary>將新建 {{ preview.new_categories.length }} 個分類</summary>
          <ul><li v-for="c in preview.new_categories" :key="c">{{ c }}</li></ul>
        </details>
        <details v-if="preview.errors.length" open class="detail-box errors">
          <summary>{{ preview.errors.length }} 筆錯誤(不會匯入)</summary>
          <ul><li v-for="(e, i) in preview.errors" :key="i">{{ e }}</li></ul>
        </details>
        <p v-if="duplicateCount" class="hint">重複的資料預設跳過;勾選左側方塊可強制匯入該筆。</p>
      </div>

      <div class="table-wrap">
        <table class="grid">
          <thead>
            <tr>
              <th class="chk">強制</th>
              <th>日期</th>
              <th>類型</th>
              <th>類別</th>
              <th>項目</th>
              <th class="num">金額</th>
              <th>狀態</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="r in preview.rows"
              :key="`${r.sheet}-${r.row}`"
              :class="{ skipped: r.is_duplicate && !isForced(r) }"
            >
              <td class="chk">
                <input
                  v-if="r.is_duplicate"
                  type="checkbox"
                  :checked="isForced(r)"
                  :aria-label="`強制匯入 ${r.date} ${r.category_top}`"
                  @change="toggleForce(r)"
                />
              </td>
              <td class="nowrap">{{ r.date }}</td>
              <td><span class="badge" :class="r.type">{{ ENTRY_TYPE_LABEL[r.type] }}</span></td>
              <td>{{ r.category_top }}</td>
              <td>{{ r.item ?? '-' }}</td>
              <td class="num"><span class="amount" :class="r.type">{{ formatCurrency(r.amount) }}</span></td>
              <td>
                <span v-if="r.is_duplicate && !isForced(r)" class="pill">重複跳過</span>
                <span v-else-if="r.is_duplicate && isForced(r)" class="pill warn">強制匯入</span>
                <span v-else-if="r.will_create_category" class="pill warn">新分類</span>
                <span v-else class="pill ok">匯入</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="modal-foot">
        <button type="button" class="btn" @click="resetImport">取消</button>
        <button type="button" class="btn primary" :disabled="committing || finalImportCount === 0" @click="handleCommit">
          {{ committing ? '匯入中…' : `確認匯入 ${finalImportCount} 筆` }}
        </button>
      </div>
    </template>
  </section>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import AppIcon from './AppIcon.vue'
import { formatCurrency, ENTRY_TYPE_LABEL } from '@/utils/ledgerLabels'
import { previewImport, commitImport, exportExcel } from '@/api/importExport'
import { fetchAccounts } from '@/api/ledgerApi'
import { ACCOUNT_TYPE_LABEL } from '@/utils/ledgerLabels'
import type { ImportPreviewResponse, ImportCommitResponse } from '@/types/importExport'
import type { AccountOut } from '@/types/ledger'

const accounts = ref<AccountOut[]>([])
const selectedAccountId = ref('')
const selectedFile = ref<File | null>(null)
const preview = ref<ImportPreviewResponse | null>(null)
const commitResult = ref<ImportCommitResponse | null>(null)
const loading = ref(false)
const committing = ref(false)
const exporting = ref(false)
const exportYear = ref(new Date().getFullYear())
const forcedRows = ref<Set<string>>(new Set())
const fileInput = ref<HTMLInputElement | null>(null)
const accountsError = ref('')

const availableYears = computed(() => {
  const cur = new Date().getFullYear()
  return Array.from({ length: 5 }, (_, i) => cur - i)
})
const duplicateCount = computed(() => preview.value?.rows.filter((r) => r.is_duplicate).length ?? 0)
const finalImportCount = computed(() => {
  if (!preview.value) return 0
  return preview.value.rows.filter((r) => !r.is_duplicate || isForced(r)).length
})

fetchAccounts()
  .then((list) => {
    accounts.value = list
    if (list.length && !selectedAccountId.value) {
      selectedAccountId.value = list.find((a) => a.is_default_expense)?.id ?? list[0].id
    }
  })
  .catch(() => {
    accountsError.value = '載入帳戶失敗,請重新整理頁面'
  })

// 清空檔案欄位,否則再次選同一個檔案不會觸發 change
function clearFileInput() {
  if (fileInput.value) fileInput.value.value = ''
}

function rowKey(r: { sheet: string; row: number }) {
  return `${r.sheet}:${r.row}`
}
function isForced(r: { sheet: string; row: number }) {
  return forcedRows.value.has(rowKey(r))
}
function toggleForce(r: { sheet: string; row: number }) {
  const key = rowKey(r)
  forcedRows.value.has(key) ? forcedRows.value.delete(key) : forcedRows.value.add(key)
}

function handleFileSelect(e: Event) {
  const target = e.target as HTMLInputElement
  selectedFile.value = target.files?.[0] ?? null
  preview.value = null
  commitResult.value = null
  forcedRows.value.clear()
}

async function handlePreview() {
  if (!selectedFile.value || !selectedAccountId.value) return
  loading.value = true
  try {
    preview.value = await previewImport(selectedFile.value, selectedAccountId.value)
  } catch (err) {
    alert('預覽失敗,請確認檔案格式是否正確')
    console.error(err)
  } finally {
    loading.value = false
  }
}

async function handleCommit() {
  if (!selectedFile.value || !selectedAccountId.value) return
  if (!confirm(`確定匯入 ${finalImportCount.value} 筆交易?`)) return
  committing.value = true
  try {
    commitResult.value = await commitImport(selectedFile.value, selectedAccountId.value, [...forcedRows.value])
    preview.value = null
    selectedFile.value = null
    forcedRows.value.clear()
    clearFileInput()
  } catch (err) {
    alert('匯入失敗')
    console.error(err)
  } finally {
    committing.value = false
  }
}

function resetImport() {
  preview.value = null
  selectedFile.value = null
  forcedRows.value.clear()
  clearFileInput()
}

async function handleExport() {
  exporting.value = true
  try {
    await exportExcel(exportYear.value)
  } catch (err) {
    alert('匯出失敗')
    console.error(err)
  } finally {
    exporting.value = false
  }
}
</script>

<style scoped>
.lbl { font-size: 13px; font-weight: 700; color: var(--text-2); }
.row.nowrap { flex-wrap: nowrap; }
.file { flex: 1; min-width: 0; min-height: var(--h-btn); padding-top: 5px; }
.result { margin-top: 16px; }
.preview-summary { border-top: 1px solid var(--line-soft); }
.detail-box { margin-top: 12px; padding: 8px 12px; border: 1px solid var(--line-soft); border-radius: var(--radius-sm); background: rgb(255 255 255 / 55%); }
.detail-box summary { cursor: pointer; font-weight: 700; }
.detail-box ul { margin: 6px 0 0; padding-left: 22px; }
.detail-box.errors { border-color: var(--bad-line); background: var(--bad-soft); color: #8e1c1c; }
.preview-summary .hint { margin: 12px 0 0; }
.chk { width: 56px; text-align: center; }
tr.skipped td { opacity: 0.5; }
</style>
