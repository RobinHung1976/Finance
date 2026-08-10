#!/usr/bin/env bash
set -euo pipefail

# ========================================
# update51.sh
# 前端:A9 最大單筆排行 —— types/ledger.ts、api/ledgerApi.ts、
#      新元件 components/TopTransactionsList.vue、串進 DashboardView.vue 第四個統計子分頁
# ========================================

# ---- 0. 自動歸檔 ----
CURRENT=51
mkdir -p "update${CURRENT}"
for f in update*.sh; do
  [ "$f" = "update${CURRENT}.sh" ] && continue
  [ -f "$f" ] || continue
  git mv "$f" "update${CURRENT}/$f" 2>/dev/null || mv "$f" "update${CURRENT}/$f"
done
git add -A
if ! git diff --cached --quiet; then
  git commit -m "chore: 歸檔已執行的 updateN.sh 腳本"
fi

# ---- 1. 前置驗證:確認後端 update50.sh 已套用(top-transactions API 已存在) ----
if ! grep -q "top-transactions" ledger-backend/app/routers/stats.py; then
  echo "❌ 後端尚未包含 update50.sh 的改動(top-transactions API),請先確認 update50.sh 是否已套用" >&2
  exit 1
fi

# ---- 2. types/ledger.ts:新增 TopTransactionItem / TopTransactionsOut ----
python3 << 'PYEOF'
import sys

path = "ledger-frontend/src/types/ledger.ts"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

old = '''export interface TagBreakdownOut {
  items: TagBreakdownItem[]
  type: 'income' | 'expense'
  start_date: string
  end_date: string
}'''

new = '''export interface TagBreakdownOut {
  items: TagBreakdownItem[]
  type: 'income' | 'expense'
  start_date: string
  end_date: string
}

export interface TopTransactionItem {
  id: string
  amount: number
  date: string
  note: string | null
  account_name: string
  category_name: string
}

export interface TopTransactionsOut {
  type: 'income' | 'expense'
  start_date: string
  end_date: string
  items: TopTransactionItem[]
}'''

count = content.count(old)
if count != 1:
    print(f"❌ ledger.ts 比對字串出現 {count} 次(預期 1 次),中止", file=sys.stderr)
    sys.exit(1)

content = content.replace(old, new)
with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("✅ ledger.ts 修改完成")
PYEOF

# ---- 3. api/ledgerApi.ts:import 補型別 + 新增 fetchTopTransactions ----
python3 << 'PYEOF'
import sys

path = "ledger-frontend/src/api/ledgerApi.ts"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

old_import = "import type { AccountOut, AccountCreatePayload, CategoryOut, CategoryCreatePayload, TagOut, TagCreatePayload, TransactionOut, TransactionCreatePayload, TransactionFilters, MonthlyTrendOut, CategoryBreakdownOut, EntryType, TagBreakdownOut } from '@/types/ledger'"
new_import = "import type { AccountOut, AccountCreatePayload, CategoryOut, CategoryCreatePayload, TagOut, TagCreatePayload, TransactionOut, TransactionCreatePayload, TransactionFilters, MonthlyTrendOut, CategoryBreakdownOut, EntryType, TagBreakdownOut, TopTransactionsOut } from '@/types/ledger'"

count = content.count(old_import)
if count != 1:
    print(f"❌ ledgerApi.ts import 比對字串出現 {count} 次(預期 1 次),中止", file=sys.stderr)
    sys.exit(1)
content = content.replace(old_import, new_import)

old_tail = '''export async function fetchTagBreakdown(
  startDate: string,
  endDate: string,
  type: 'income' | 'expense' = 'expense',
  limit = 15,
): Promise<TagBreakdownOut> {
  const { data } = await apiClient.get<TagBreakdownOut>('/stats/tag-breakdown', {
    params: { start_date: startDate, end_date: endDate, type, limit },
  })
  return data
}'''

new_tail = old_tail + '''

export async function fetchTopTransactions(
  startDate: string,
  endDate: string,
  type: 'income' | 'expense' = 'expense',
  limit = 5,
): Promise<TopTransactionsOut> {
  const { data } = await apiClient.get<TopTransactionsOut>('/stats/top-transactions', {
    params: { start_date: startDate, end_date: endDate, type, limit },
  })
  return data
}'''

count = content.count(old_tail)
if count != 1:
    print(f"❌ ledgerApi.ts 尾端比對字串出現 {count} 次(預期 1 次),中止", file=sys.stderr)
    sys.exit(1)
content = content.replace(old_tail, new_tail)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("✅ ledgerApi.ts 修改完成")
PYEOF

# ---- 4. 新元件:components/TopTransactionsList.vue(全新檔案,完整覆寫) ----
cat > ledger-frontend/src/components/TopTransactionsList.vue << 'VUEEOF'
<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { fetchTopTransactions } from '@/api/ledgerApi'
import type { TopTransactionItem } from '@/types/ledger'
import { formatCurrency } from '@/utils/ledgerLabels'

const props = defineProps<{
  startDate: string
  endDate: string
}>()

const items = ref<TopTransactionItem[]>([])
const loading = ref(false)
const errorMsg = ref('')
const type = ref<'expense' | 'income'>('expense')
const limit = ref(5)

async function load() {
  loading.value = true
  errorMsg.value = ''
  try {
    const result = await fetchTopTransactions(props.startDate, props.endDate, type.value, limit.value)
    items.value = result.items
  } catch (e) {
    errorMsg.value = '載入最大單筆排行失敗'
    items.value = []
  } finally {
    loading.value = false
  }
}

onMounted(load)
watch([() => props.startDate, () => props.endDate, type, limit], load)

const maxAmount = computed(() =>
  items.value.length ? Math.max(...items.value.map((i) => i.amount)) : 1,
)
</script>

<template>
  <div class="top-transactions">
    <div class="header-row">
      <div class="type-toggle">
        <button :class="{ active: type === 'expense' }" @click="type = 'expense'">支出</button>
        <button :class="{ active: type === 'income' }" @click="type = 'income'">收入</button>
      </div>
      <select v-model.number="limit" class="limit-select">
        <option :value="5">Top 5</option>
        <option :value="10">Top 10</option>
        <option :value="20">Top 20</option>
      </select>
    </div>

    <p class="hint">依單筆交易金額排行,不套用進階篩選(帳戶/分類/消費品項)</p>

    <div v-if="loading" class="state-msg">載入中...</div>
    <div v-else-if="errorMsg" class="state-msg error">{{ errorMsg }}</div>
    <div v-else-if="items.length === 0" class="state-msg">此區間無交易</div>

    <div v-else class="bar-list">
      <div v-for="(item, index) in items" :key="item.id" class="bar-row">
        <span class="rank">{{ index + 1 }}</span>
        <div class="info">
          <div class="info-top">
            <span class="category" :title="item.category_name">{{ item.category_name }}</span>
            <span class="account" :title="item.account_name">{{ item.account_name }}</span>
          </div>
          <div class="bar-track">
            <div class="bar-fill" :style="{ width: `${(item.amount / maxAmount) * 100}%` }" />
          </div>
        </div>
        <div class="right">
          <span class="amount">{{ formatCurrency(item.amount) }}</span>
          <span class="date">{{ item.date }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.top-transactions {
  height: 320px;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.header-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 4px;
}
.type-toggle button {
  padding: 4px 12px;
  border: 1px solid #ddd;
  background: #fff;
  cursor: pointer;
}
.type-toggle button.active {
  background: #333;
  color: #fff;
}
.limit-select {
  border: 1px solid #ddd;
  border-radius: 4px;
  padding: 4px 8px;
  font-size: 13px;
}
.hint {
  font-size: 12px;
  color: #888;
  margin: 4px 0 8px;
}
.state-msg {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #999;
}
.state-msg.error {
  color: #d33;
}
.bar-list {
  flex: 1;
  overflow-y: auto;
}
.bar-row {
  display: grid;
  grid-template-columns: 24px 1fr 110px;
  align-items: center;
  gap: 10px;
  padding: 6px 0;
  border-bottom: 1px solid #f3f4f6;
}
.rank {
  font-size: 13px;
  font-weight: 600;
  color: #9ca3af;
  text-align: center;
}
.info-top {
  display: flex;
  justify-content: space-between;
  gap: 8px;
  font-size: 13px;
  margin-bottom: 4px;
}
.category {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-weight: 500;
}
.account {
  color: #888;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  flex-shrink: 0;
}
.bar-track {
  height: 10px;
  background: #f0f0f0;
  border-radius: 4px;
  overflow: hidden;
}
.bar-fill {
  height: 100%;
  background: #4a90d9;
  transition: width 0.3s ease;
}
.right {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
}
.amount {
  font-size: 13px;
  font-weight: 600;
}
.date {
  font-size: 11px;
  color: #999;
}
</style>
VUEEOF

# ---- 5. DashboardView.vue:串進第四個統計子分頁 ----
python3 << 'PYEOF'
import sys

path = "ledger-frontend/src/views/DashboardView.vue"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

edits = [
    (
        "import TagBreakdownChart from '@/components/TagBreakdownChart.vue'\nimport DateRangePicker from '@/components/DateRangePicker.vue'",
        "import TagBreakdownChart from '@/components/TagBreakdownChart.vue'\nimport TopTransactionsList from '@/components/TopTransactionsList.vue'\nimport DateRangePicker from '@/components/DateRangePicker.vue'",
    ),
    (
        "type StatsSubTab = 'trend' | 'breakdown' | 'tagBreakdown'",
        "type StatsSubTab = 'trend' | 'breakdown' | 'tagBreakdown' | 'topTransactions'",
    ),
    (
        '''            <button :class="{ active: statsSubTab === 'tagBreakdown' }" @click="statsSubTab = 'tagBreakdown'">消費品項排行</button>
          </nav>''',
        '''            <button :class="{ active: statsSubTab === 'tagBreakdown' }" @click="statsSubTab = 'tagBreakdown'">消費品項排行</button>
            <button :class="{ active: statsSubTab === 'topTransactions' }" @click="statsSubTab = 'topTransactions'">最大單筆排行</button>
          </nav>''',
    ),
    (
        '''          <MonthlyTrendChart v-if="statsSubTab === 'trend'" :start-date="startDate" :end-date="endDate" />
          <CategoryBreakdownChart v-else-if="statsSubTab === 'breakdown'" type="expense" :start-date="startDate" :end-date="endDate" />
          <TagBreakdownChart v-else :start-date="startDate" :end-date="endDate" />''',
        '''          <MonthlyTrendChart v-if="statsSubTab === 'trend'" :start-date="startDate" :end-date="endDate" />
          <CategoryBreakdownChart v-else-if="statsSubTab === 'breakdown'" type="expense" :start-date="startDate" :end-date="endDate" />
          <TagBreakdownChart v-else-if="statsSubTab === 'tagBreakdown'" :start-date="startDate" :end-date="endDate" />
          <TopTransactionsList v-else :start-date="startDate" :end-date="endDate" />''',
    ),
]

for old, new in edits:
    count = content.count(old)
    if count != 1:
        print(f"❌ DashboardView.vue 比對字串出現 {count} 次(預期 1 次):\\n{old[:80]}...", file=sys.stderr)
        sys.exit(1)
    content = content.replace(old, new)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("✅ DashboardView.vue 修改完成")
PYEOF

# ---- 6. commit(feat,與歸檔分開) ----
git add ledger-frontend/src/types/ledger.ts \
        ledger-frontend/src/api/ledgerApi.ts \
        ledger-frontend/src/components/TopTransactionsList.vue \
        ledger-frontend/src/views/DashboardView.vue
git commit -m "feat: A9 最大單筆排行前端(TopTransactionsList.vue + 第四個統計子分頁)"

# ---- 7. 確認 commit 真的產生 ----
echo "---- git log --oneline -1 ----"
git log --oneline -1
