<template>
  <div class="import-export">
    <section class="export-section">
      <h3>匯出 Excel</h3>
      <select v-model.number="exportYear">
        <option v-for="y in availableYears" :key="y" :value="y">{{ y }}</option>
      </select>
      <button @click="handleExport" :disabled="exporting">
        {{ exporting ? '匯出中...' : '下載 Excel' }}
      </button>
    </section>

    <section class="import-section">
      <h3>匯入 Excel</h3>
      <label>
        目標帳戶
        <select v-model="selectedAccountId">
          <option v-for="acc in accounts" :key="acc.id" :value="acc.id">
            {{ acc.name }}{{ acc.is_default_expense ? '（預設）' : '' }} - {{ ACCOUNT_TYPE_LABEL[acc.type] }}
          </option>
        </select>
      </label>
      <input type="file" accept=".xlsx" @change="handleFileSelect" ref="fileInput" />

      <button
        v-if="selectedFile && !preview"
        @click="handlePreview"
        :disabled="!selectedAccountId || loading"
      >
        {{ loading ? '解析中...' : '預覽' }}
      </button>

      <div v-if="preview" class="preview-result">
        <p>
          共 {{ preview.total_rows }} 筆,有效 {{ preview.valid_rows }} 筆,
          重複 {{ duplicateCount }} 筆,錯誤 {{ preview.errors.length }} 筆
        </p>

        <details v-if="preview.new_categories.length">
          <summary>將新建 {{ preview.new_categories.length }} 個分類</summary>
          <ul><li v-for="c in preview.new_categories" :key="c">{{ c }}</li></ul>
        </details>

        <details v-if="preview.errors.length" open>
          <summary class="error-summary">{{ preview.errors.length }} 筆錯誤(不會匯入)</summary>
          <ul><li v-for="(e, i) in preview.errors" :key="i" class="error-line">{{ e }}</li></ul>
        </details>

        <table class="preview-table">
          <thead>
            <tr><th></th><th>日期</th><th>類別</th><th>項目</th><th>金額</th><th>狀態</th></tr>
          </thead>
          <tbody>
            <tr
              v-for="r in preview.rows"
              :key="`${r.sheet}-${r.row}`"
              :class="{ duplicate: r.is_duplicate && !isForced(r), 'new-cat': r.will_create_category }"
            >
              <td>
                <input
                  v-if="r.is_duplicate"
                  type="checkbox"
                  :checked="isForced(r)"
                  @change="toggleForce(r)"
                  title="仍要匯入這筆"
                />
              </td>
              <td>{{ r.date }}</td>
              <td>{{ r.category_top }}</td>
              <td>{{ r.item ?? '-' }}</td>
              <td>{{ r.amount.toLocaleString() }}</td>
              <td>
                <span v-if="r.is_duplicate && !isForced(r)" class="tag tag-dup">重複跳過</span>
                <span v-else-if="r.is_duplicate && isForced(r)" class="tag tag-forced">強制匯入</span>
                <span v-else-if="r.will_create_category" class="tag tag-new">新分類</span>
                <span v-else class="tag tag-ok">匯入</span>
              </td>
            </tr>
          </tbody>
        </table>

        <div class="actions">
          <button @click="handleCommit" :disabled="committing">
            {{ committing ? '匯入中...' : `確認匯入 ${finalImportCount} 筆` }}
          </button>
          <button @click="resetImport">取消</button>
        </div>
      </div>

      <div v-if="commitResult" class="commit-result">
        ✅ 已匯入 {{ commitResult.imported }} 筆,
        跳過重複 {{ commitResult.skipped_duplicates }} 筆,
        跳過錯誤 {{ commitResult.skipped_errors }} 筆,
        新建分類 {{ commitResult.created_categories }} 個
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { previewImport, commitImport, exportExcel } from '@/api/importExport'
import { fetchAccounts } from '@/api/ledger'
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

const availableYears = computed(() => {
  const cur = new Date().getFullYear()
  return Array.from({ length: 5 }, (_, i) => cur - i)
})
const duplicateCount = computed(() => preview.value?.rows.filter((r) => r.is_duplicate).length ?? 0)
const finalImportCount = computed(() => {
  if (!preview.value) return 0
  return preview.value.rows.filter((r) => !r.is_duplicate || isForced(r)).length
})

fetchAccounts().then((list) => {
  accounts.value = list
  if (list.length && !selectedAccountId.value) {
    selectedAccountId.value = list.find((a) => a.is_default_expense)?.id ?? list[0].id
  }
})

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
.duplicate { opacity: 0.5; }
.new-cat { background: #fffbe6; }
.tag { padding: 2px 6px; border-radius: 4px; font-size: 12px; }
.tag-dup { background: #f0f0f0; color: #999; }
.tag-forced { background: #d1e7ff; color: #084298; }
.tag-new { background: #fff3cd; color: #856404; }
.tag-ok { background: #d4edda; color: #155724; }
.error-summary { color: #d32f2f; cursor: pointer; }
.error-line { color: #d32f2f; }
.preview-table { width: 100%; border-collapse: collapse; margin: 12px 0; }
.preview-table th, .preview-table td { padding: 4px 8px; border-bottom: 1px solid #eee; text-align: left; }
.actions { display: flex; gap: 8px; margin-top: 12px; }
</style>
