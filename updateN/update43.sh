#!/usr/bin/env bash
set -euo pipefail

# ---------- 0. 自動歸檔:把非本次腳本的 updateM.sh 搬進 updateN/ ----------
mkdir -p updateN
CURRENT=43
for f in update*.sh; do
  [ "$f" = "update${CURRENT}.sh" ] && continue
  [ -f "$f" ] || continue
  git mv "$f" "updateN/$f" 2>/dev/null || mv "$f" "updateN/$f"
done
git add -A
if ! git diff --cached --quiet; then
  git commit -m "chore: 歸檔已執行的 updateN.sh 腳本"
  echo "✅ 歸檔 commit 已產生(與本次功能改動分開)"
fi

BACKEND=ledger-backend
FRONTEND=ledger-frontend
[ -d "$BACKEND" ] && [ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

# ============================================================
# 1. api/ledger.ts -> api/ledgerApi.ts(改名 + 全專案 import 路徑更新)
# ============================================================
if [ -f "$FRONTEND/src/api/ledger.ts" ]; then
  git mv "$FRONTEND/src/api/ledger.ts" "$FRONTEND/src/api/ledgerApi.ts"
  echo "✅ api/ledger.ts 已改名為 api/ledgerApi.ts"
else
  echo "⚠️  找不到 $FRONTEND/src/api/ledger.ts,可能已改過名,跳過改名步驟"
fi

python3 << 'PYEOF'
import subprocess

root = "ledger-frontend/src"

def find_files(pattern):
    r = subprocess.run(["grep", "-rl", pattern, root], capture_output=True, text=True)
    return set(r.stdout.splitlines())

files = find_files("@/api/ledger'") | find_files('@/api/ledger"')

changed = 0
for path in files:
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    new_content = content.replace("@/api/ledger'", "@/api/ledgerApi'").replace('@/api/ledger"', '@/api/ledgerApi"')
    if new_content != content:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_content)
        changed += 1
        print(f"✅ 已更新 import 路徑: {path}")

print(f"共更新 {changed} 個檔案的 import 路徑")
PYEOF

if grep -rn "@/api/ledger'" ledger-frontend/src || grep -rn '@/api/ledger"' ledger-frontend/src; then
  echo "❌ 仍有殘留的 @/api/ledger 舊 import 路徑,上方已列出,請人工檢查後重跑" >&2
  exit 1
fi
echo "✅ 確認全專案已無殘留的舊 @/api/ledger import 路徑"

# ============================================================
# 2. 後端:GET /transactions 加入 tag_ids 篩選
# ============================================================
python3 << 'PYEOF'
path = "ledger-backend/app/routers/transactions.py"
with open(path, encoding="utf-8") as f:
    content = f.read()

old_sig = '''@router.get("", response_model=list[TransactionOut])
def list_transactions(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    account_id: str | None = Query(default=None),
    category_id: str | None = Query(default=None),
    min_amount: float | None = Query(default=None, ge=0),
    max_amount: float | None = Query(default=None, ge=0),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):'''
new_sig = '''@router.get("", response_model=list[TransactionOut])
def list_transactions(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    account_id: str | None = Query(default=None),
    category_id: str | None = Query(default=None),
    min_amount: float | None = Query(default=None, ge=0),
    max_amount: float | None = Query(default=None, ge=0),
    tag_ids: list[str] | None = Query(default=None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):'''
if old_sig not in content:
    raise SystemExit("❌ list_transactions 函式簽名不符,請人工確認 transactions.py 內容")
content = content.replace(old_sig, new_sig)

old_block = '''    if max_amount is not None:
        query = query.filter(Transaction.amount <= max_amount)

    return query.order_by(Transaction.date.desc()).all()'''
new_block = '''    if max_amount is not None:
        query = query.filter(Transaction.amount <= max_amount)
    if tag_ids:
        query = (
            query.join(TransactionTag, TransactionTag.transaction_id == Transaction.id)
            .filter(TransactionTag.tag_id.in_(set(tag_ids)))
            .distinct()
        )

    return query.order_by(Transaction.date.desc()).all()'''
if old_block not in content:
    raise SystemExit("❌ list_transactions 篩選區塊不符,請人工確認 transactions.py 內容")
content = content.replace(old_block, new_block)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("✅ transactions.py 已加入 tag_ids 篩選(OR 語意 + distinct 避免重複列)")
PYEOF

# ============================================================
# 3. 前端型別:TransactionFilters 加入 tag_ids
# ============================================================
python3 << 'PYEOF'
path = "ledger-frontend/src/types/ledger.ts"
with open(path, encoding="utf-8") as f:
    content = f.read()

old = '''export interface TransactionFilters {
  start_date?: string
  end_date?: string
  account_id?: string
  category_id?: string
  min_amount?: number
  max_amount?: number
}'''
new = '''export interface TransactionFilters {
  start_date?: string
  end_date?: string
  account_id?: string
  category_id?: string
  min_amount?: number
  max_amount?: number
  tag_ids?: string[]
}'''
if old not in content:
    raise SystemExit("❌ TransactionFilters 內容不符,請人工確認 types/ledger.ts")
content = content.replace(old, new)
with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("✅ types/ledger.ts 已加入 tag_ids")
PYEOF

# ============================================================
# 4. api/ledgerApi.ts:fetchTransactions 改用 URLSearchParams
# ============================================================
python3 << 'PYEOF'
path = "ledger-frontend/src/api/ledgerApi.ts"
with open(path, encoding="utf-8") as f:
    content = f.read()

old = '''export function fetchTransactions(filters: TransactionFilters = {}) {
  return apiClient.get<TransactionOut[]>('/transactions', { params: filters }).then((r) => r.data)
}'''
new = '''export function fetchTransactions(filters: TransactionFilters = {}) {
  const { tag_ids, ...rest } = filters
  const params = new URLSearchParams()
  Object.entries(rest).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      params.append(key, String(value))
    }
  })
  if (tag_ids) {
    tag_ids.forEach((id) => params.append('tag_ids', id))
  }
  return apiClient.get<TransactionOut[]>('/transactions', { params }).then((r) => r.data)
}'''
if old not in content:
    raise SystemExit("❌ fetchTransactions 內容不符,請人工確認 api/ledgerApi.ts")
content = content.replace(old, new)
with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("✅ api/ledgerApi.ts 的 fetchTransactions 已改用 URLSearchParams 正確序列化 tag_ids")
PYEOF

# ============================================================
# 5. TagFilterPicker.vue(可能是上次殘留的孤兒檔案,直接覆寫確保內容一致)
# ============================================================
mkdir -p "$FRONTEND/src/components"
cat > "$FRONTEND/src/components/TagFilterPicker.vue" << 'EOF'
<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import type { TagOut } from '@/types/ledger'

const props = defineProps<{
  tags: TagOut[]
  modelValue: string[]
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string[]] }>()

const rootEl = ref<HTMLElement | null>(null)
const isOpen = ref(false)
const searchQuery = ref('')

const selectedLabel = computed(() => {
  if (props.modelValue.length === 0) return '所有品項'
  const names = props.modelValue
    .map((id) => props.tags.find((t) => t.id === id)?.name)
    .filter((n): n is string => !!n)
  if (names.length === 0) return '所有品項'
  if (names.length <= 2) return names.join('、')
  return `已選 ${names.length} 項`
})

const filteredTags = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  const list = q ? props.tags.filter((t) => t.name.toLowerCase().includes(q)) : props.tags
  return [...list].sort((a, b) => a.name.localeCompare(b.name)).slice(0, 50)
})

function isSelected(id: string) {
  return props.modelValue.includes(id)
}
function toggleTag(id: string) {
  const next = isSelected(id) ? props.modelValue.filter((v) => v !== id) : [...props.modelValue, id]
  emit('update:modelValue', next)
}
function toggleOpen() {
  isOpen.value = !isOpen.value
  if (isOpen.value) searchQuery.value = ''
}
function clearSelection() {
  emit('update:modelValue', [])
}

function handleOutsideClick(e: MouseEvent) {
  if (rootEl.value && !rootEl.value.contains(e.target as Node)) {
    isOpen.value = false
  }
}
onMounted(() => document.addEventListener('click', handleOutsideClick))
onBeforeUnmount(() => document.removeEventListener('click', handleOutsideClick))
</script>

<template>
  <div ref="rootEl" class="tag-filter-picker">
    <button type="button" class="filter-input picker-trigger" @click="toggleOpen">
      {{ selectedLabel }}
    </button>
    <div v-if="isOpen" class="dropdown-panel">
      <input v-model="searchQuery" type="text" class="search-input" placeholder="搜尋消費品項…" autofocus />
      <div class="result-list">
        <button type="button" class="result-item" :class="{ selected: modelValue.length === 0 }" @click="clearSelection">
          所有品項
        </button>
        <button
          v-for="t in filteredTags"
          :key="t.id"
          type="button"
          class="result-item"
          :class="{ selected: isSelected(t.id) }"
          @click="toggleTag(t.id)"
        >
          <span>{{ t.name }}</span>
          <span v-if="isSelected(t.id)" class="check-mark">✓</span>
        </button>
        <p v-if="filteredTags.length === 0" class="no-result">沒有符合的消費品項</p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.tag-filter-picker {
  position: relative;
}
.picker-trigger {
  cursor: pointer;
  text-align: left;
  min-width: 140px;
  max-width: 220px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.dropdown-panel {
  position: absolute;
  top: calc(100% + 4px);
  left: 0;
  z-index: 20;
  width: 260px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  padding: 8px;
}
.search-input {
  width: 100%;
  padding: 6px 10px;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  font-size: 13px;
  margin-bottom: 6px;
  box-sizing: border-box;
}
.result-list {
  max-height: 280px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.result-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  text-align: left;
  background: none;
  border: none;
  padding: 6px 8px;
  font-size: 13px;
  cursor: pointer;
  border-radius: 6px;
}
.result-item:hover {
  background: var(--color-bg);
}
.result-item.selected {
  color: var(--color-primary);
  font-weight: 600;
}
.check-mark {
  color: var(--color-primary);
  font-weight: 700;
}
.no-result {
  font-size: 12px;
  color: #6b7a74;
  padding: 6px 8px;
  margin: 0;
}
</style>
EOF
echo "✅ components/TagFilterPicker.vue 已寫入(覆寫確保內容一致)"

# ============================================================
# 6. AccountFilterPicker.vue(同上,覆寫確保內容一致)
# ============================================================
cat > "$FRONTEND/src/components/AccountFilterPicker.vue" << 'EOF'
<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import type { AccountOut } from '@/types/ledger'

const props = defineProps<{
  accounts: AccountOut[]
  modelValue: string
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

const rootEl = ref<HTMLElement | null>(null)
const isOpen = ref(false)
const searchQuery = ref('')

const selectedLabel = computed(() => {
  if (!props.modelValue) return '所有帳戶'
  return props.accounts.find((a) => a.id === props.modelValue)?.name ?? '所有帳戶'
})

const filteredAccounts = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  const list = q ? props.accounts.filter((a) => a.name.toLowerCase().includes(q)) : props.accounts
  return [...list].sort((a, b) => a.name.localeCompare(b.name))
})

function toggleOpen() {
  isOpen.value = !isOpen.value
  if (isOpen.value) searchQuery.value = ''
}
function selectAccount(id: string) {
  emit('update:modelValue', id)
  isOpen.value = false
}
function clearSelection() {
  emit('update:modelValue', '')
  isOpen.value = false
}

function handleOutsideClick(e: MouseEvent) {
  if (rootEl.value && !rootEl.value.contains(e.target as Node)) {
    isOpen.value = false
  }
}
onMounted(() => document.addEventListener('click', handleOutsideClick))
onBeforeUnmount(() => document.removeEventListener('click', handleOutsideClick))
</script>

<template>
  <div ref="rootEl" class="account-filter-picker">
    <button type="button" class="filter-input picker-trigger" @click="toggleOpen">
      {{ selectedLabel }}
    </button>
    <div v-if="isOpen" class="dropdown-panel">
      <input v-model="searchQuery" type="text" class="search-input" placeholder="搜尋帳戶…" autofocus />
      <div class="result-list">
        <button type="button" class="result-item" :class="{ selected: !modelValue }" @click="clearSelection">
          所有帳戶
        </button>
        <button
          v-for="a in filteredAccounts"
          :key="a.id"
          type="button"
          class="result-item"
          :class="{ selected: a.id === modelValue }"
          @click="selectAccount(a.id)"
        >
          {{ a.name }}
        </button>
        <p v-if="filteredAccounts.length === 0" class="no-result">沒有符合的帳戶</p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.account-filter-picker {
  position: relative;
}
.picker-trigger {
  cursor: pointer;
  text-align: left;
  min-width: 120px;
  max-width: 200px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.dropdown-panel {
  position: absolute;
  top: calc(100% + 4px);
  left: 0;
  z-index: 20;
  width: 220px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  padding: 8px;
}
.search-input {
  width: 100%;
  padding: 6px 10px;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  font-size: 13px;
  margin-bottom: 6px;
  box-sizing: border-box;
}
.result-list {
  max-height: 240px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.result-item {
  text-align: left;
  background: none;
  border: none;
  padding: 6px 8px;
  font-size: 13px;
  cursor: pointer;
  border-radius: 6px;
}
.result-item:hover {
  background: var(--color-bg);
}
.result-item.selected {
  color: var(--color-primary);
  font-weight: 600;
}
.no-result {
  font-size: 12px;
  color: #6b7a74;
  padding: 6px 8px;
  margin: 0;
}
</style>
EOF
echo "✅ components/AccountFilterPicker.vue 已寫入(覆寫確保內容一致)"

# ============================================================
# 7. TransactionList.vue:接上新元件、新增 tag_ids 篩選狀態
#    【本次修正重點】import 這段的比對字串改成「第 1 步執行完之後」的狀態
#    (第 1 步已經把 '@/api/ledger' 改成 '@/api/ledgerApi',所以這裡不能再假設是舊路徑,
#     這正是 update42.sh 卡住的根本原因)
# ============================================================
python3 << 'PYEOF'
path = "ledger-frontend/src/components/TransactionList.vue"
with open(path, encoding="utf-8") as f:
    content = f.read()

replacements = [
    (
        "import CategoryPicker from './CategoryPicker.vue'\n"
        "import CategoryFilterPicker from './CategoryFilterPicker.vue'\n"
        "import TagPicker from './TagPicker.vue'\n"
        "import { fetchAccounts, fetchCategories, fetchTags, fetchTransactions, createTransaction, updateTransaction, deleteTransaction } from '@/api/ledgerApi'",
        "import CategoryPicker from './CategoryPicker.vue'\n"
        "import CategoryFilterPicker from './CategoryFilterPicker.vue'\n"
        "import AccountFilterPicker from './AccountFilterPicker.vue'\n"
        "import TagPicker from './TagPicker.vue'\n"
        "import TagFilterPicker from './TagFilterPicker.vue'\n"
        "import { fetchAccounts, fetchCategories, fetchTags, fetchTransactions, createTransaction, updateTransaction, deleteTransaction } from '@/api/ledgerApi'",
    ),
    (
        "const filterAccountId = ref('')\n"
        "const filterCategoryId = ref('')\n"
        "const filterMinAmount = ref<number | null>(null)\n"
        "const filterMaxAmount = ref<number | null>(null)",
        "const filterAccountId = ref('')\n"
        "const filterCategoryId = ref('')\n"
        "const filterTagIds = ref<string[]>([])\n"
        "const filterMinAmount = ref<number | null>(null)\n"
        "const filterMaxAmount = ref<number | null>(null)",
    ),
    (
        "    transactions.value = await fetchTransactions({\n"
        "      start_date: filterStartDate.value || undefined,\n"
        "      end_date: filterEndDate.value || undefined,\n"
        "      account_id: filterAccountId.value || undefined,\n"
        "      category_id: filterCategoryId.value || undefined,\n"
        "      min_amount: filterMinAmount.value ?? undefined,\n"
        "      max_amount: filterMaxAmount.value ?? undefined,\n"
        "    })",
        "    transactions.value = await fetchTransactions({\n"
        "      start_date: filterStartDate.value || undefined,\n"
        "      end_date: filterEndDate.value || undefined,\n"
        "      account_id: filterAccountId.value || undefined,\n"
        "      category_id: filterCategoryId.value || undefined,\n"
        "      tag_ids: filterTagIds.value.length ? filterTagIds.value : undefined,\n"
        "      min_amount: filterMinAmount.value ?? undefined,\n"
        "      max_amount: filterMaxAmount.value ?? undefined,\n"
        "    })",
    ),
    (
        "watch(\n"
        "  [filterStartDate, filterEndDate, filterAccountId, filterCategoryId, filterMinAmount, filterMaxAmount],\n"
        "  loadTransactions\n"
        ")",
        "watch(\n"
        "  [filterStartDate, filterEndDate, filterAccountId, filterCategoryId, filterTagIds, filterMinAmount, filterMaxAmount],\n"
        "  loadTransactions\n"
        ")",
    ),
    (
        "      <select v-model=\"filterAccountId\" class=\"filter-input\">\n"
        "        <option value=\"\">所有帳戶</option>\n"
        "        <option v-for=\"a in accounts\" :key=\"a.id\" :value=\"a.id\">{{ a.name }}</option>\n"
        "      </select>\n"
        "      <CategoryFilterPicker v-model=\"filterCategoryId\" :categories=\"categories\" />",
        "      <AccountFilterPicker v-model=\"filterAccountId\" :accounts=\"accounts\" />\n"
        "      <CategoryFilterPicker v-model=\"filterCategoryId\" :categories=\"categories\" />\n"
        "      <TagFilterPicker v-model=\"filterTagIds\" :tags=\"tags\" />",
    ),
]

for old, new in replacements:
    if old not in content:
        raise SystemExit(f"❌ 內容不符,請人工檢查以下片段是否存在:\n{old[:80]}...")
    content = content.replace(old, new)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("✅ TransactionList.vue 已接上 AccountFilterPicker / TagFilterPicker")
PYEOF

echo "✅ 檔案異動完成,commit..."
git add -A
git commit -m "feat: 交易紀錄新增消費品項篩選,帳戶/分類篩選改為按鈕式搜尋,api/ledger.ts 改名為 ledgerApi.ts"
echo "---- 確認 commit 是否真的產生(務必檢查下面這行是不是新的 commit) ----"
git log --oneline -1
git status
echo "✅ 若上方 git log 顯示的是本次 feat commit、git status 顯示 clean,才代表成功"
echo "接下來請執行:git push origin main,再到 server 跑 ./deploy.sh"
