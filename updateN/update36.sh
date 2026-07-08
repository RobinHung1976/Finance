#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
FRONTEND=ledger-frontend
[ -d "$BACKEND" ] && [ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

echo "=== update36.sh:消費品項排行統計(tag-breakdown) ==="

# ---------- 1. 全新檔案:TagBreakdownChart.vue ----------
mkdir -p "$FRONTEND/src/components"
cat > "$FRONTEND/src/components/TagBreakdownChart.vue" << 'EOF'
<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { fetchTagBreakdown } from '@/api/ledger'
import type { TagBreakdownItem } from '@/types/ledger'
import { formatCurrency } from '@/utils/ledgerLabels'

const props = defineProps<{
  startDate: string
  endDate: string
}>()

const items = ref<TagBreakdownItem[]>([])
const loading = ref(false)
const errorMsg = ref('')
const type = ref<'expense' | 'income'>('expense')

async function load() {
  loading.value = true
  errorMsg.value = ''
  try {
    const result = await fetchTagBreakdown(props.startDate, props.endDate, type.value)
    items.value = result.items
  } catch (e) {
    errorMsg.value = '載入消費品項排行失敗'
    items.value = []
  } finally {
    loading.value = false
  }
}

onMounted(load)
watch([() => props.startDate, () => props.endDate, type], load)

const maxAmount = computed(() =>
  items.value.length ? Math.max(...items.value.map((i) => i.total_amount)) : 1,
)
</script>

<template>
  <div class="tag-breakdown">
    <div class="header-row">
      <div class="type-toggle">
        <button :class="{ active: type === 'expense' }" @click="type = 'expense'">支出</button>
        <button :class="{ active: type === 'income' }" @click="type = 'income'">收入</button>
      </div>
    </div>

    <p class="hint">
      依消費品項排行(單筆交易可能同時掛多個品項,故總和不等於{{ type === 'expense' ? '支出' : '收入' }}總額)
    </p>

    <div v-if="loading" class="state-msg">載入中...</div>
    <div v-else-if="errorMsg" class="state-msg error">{{ errorMsg }}</div>
    <div v-else-if="items.length === 0" class="state-msg">此區間無已標記消費品項的交易</div>

    <div v-else class="bar-list">
      <div v-for="item in items" :key="item.tag_id" class="bar-row">
        <span class="label" :title="item.name">{{ item.name }}</span>
        <div class="bar-track">
          <div class="bar-fill" :style="{ width: `${(item.total_amount / maxAmount) * 100}%` }" />
        </div>
        <span class="amount">{{ formatCurrency(item.total_amount) }}</span>
        <span class="count">{{ item.transaction_count }} 筆</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.tag-breakdown {
  height: 320px;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.header-row {
  display: flex;
  justify-content: flex-end;
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
  grid-template-columns: 90px 1fr 90px 50px;
  align-items: center;
  gap: 8px;
  padding: 4px 0;
}
.label {
  font-size: 13px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.bar-track {
  height: 14px;
  background: #f0f0f0;
  border-radius: 4px;
  overflow: hidden;
}
.bar-fill {
  height: 100%;
  background: #4a90d9;
  transition: width 0.3s ease;
}
.amount {
  font-size: 13px;
  text-align: right;
}
.count {
  font-size: 12px;
  color: #999;
  text-align: right;
}
</style>
EOF
echo "✅ TagBreakdownChart.vue 已建立"

# ---------- 2. 附加到 schemas_ledger.py(檔尾新增,冪等檢查) ----------
python3 << 'PYEOF'
path = "ledger-backend/app/schemas_ledger.py"
marker = "class TagBreakdownItem(BaseModel):"

with open(path) as f:
    content = f.read()

if marker in content:
    print("⏭  schemas_ledger.py 已包含 TagBreakdownItem,略過")
else:
    addition = '''

class TagBreakdownItem(BaseModel):
    tag_id: str
    name: str
    total_amount: float
    transaction_count: int


class TagBreakdownOut(BaseModel):
    items: list[TagBreakdownItem]
    type: TransactionType
    start_date: date
    end_date: date
'''
    with open(path, "a") as f:
        f.write(addition)
    print("✅ schemas_ledger.py 已附加 TagBreakdownItem/TagBreakdownOut")
PYEOF

# ---------- 3. 附加到 stats.py(檔尾新增,冪等檢查) ----------
python3 << 'PYEOF'
path = "ledger-backend/app/routers/stats.py"
marker = "def get_tag_breakdown"

with open(path) as f:
    content = f.read()

if marker in content:
    print("⏭  stats.py 已包含 get_tag_breakdown,略過")
else:
    addition = '''

from app.models import Tag, TransactionTag
from app.schemas_ledger import TagBreakdownItem, TagBreakdownOut
from fastapi import Query


@router.get("/tag-breakdown", response_model=TagBreakdownOut)
def get_tag_breakdown(
    start_date: date,
    end_date: date,
    type: TransactionType = TransactionType.expense,
    limit: int = Query(15, ge=1, le=50),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if end_date < start_date:
        raise HTTPException(status_code=400, detail="end_date 不可早於 start_date")

    rows = (
        db.query(
            Tag.id,
            Tag.name,
            func.sum(Transaction.amount).label("total_amount"),
            func.count(Transaction.id).label("transaction_count"),
        )
        .join(TransactionTag, TransactionTag.tag_id == Tag.id)
        .join(Transaction, Transaction.id == TransactionTag.transaction_id)
        .filter(
            Tag.household_id == current_user.household_id,
            Transaction.type == type,
            Transaction.date >= start_date,
            Transaction.date <= end_date,
        )
        .group_by(Tag.id, Tag.name)
        .order_by(func.sum(Transaction.amount).desc())
        .limit(limit)
        .all()
    )

    return TagBreakdownOut(
        items=[
            TagBreakdownItem(
                tag_id=str(r.id),
                name=r.name,
                total_amount=float(r.total_amount),
                transaction_count=r.transaction_count,
            )
            for r in rows
        ],
        type=type,
        start_date=start_date,
        end_date=end_date,
    )
'''
    with open(path, "a") as f:
        f.write(addition)
    print("✅ stats.py 已附加 get_tag_breakdown")
    print("⚠️  請人工確認 stats.py 檔頭是否已 import HTTPException / date / func / Session / Depends / TransactionType / Transaction / User / get_db / get_current_user,若缺漏需手動補上")
PYEOF

# ---------- 4. 附加到 types/ledger.ts(冪等檢查) ----------
python3 << 'PYEOF'
path = "ledger-frontend/src/types/ledger.ts"
marker = "TagBreakdownItem"

with open(path) as f:
    content = f.read()

if marker in content:
    print("⏭  types/ledger.ts 已包含 TagBreakdownItem,略過")
else:
    addition = '''

export interface TagBreakdownItem {
  tag_id: string
  name: string
  total_amount: number
  transaction_count: number
}

export interface TagBreakdownOut {
  items: TagBreakdownItem[]
  type: 'income' | 'expense'
  start_date: string
  end_date: string
}
'''
    with open(path, "a") as f:
        f.write(addition)
    print("✅ types/ledger.ts 已附加 TagBreakdownItem/TagBreakdownOut")
PYEOF

# ---------- 5. 附加到 api/ledger.ts(冪等檢查) ----------
python3 << 'PYEOF'
path = "ledger-frontend/src/api/ledger.ts"
marker = "fetchTagBreakdown"

with open(path) as f:
    content = f.read()

if marker in content:
    print("⏭  api/ledger.ts 已包含 fetchTagBreakdown,略過")
else:
    addition = '''

export async function fetchTagBreakdown(
  startDate: string,
  endDate: string,
  type: 'income' | 'expense' = 'expense',
  limit = 15,
): Promise<TagBreakdownOut> {
  const { data } = await apiClient.get<TagBreakdownOut>('/stats/tag-breakdown', {
    params: { start_date: startDate, end_date: endDate, type, limit },
  })
  return data
}
'''
    with open(path, "a") as f:
        f.write(addition)
    print("✅ api/ledger.ts 已附加 fetchTagBreakdown")
    print("⚠️  請人工確認 api/ledger.ts 檔頭已 import TagBreakdownOut(從 '@/types/ledger'),若缺漏需手動補上")
PYEOF

echo ""
echo "=== 完成 ==="
git add -A
git commit -m "feat: 新增消費品項排行統計 API(/stats/tag-breakdown)與前端長條圖元件"
echo "✅ 已 commit,請執行 'git log --oneline -1' 確認,再 'git push origin main',最後到 server 跑 ./deploy.sh"
echo ""
echo "⚠️  DashboardView.vue 的 tab 整合本次未處理:"
echo "   請先在 server 上執行:cat ledger-frontend/src/views/DashboardView.vue"
echo "   把實際內容貼給我,我再依實際內容出 update37.sh 加上「消費品項排行」分頁"