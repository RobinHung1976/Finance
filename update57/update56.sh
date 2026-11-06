#!/usr/bin/env bash
# update56.sh — 前端改版 E2-1:交易紀錄頁改為 TCR 查詢/報表風格
#   - 查詢面板:日期 + 快選、類型 LED 按鍵(支出/收入)、金額區間、進階篩選(帳戶/分類/消費品項)、清除條件
#   - 交易明細:統計卡片(筆數/收入/支出/結餘/帳戶總餘額)、帳戶餘額、搜尋、可排序表格(日期/金額)
#   - 新增/編輯改為對話框(TransactionFormDialog.vue,共用同一表單)
#   - 匯出 CSV(目前畫面結果,UTF-8 BOM,防 CSV 公式注入)
# 執行位置:server 的 /root/apps(root)
set -euo pipefail

CURRENT=56
FE=ledger-frontend

# ---------- 前置驗證(不通過不寫入任何檔案) ----------
[ -d .git ] && [ -d "$FE/src" ] && [ -f deploy.sh ] \
  || { echo "❌ 請在 Finance repo 根目錄執行(需有 .git、$FE/src、deploy.sh)" >&2; exit 1; }
if ! grep -q "feature-ui-theme.md" docs/PROJECT-OVERVIEW.md; then
  echo "❌ 尚未包含 update55.sh 的改動,請先確認 update55.sh 是否已成功套用" >&2; exit 1
fi
if git ls-files --error-unmatch "$FE/src/components/TransactionFormDialog.vue" >/dev/null 2>&1; then
  echo "❌ 已套用過本次更新(TransactionFormDialog.vue 已在版控中),不需重跑" >&2; exit 1
fi
if ! git diff --quiet HEAD -- "$FE" || ! git diff --cached --quiet -- "$FE"; then
  echo "❌ $FE 有未 commit 的修改,請先處理後再執行" >&2; exit 1
fi

# 要覆寫/刪除的既有檔案,內容必須與產生腳本時看到的版本完全一致
check_sha() {
  local f="$FE/$1" want="$2" got
  [ -f "$f" ] || { echo "❌ 找不到 $f" >&2; exit 1; }
  got=$(sha256sum "$f" | cut -d' ' -f1)
  [ "$got" = "$want" ] || { echo "❌ $f 內容與預期版本不符(可能已被修改),中止" >&2; exit 1; }
}
check_sha src/styles/theme.css 67a3423dfef72d5edfadd677d968f9de0b87f16de000be66938b3ac0c5431fc9
check_sha src/components/AppIcon.vue 7b169812dd354517fbae79f1921bd4c40e9299c1ee298723b4babe274a08da27
check_sha src/components/TransactionList.vue 48f991c607147c794db44a64e2e68253db7278593c1f95b14b667d145933002f
check_sha src/views/TransactionsView.vue d752233505d169572d4a434ad9075a8b49041d6e96542ad6de8b6c6fe1b13058
echo "✅ 前置驗證通過"

# ---------- 自動歸檔 ----------
mkdir -p "update${CURRENT}"
for f in update*.sh; do
  [ "$f" = "update${CURRENT}.sh" ] && continue
  [ -f "$f" ] || continue
  git mv "$f" "update${CURRENT}/$f" 2>/dev/null || mv "$f" "update${CURRENT}/$f"
done
git add -A "update${CURRENT}" 2>/dev/null || true
if ! git diff --cached --quiet; then
  git commit -m "chore: 歸檔已執行的 updateN.sh 腳本"
fi

# ---------- 寫入檔案(整份覆寫;新檔案即使殘留也一律覆寫) ----------
mkdir -p "$FE/src/components" "$FE/src/utils"
cat > "$FE/src/components/TransactionFormDialog.vue" << '__F56_EOF__'
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
__F56_EOF__

cat > "$FE/src/utils/csv.ts" << '__F56_EOF__'
// CSV 匯出(前端產生):UTF-8 BOM 讓 Excel 正確辨識中文;每格以雙引號包住並跳脫內含雙引號。
// 文字格開頭若為 = + - @ Tab CR,前面補單引號,避免在 Excel 開啟時被當成公式執行(CSV injection)。

export type CsvCell = string | number

const FORMULA_PREFIX = /^[=+\-@\t\r]/

function escapeCell(value: CsvCell): string {
  let text = typeof value === 'number' ? String(value) : value
  if (typeof value === 'string' && FORMULA_PREFIX.test(text)) text = `'${text}`
  return `"${text.replace(/"/g, '""')}"`
}

export function toCsv(header: string[], rows: CsvCell[][]): string {
  return [header, ...rows].map((row) => row.map(escapeCell).join(',')).join('\r\n')
}

export function downloadCsv(filename: string, csv: string): void {
  const blob = new Blob(['﻿', csv], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  a.remove()
  // 延後釋放,避免部分瀏覽器在下載開始前就失效
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}
__F56_EOF__

cat > "$FE/src/styles/theme.css" << '__F56_EOF__'
/* Finance Ledger — 金屬主題：淺色拉絲鋼內容區、深色拉絲側欄、金屬面板與按鍵；品牌色為墨綠金屬 */
:root {
  color-scheme: light;
  --font: "Segoe UI", "Noto Sans TC", "Noto Sans CJK TC", "Microsoft JhengHei", "PingFang TC", system-ui, sans-serif;
  --font-mono: "Cascadia Mono", Consolas, "JetBrains Mono", ui-monospace, "Microsoft JhengHei", monospace;

  /* 拉絲紋理（細直線） */
  --brush-light: repeating-linear-gradient(90deg, rgb(255 255 255 / 16%) 0 1px, rgb(0 0 0 / 2.5%) 1px 2px, transparent 2px 4px);

  /* 金屬面（由亮到暗） */
  --metal-plate: linear-gradient(180deg, #f7f8f9 0%, #e7e9ec 55%, #dcdfe3 100%);
  --metal-key: linear-gradient(180deg, #fbfbfc 0%, #e2e5e9 48%, #cfd3d8 52%, #e3e6e9 100%);
  --metal-key-hover: linear-gradient(180deg, #ffffff 0%, #eceef1 48%, #dadde2 52%, #eceef1 100%);
  --metal-key-down: linear-gradient(180deg, #cdd1d6 0%, #dcdfe3 100%);
  --metal-dark: linear-gradient(180deg, #70757d 0%, #50545b 48%, #42464c 52%, #5a5e65 100%);
  --metal-dark-hover: linear-gradient(180deg, #7e838b 0%, #5c6068 48%, #4d5157 52%, #666a71 100%);
  /* 卡片雙色立體面：上半亮、下半暗，中間明顯分界 */
  --card-2tone: linear-gradient(180deg, #ffffff 0%, #eef0f3 49%, #d2d6db 50%, #c3c8ce 100%);
  --card-2tone-hover: linear-gradient(180deg, #ffffff 0%, #f5f6f8 49%, #dcdfe3 50%, #cfd3d8 100%);
  --card-2tone-lit: linear-gradient(180deg, #ffffff 0%, #fbfcfd 49%, #e6eaee 50%, #dce1e7 100%);

  /* 品牌：墨綠金屬（基準色 #1f5f4f，同 PWA theme_color） */
  --brand: #1f5f4f;
  --brand-metal: linear-gradient(180deg, #5fae96 0%, #2b7a64 49%, #1f5f4f 50%, #286f5c 100%);
  --brand-metal-lit: linear-gradient(180deg, #8fd0bb 0%, #3f9078 48%, #26705b 52%, #3c8a73 100%);
  --brand-edge: #123d33;
  --brand-glow: rgb(80 190 150 / 55%);
  --lamp: #ffb547;   /* 品牌列指示燈（琥珀色，在綠底上可辨識） */

  --side-text: #e4e6ea;
  --side-muted: #c3c8ce;
  --side-line: rgb(255 255 255 / 10%);

  --line: #b8bec6;
  --line-soft: #ccd1d7;
  --field-line: #a6adb6;

  --text: #1d2228;
  --text-2: #30363e;
  --muted: #555d68;

  --accent: #1f5f4f;
  --accent-hover: #17493c;
  --focus: #2f8f73;

  --ok: #1f7a3a;
  --ok-soft: #e4f3e8;
  --ok-line: #9fd0ae;
  --warn: #8a4b00;
  --warn-soft: #fbf0d6;
  --warn-line: #dfbd6e;
  --bad: #b42318;
  --bad-soft: #f9e5e3;
  --bad-line: #e6aaa4;

  --radius: 10px;
  --radius-sm: 6px;
  --bevel: inset 0 1px 0 rgb(255 255 255 / 95%), inset 0 -1px 0 rgb(0 0 0 / 8%);
  --shadow: 0 1px 1px rgb(0 0 0 / 12%), 0 4px 14px rgb(30 35 45 / 14%);
  --h-btn: 34px;
  --h-btn-sm: 28px;
}

* { box-sizing: border-box; }
html, body, #app { height: 100%; margin: 0; }
html { background: #d5d9de; }
body {
  font: 14px/1.6 var(--font);
  color: var(--text);
  background:
    var(--brush-light),
    linear-gradient(115deg, rgb(255 255 255 / 35%) 0%, transparent 35%, rgb(255 255 255 / 22%) 62%, transparent 85%),
    linear-gradient(180deg, #e8eaed 0%, #d3d7dc 100%);
  background-attachment: fixed;
  -webkit-font-smoothing: antialiased;
}
a { color: var(--accent); text-decoration: none; }
a:hover { color: var(--accent-hover); text-decoration: underline; }
button { font-family: inherit; cursor: pointer; }
:focus-visible { outline: 2px solid var(--focus); outline-offset: 2px; }

/* ---------- 圖示 ---------- */
.i {
  width: 16px; height: 16px; flex: none; vertical-align: -3px;
  fill: none; stroke: currentColor; stroke-width: 1.75; stroke-linecap: round; stroke-linejoin: round;
}

/* ---------- 版面 ---------- */
.layout { display: grid; grid-template-columns: 236px 1fr; min-height: 100vh; }
.sidebar {
  color: var(--side-text);
  background:
    repeating-linear-gradient(90deg, rgb(255 255 255 / 3%) 0 1px, rgb(0 0 0 / 7%) 1px 2px, transparent 2px 3px),
    linear-gradient(100deg, rgb(255 255 255 / 6%) 0%, transparent 40%, rgb(255 255 255 / 4%) 70%, transparent 100%),
    linear-gradient(180deg, #45484e 0%, #2c2e33 100%);
  border-right: 1px solid #1c1e21;
  box-shadow: inset -1px 0 0 rgb(255 255 255 / 8%), 4px 0 16px rgb(0 0 0 / 22%);
  display: flex; flex-direction: column;
  position: sticky; top: 0; height: 100vh; overflow-y: auto;
}
.brand {
  padding: 18px 18px 14px; background: var(--brand-metal); border-bottom: 1px solid var(--brand-edge);
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 45%), 0 2px 6px rgb(0 0 0 / 40%);
}
.brand-row { display: flex; align-items: center; gap: 10px; }
.brand-mark { display: grid; place-items: center; width: 34px; height: 34px; color: #fff; filter: drop-shadow(0 1px 1px rgb(0 0 0 / 45%)); }
.brand-mark .i { width: 30px; height: 30px; stroke-width: 1.6; }
.brand-sep { width: 1px; height: 26px; background: rgb(255 255 255 / 40%); }
.brand-name { font-weight: 700; font-size: 15px; line-height: 1.25; color: #fff; text-shadow: 0 1px 1px rgb(0 0 0 / 35%); }
.brand-name small { display: block; font-weight: 400; font-size: 10.5px; color: #dff3ec; letter-spacing: .3px; }
.brand-product {
  margin-top: 12px; font-size: 10.5px; letter-spacing: 2.4px; color: #fff; font-weight: 700; text-shadow: 0 1px 1px rgb(0 0 0 / 35%);
  display: flex; align-items: center; gap: 7px;
}
.brand-product::before { content: ""; width: 7px; height: 7px; border-radius: 50%; background: var(--lamp); box-shadow: 0 0 6px var(--lamp); }

.nav { padding: 4px 12px 16px; }
.nav-group { margin-top: 18px; }
.nav-title { padding: 0 4px 7px; font-weight: 800; font-size: 13px; letter-spacing: 1px; color: #f1f3f5; text-shadow: 0 1px 0 #000; }
/* 選單項目：金屬按鍵；目前頁面為墨綠金屬、白字 */
.nav a {
  position: relative; display: flex; align-items: center; gap: 10px;
  height: 38px; padding: 0 12px; margin: 0 0 8px; border-radius: var(--radius-sm);
  border: 1px solid #1d1f23; background: var(--metal-key); color: #1d2228;
  font-size: 14.5px; font-weight: 800; text-shadow: 0 1px 0 #fff;
  box-shadow: inset 0 1px 0 #fff, 0 1px 3px rgb(0 0 0 / 50%);
}
.nav a:hover { background: var(--metal-key-hover); color: #000; text-decoration: none; }
.nav a:active { background: var(--metal-key-down); box-shadow: inset 0 1px 3px rgb(0 0 0 / 30%); }
.nav a.active {
  background: var(--brand-metal-lit); border-color: var(--brand-edge); color: #fff; text-shadow: 0 -1px 0 rgb(0 0 0 / 45%);
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 55%), 0 0 10px var(--brand-glow), 0 1px 3px rgb(0 0 0 / 50%);
}
.nav a .i { width: 17px; height: 17px; color: #3a4048; }
.nav a:hover .i { color: #000; }
.nav a.active .i { color: #fff; }

/* 側欄：目前帳本 */
.household-nav { padding: 12px 12px 14px; border-bottom: 1px solid var(--side-line); box-shadow: 0 1px 0 rgb(0 0 0 / 30%); }
.household-current {
  display: flex; align-items: center; gap: 8px; height: 36px; padding: 0 12px; border-radius: var(--radius-sm);
  background: rgb(0 0 0 / 25%); border: 1px solid rgb(0 0 0 / 45%); box-shadow: inset 0 1px 3px rgb(0 0 0 / 40%), 0 1px 0 rgb(255 255 255 / 8%);
  color: #fff; font-weight: 800; font-size: 14px;
}
.household-current span { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.household-current .i { color: #8fe0c4; }

.side-foot {
  margin-top: auto; padding: 14px 20px 16px; font-size: 12px; color: var(--side-muted);
  border-top: 1px solid var(--side-line); box-shadow: inset 0 1px 0 rgb(0 0 0 / 30%);
  display: flex; flex-direction: column; gap: 3px;
}
.side-foot .clock { display: flex; align-items: center; gap: 6px; font-size: 12.5px; color: #fff; white-space: nowrap; }
.side-foot .clock .tz { color: #c3c8ce; }
.side-foot .clock time { font-weight: 700; font-variant-numeric: tabular-nums; }

.main { min-width: 0; display: flex; flex-direction: column; }
.topbar {
  height: 60px; background: var(--brush-light), linear-gradient(180deg, #f3f4f6 0%, #dde0e4 100%);
  border-bottom: 1px solid #a9b0b8; box-shadow: inset 0 1px 0 #fff, 0 1px 3px rgb(0 0 0 / 12%);
  display: flex; align-items: center; padding: 0 26px; gap: 12px;
  position: sticky; top: 0; z-index: 5;
}
.topbar h1 { margin: 0; font-size: 17px; font-weight: 700; letter-spacing: .3px; text-shadow: 0 1px 0 #fff; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.topbar .who { margin-left: auto; font-size: 13px; color: var(--muted); white-space: nowrap; }
.topbar .who b { color: var(--text); }
.content { padding: 24px 26px 32px; display: flex; flex-direction: column; gap: 18px; }

/* ---------- 面板：金屬板 ---------- */
.panel {
  position: relative; background: var(--brush-light), var(--metal-plate);
  border: 1px solid var(--line); border-radius: var(--radius); box-shadow: var(--bevel), var(--shadow);
}
.panel-head {
  display: flex; align-items: center; gap: 10px; flex-wrap: wrap; min-height: 52px;
  padding: 10px 20px; border-bottom: 1px solid var(--line-soft);
  background: linear-gradient(180deg, rgb(255 255 255 / 55%), rgb(255 255 255 / 0%));
  box-shadow: 0 1px 0 rgb(255 255 255 / 80%);
  border-radius: var(--radius) var(--radius) 0 0;
}
.panel-head h2 { margin: 0; font-size: 15px; font-weight: 700; display: flex; align-items: center; gap: 9px; text-shadow: 0 1px 0 #fff; }
.panel-head h2 .i { color: var(--text-2); width: 18px; height: 18px; vertical-align: 0; }
.panel-head .spacer { flex: 1; }
.panel-body { padding: 20px; }
.hint { color: var(--muted); font-size: 12.5px; font-weight: 400; }
.empty { padding: 34px 18px; text-align: center; color: var(--muted); }
.row { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }

/* ---------- 標籤 ---------- */
.pill {
  display: inline-flex; align-items: center; gap: 5px; padding: 1px 10px; border-radius: 999px;
  font-size: 12px; line-height: 1.6; border: 1px solid var(--field-line); background: var(--metal-key); color: var(--text-2);
  box-shadow: inset 0 1px 0 #fff; white-space: nowrap;
}
.pill.ok { border-color: var(--ok-line); background: var(--ok-soft); color: var(--ok); box-shadow: none; }
.pill.warn { border-color: var(--warn-line); background: var(--warn-soft); color: var(--warn); box-shadow: none; }
.pill.bad { border-color: var(--bad-line); background: var(--bad-soft); color: var(--bad); box-shadow: none; }
.household-badge {
  display: inline-flex; align-items: center; gap: 6px; height: 26px; padding: 0 11px; border-radius: var(--radius-sm);
  background: var(--brand-metal); border: 1px solid var(--brand-edge); color: #fff; font-size: 13px; font-weight: 700;
  text-shadow: 0 -1px 0 rgb(0 0 0 / 35%); box-shadow: inset 0 1px 0 rgb(255 255 255 / 45%), 0 1px 2px rgb(0 0 0 / 25%); white-space: nowrap;
}
.household-badge .i { width: 14px; height: 14px; }

/* ---------- 表格 ---------- */
.table-wrap { overflow-x: auto; }
table.grid { width: 100%; border-collapse: collapse; }
.grid th {
  text-align: left; font-weight: 700; font-size: 12.5px; color: var(--text-2); padding: 10px 16px; white-space: nowrap;
  background: var(--metal-key); border-bottom: 1px solid var(--line); box-shadow: inset 0 1px 0 #fff; text-shadow: 0 1px 0 #fff;
}
.grid td { padding: 10px 16px; border-bottom: 1px solid var(--line-soft); vertical-align: top; }
.grid tr:last-child td { border-bottom: 0; }
.grid tbody tr:hover td { background: rgb(255 255 255 / 45%); }
.grid td.num, .grid th.num { text-align: right; font-variant-numeric: tabular-nums; }
.grid .nowrap { white-space: nowrap; }

/* ---------- 表單：內凹的金屬輸入框 ---------- */
input[type=text], input[type=password], input[type=email], input[type=number], input[type=date], input[type=search], select, textarea {
  font: inherit; font-size: 14px; color: var(--text); border: 1px solid var(--field-line);
  background: linear-gradient(180deg, #e6e9ec 0%, #f6f7f8 30%, #fbfbfc 100%);
  box-shadow: inset 0 1px 3px rgb(0 0 0 / 20%), 0 1px 0 rgb(255 255 255 / 80%);
  border-radius: var(--radius-sm); padding: 0 11px; min-height: var(--h-btn);
  transition: border-color .15s, box-shadow .15s;
}
input::placeholder, textarea::placeholder { color: #7d8590; }
input[type=date] { font-weight: 700; color: #0f141a; font-variant-numeric: tabular-nums; }
input[type=date]::-webkit-calendar-picker-indicator { opacity: .85; cursor: pointer; }
textarea { min-height: 64px; padding: 7px 11px; resize: vertical; }
input:focus, select:focus, textarea:focus {
  outline: none; border-color: var(--focus);
  box-shadow: inset 0 1px 3px rgb(0 0 0 / 18%), 0 0 0 3px rgb(47 143 115 / 22%);
}
input:disabled, select:disabled, textarea:disabled { background: #dfe2e6; color: var(--muted); }
input[type=checkbox], input[type=radio] { width: 15px; height: 15px; margin: 0; accent-color: var(--brand); }

/* ---------- 按鈕：金屬按鍵 ---------- */
.btn {
  font: inherit; font-size: 13px; font-weight: 600; cursor: pointer;
  display: inline-flex; align-items: center; justify-content: center; gap: 6px;
  height: var(--h-btn); padding: 0 15px; border-radius: var(--radius-sm); border: 1px solid #959ca6;
  background: var(--metal-key); color: #22272e; text-decoration: none; white-space: nowrap; text-shadow: 0 1px 0 #fff;
  box-shadow: inset 0 1px 0 #fff, 0 1px 2px rgb(0 0 0 / 22%);
}
.btn:hover { background: var(--metal-key-hover); color: #111; text-decoration: none; }
.btn:active, .btn.on { background: var(--metal-key-down); box-shadow: inset 0 1px 3px rgb(0 0 0 / 25%); }
.btn.on { border-color: #6f7781; color: #000; }
.btn.primary {
  background: var(--metal-dark); border-color: #2c2f34; color: #fff; text-shadow: 0 -1px 0 rgb(0 0 0 / 50%);
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 28%), 0 1px 3px rgb(0 0 0 / 35%);
}
.btn.primary:hover { background: var(--metal-dark-hover); color: #fff; }
.btn.primary:active { background: linear-gradient(180deg, #44484e, #575b61); box-shadow: inset 0 2px 4px rgb(0 0 0 / 45%); }
.btn.danger { color: var(--bad); }
.btn.ghost { border-color: transparent; background: transparent; box-shadow: none; color: var(--muted); }
.btn.ghost:hover { border-color: #959ca6; background: var(--metal-key-hover); box-shadow: inset 0 1px 0 #fff, 0 1px 2px rgb(0 0 0 / 18%); color: var(--text); }
.btn.sm { height: var(--h-btn-sm); padding: 0 11px; font-size: 12.5px; }
.btn.sm .i { width: 14px; height: 14px; }
.btn:disabled, .btn:disabled:hover { opacity: .5; cursor: not-allowed; }

/* ---------- 選擇按鍵：金屬鍵 + 底部 LED 燈條（未選取為內凹灰條、選取後亮綠發光） ---------- */
.keypad { display: flex; flex-wrap: wrap; gap: 12px; padding: 3px 2px 6px; }
.key {
  position: relative; display: inline-flex; align-items: center; gap: 8px; height: 40px; padding: 0 16px 7px;
  border: 1px solid #8e96a0; border-radius: 8px; background: var(--card-2tone); color: #3a4048;
  font: inherit; font-weight: 700; font-size: 14px; text-shadow: 0 1px 0 #fff; cursor: pointer; user-select: none;
  box-shadow: inset 0 1px 0 #fff, 0 0 0 2px rgb(255 255 255 / 55%), 0 2px 4px rgb(0 0 0 / 22%);
  transition: box-shadow .15s, background .15s, color .15s, transform .08s;
}
.key:hover { background: var(--card-2tone-hover); }
.key:active { transform: translateY(1px); }
.key .i { width: 18px; height: 18px; stroke-width: 2; }
.key::after {
  content: ""; position: absolute; left: 12px; right: 12px; bottom: 4px; height: 4px; border-radius: 3px;
  background: #b4bac2; box-shadow: inset 0 1px 1px rgb(0 0 0 / 30%), 0 1px 0 rgb(255 255 255 / 70%);
  transition: background .15s, box-shadow .15s;
}
.key.active {
  background: var(--card-2tone-lit); color: #15191e; border-color: #6f7781;
  box-shadow: inset 0 1px 0 #fff, 0 0 0 2px #fff, 0 0 12px 3px rgb(255 255 255 / 95%), 0 2px 5px rgb(0 0 0 / 25%);
}
.key.active::after { background: #22c55e; box-shadow: 0 0 6px 1px rgb(34 197 94 / 90%), inset 0 1px 0 rgb(255 255 255 / 55%); }

/* ---------- 查詢表單：欄位格線（標籤在上） ---------- */
.form-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 16px 20px; }
.form-field { display: flex; flex-direction: column; gap: 7px; min-width: 0; }
.form-field.wide { grid-column: 1 / -1; }
.form-field.span2 { grid-column: span 2; }
.form-field > label, .form-field > .label { font-size: 13px; font-weight: 700; color: var(--text-2); text-shadow: 0 1px 0 rgb(255 255 255 / 70%); }
.form-field input, .form-field select { width: 100%; }
.form-field input[type=date] { font-size: 15px; min-height: 38px; }
.form-field .hint { font-weight: 400; }

/* ---------- 統計卡片（報表摘要） ---------- */
.stat-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(170px, 1fr)); gap: 12px; }
.stat {
  padding: 10px 14px 12px; border-radius: 8px; border: 1px solid #a9b0b8;
  background: var(--brush-light), linear-gradient(180deg, #ffffff 0%, #eef0f3 55%, #e2e5e9 100%);
  box-shadow: inset 0 1px 0 #fff, 0 1px 3px rgb(0 0 0 / 18%);
}
.stat-label { font-size: 12.5px; color: var(--muted); }
.stat-value { font-size: 22px; font-weight: 800; line-height: 1.3; font-variant-numeric: tabular-nums; white-space: nowrap; }
.stat-value.income { color: var(--ok); }
.stat-value.expense { color: var(--bad); }

/* ---------- 實心標籤（類型） ---------- */
.badge {
  display: inline-flex; align-items: center; gap: 4px; padding: 1px 10px; border-radius: var(--radius-sm);
  font-size: 12.5px; line-height: 1.6; font-weight: 700; color: #fff; white-space: nowrap;
  border: 1px solid rgb(0 0 0 / 18%); text-shadow: 0 1px 0 rgb(0 0 0 / 25%); box-shadow: inset 0 1px 0 rgb(255 255 255 / 25%);
}
.badge.income { background: linear-gradient(180deg, #2fae68 0%, #1f8a4c 100%); }
.badge.expense { background: linear-gradient(180deg, #d9532f 0%, #b8391a 100%); }
.chip {
  display: inline-block; padding: 0 8px; margin: 1px 4px 1px 0; border-radius: 999px; font-size: 12px; line-height: 1.7;
  background: #fef3c7; color: #8a4b00; border: 1px solid #f1d58a; white-space: nowrap;
}
.amount { font-weight: 800; font-variant-numeric: tabular-nums; white-space: nowrap; }
.amount.income { color: var(--ok); }
.amount.expense { color: var(--bad); }

/* ---------- 表格：工具列、排序表頭 ---------- */
.toolbar { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; padding: 12px 16px; border-bottom: 1px solid var(--line-soft); }
.toolbar .spacer { flex: 1; }
.toolbar input[type=search] { width: 260px; }
.grid th.sortable { cursor: pointer; user-select: none; color: var(--accent); }
.grid th.sortable:hover { color: var(--accent-hover); }
.grid tbody tr:nth-child(even) td { background: rgb(255 255 255 / 28%); }
.grid td.actions { white-space: nowrap; text-align: right; }
.grid td.actions .btn + .btn { margin-left: 6px; }

/* ---------- 對話框（原生 <dialog>） ---------- */
dialog.modal {
  width: min(640px, calc(100vw - 32px)); max-height: calc(100vh - 48px); padding: 0; overflow: auto;
  border: 1px solid var(--line); border-radius: var(--radius); color: var(--text);
  background: var(--brush-light), var(--metal-plate); box-shadow: var(--bevel), 0 24px 60px rgb(20 25 35 / 40%);
}
dialog.modal::backdrop { background: rgb(20 24 30 / 45%); backdrop-filter: blur(1px); }
dialog.modal .panel-head { position: sticky; top: 0; z-index: 1; background: linear-gradient(180deg, #fbfbfc, #eceef1); }
.modal-foot { display: flex; justify-content: flex-end; gap: 10px; padding: 14px 20px; border-top: 1px solid var(--line-soft); }

/* ---------- 訊息 ---------- */
.flash { border-radius: var(--radius); padding: 10px 16px; border: 1px solid var(--ok-line); background: var(--ok-soft); color: #14532d; box-shadow: var(--bevel); }
.flash.error { border-color: var(--bad-line); background: var(--bad-soft); color: #8e1c1c; }
.notice { border: 1px dashed var(--field-line); background: rgb(255 255 255 / 55%); border-radius: var(--radius); padding: 12px 16px; }
[hidden] { display: none !important; }

/* ---------- 窄螢幕：只做最基本的上下堆疊（完整手機版另案處理） ---------- */
@media (max-width: 860px) {
  .layout { grid-template-columns: 1fr; }
  .sidebar { position: static; height: auto; }
  .topbar { position: static; padding: 0 14px; }
  .content { padding: 14px; }
  .topbar .who { display: none; }
}
@media (prefers-reduced-motion: reduce) {
  .key, input, select, textarea { transition: none; }
}
__F56_EOF__

cat > "$FE/src/components/AppIcon.vue" << '__F56_EOF__'
<script setup lang="ts">
// 線條圖示（24x24、stroke 繪製，裝飾用，螢幕閱讀器略過）
export type IconName =
  | 'book' | 'chart' | 'receipt' | 'wallet' | 'folder' | 'tag' | 'transfer'
  | 'users' | 'history' | 'logout' | 'clock' | 'trend' | 'pie' | 'ranking' | 'calendar'
  | 'income' | 'expense' | 'plus' | 'edit' | 'trash' | 'download' | 'search' | 'filter' | 'x' | 'table'

const PATHS: Record<IconName, string> = {
  book: '<path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1 0-5H20"/><path d="M9 7h7M9 11h5"/>',
  chart: '<path d="M3 3v18h18"/><path d="M7 16v-4M12 16V8M17 16v-7"/>',
  receipt: '<path d="M5 3h14v18l-3-2-2 2-2-2-2 2-2-2-3 2z"/><path d="M9 8h6M9 12h6M9 16h3"/>',
  wallet: '<path d="M19 7V5a2 2 0 0 0-2-2H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-4a2 2 0 0 0 0 4h4v3a1 1 0 0 1-1 1H5a2 2 0 0 1-2-2V5"/>',
  folder: '<path d="M4 20h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-8l-2-3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2z"/><path d="M8 13h8"/>',
  tag: '<path d="M12.6 2.6A2 2 0 0 0 11.2 2H4a2 2 0 0 0-2 2v7.2a2 2 0 0 0 .6 1.4l8.7 8.7a2.4 2.4 0 0 0 3.4 0l6.6-6.6a2.4 2.4 0 0 0 0-3.4z"/><circle cx="7.5" cy="7.5" r="1.5"/>',
  transfer: '<path d="m3 16 4 4 4-4"/><path d="M7 20V4"/><path d="m21 8-4-4-4 4"/><path d="M17 4v16"/>',
  users: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
  history: '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/><path d="M12 7v5l3.5 2"/>',
  logout: '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="m16 17 5-5-5-5"/><path d="M21 12H9"/>',
  clock: '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
  trend: '<path d="m22 7-8.5 8.5-5-5L2 17"/><path d="M16 7h6v6"/>',
  pie: '<path d="M21.2 15.9A10 10 0 1 1 8 2.8"/><path d="M22 12A10 10 0 0 0 12 2v10z"/>',
  ranking: '<path d="M10 6h11M10 12h11M10 18h11"/><path d="M4 6h1v4M4 10h2"/><path d="M6 18H4c0-1 2-2 2-3s-1-1.5-2-1"/>',
  calendar: '<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
  income: '<path d="M17 7 7 17"/><path d="M17 17H7V7"/>',
  expense: '<path d="M7 17 17 7"/><path d="M7 7h10v10"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  edit: '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/>',
  trash: '<path d="M3 6h18"/><path d="M8 6V4h8v2"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6M14 11v6"/>',
  download: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="m7 10 5 5 5-5"/><path d="M12 15V3"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/>',
  filter: '<path d="M22 3H2l8 9.46V19l4 2v-8.54z"/>',
  x: '<path d="M18 6 6 18M6 6l12 12"/>',
  table: '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M3 15h18M9 3v18"/>',
}

defineProps<{ name: IconName }>()
</script>

<template>
  <!-- PATHS 為本檔內的固定常數，不含任何使用者輸入，v-html 無 XSS 風險 -->
  <svg class="i" viewBox="0 0 24 24" aria-hidden="true" focusable="false" v-html="PATHS[name]"></svg>
</template>
__F56_EOF__

cat > "$FE/src/components/TransactionList.vue" << '__F56_EOF__'
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
.ic-expense { color: #b8391a; }
.ic-income { color: #1f8a4c; }
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
__F56_EOF__

cat > "$FE/src/views/TransactionsView.vue" << '__F56_EOF__'
<script setup lang="ts">
import TransactionList from '@/components/TransactionList.vue'
</script>

<template>
  <!-- TransactionList 自帶「交易查詢」「交易明細」兩個面板 -->
  <TransactionList />
</template>
__F56_EOF__


# ---------- 驗證建置(失敗則還原前端改動,不 commit) ----------
echo "▶ npm install && npm run build(vue-tsc 型別檢查 + vite build)"
if ! ( cd "$FE" && npm install --no-audit --no-fund && npm run build ); then
  echo "❌ 建置失敗,還原本次前端改動" >&2
  git checkout HEAD -- "$FE/src"
  git clean -fdq -- "$FE/src"
  exit 1
fi

git add -A "$FE/src"
git commit -m "feat: 交易紀錄頁改為查詢面板 + 報表表格(統計卡片、排序、搜尋、匯出 CSV),新增/編輯改對話框"

echo
git log --oneline -3
echo
git diff HEAD~1 --stat | tail -n 30
echo
echo "✅ 完成。確認無誤後:git push origin main && ./deploy.sh,瀏覽器 Ctrl+Shift+R"
