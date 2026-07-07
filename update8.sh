#!/usr/bin/env bash
set -euo pipefail
BACKEND=ledger-backend
FRONTEND=ledger-frontend
[ -d "$BACKEND" ] && [ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

python3 << 'PYEOF'
path = "ledger-frontend/src/views/DashboardView.vue"
with open(path) as f:
    content = f.read()

old = """import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import AccountList from '@/components/AccountList.vue'
import CategoryList from '@/components/CategoryList.vue'
import TransactionList from '@/components/TransactionList.vue'
import MonthlyTrendChart from '@/components/MonthlyTrendChart.vue'
import CategoryBreakdownChart from '@/components/CategoryBreakdownChart.vue'
import DateRangePicker from '@/components/DateRangePicker.vue'

const router = useRouter()
const auth = useAuthStore()

type Tab = 'stats' | 'transactions' | 'accounts' | 'categories'
const activeTab = ref<Tab>('stats')"""

new = """import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { fetchMyHousehold } from '@/api/auth'
import type { HouseholdOut } from '@/types/api'
import AccountList from '@/components/AccountList.vue'
import CategoryList from '@/components/CategoryList.vue'
import TransactionList from '@/components/TransactionList.vue'
import MonthlyTrendChart from '@/components/MonthlyTrendChart.vue'
import CategoryBreakdownChart from '@/components/CategoryBreakdownChart.vue'
import DateRangePicker from '@/components/DateRangePicker.vue'

const router = useRouter()
const auth = useAuthStore()

const household = ref<HouseholdOut | null>(null)
onMounted(async () => {
  try {
    household.value = await fetchMyHousehold()
  } catch {
    // 失敗不阻斷主頁,標題 fallback 顯示預設文字
  }
})

type Tab = 'stats' | 'transactions' | 'accounts' | 'categories'
const activeTab = ref<Tab>('stats')"""

if old not in content:
    raise SystemExit("❌ script 區塊不符")
content = content.replace(old, new)

old_h1 = '<h1 style="font-size: 20px; margin: 0">家庭理財</h1>'
new_h1 = '<h1 style="font-size: 20px; margin: 0">{{ household?.name ?? \'家庭理財\' }}</h1>'
if old_h1 not in content:
    raise SystemExit("❌ 標題不符")
content = content.replace(old_h1, new_h1)

with open(path, "w") as f:
    f.write(content)
print("✅ 修正完成")
PYEOF

git add -A
git commit -m "fix: DashboardView 標題改用實際 household 名稱"
echo "✅ 已 commit,請 push + deploy"
