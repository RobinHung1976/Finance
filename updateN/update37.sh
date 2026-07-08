#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
FRONTEND=ledger-frontend
[ -d "$BACKEND" ] && [ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

echo "=== update37.sh:修正 update36.sh 遺留問題 + DashboardView 加入消費品項排行分頁 ==="

# ---------- 0. 自動歸檔:把小於當前編號的 updateM.sh 搬進 updateN/ ----------
mkdir -p updateN
CURRENT=37
for f in update*.sh; do
  [ "$f" = "update${CURRENT}.sh" ] && continue
  [ -f "$f" ] || continue
  git mv "$f" "updateN/$f" 2>/dev/null || mv "$f" "updateN/$f"
done
git add -A
if ! git diff --cached --quiet; then
  git commit -m "chore: 歸檔已執行的 updateN.sh 腳本"
  echo "✅ 歸檔 commit 已產生"
fi

# ---------- 1. 修正 stats.py:TransactionType -> EntryType ----------
python3 << 'PYEOF'
path = "ledger-backend/app/routers/stats.py"
with open(path) as f:
    content = f.read()

old = '''    type: TransactionType = TransactionType.expense,'''
new = '''    type: EntryType = EntryType.expense,'''

if old not in content:
    raise SystemExit("❌ 找不到預期字串,update36.sh 產出的內容與假設不符,請人工確認 stats.py")

content = content.replace(old, new)

with open(path, "w") as f:
    f.write(content)
print("✅ stats.py:TransactionType 已修正為 EntryType")
PYEOF

# ---------- 2. DashboardView.vue:精確字串替換,加入消費品項排行分頁 ----------
python3 << 'PYEOF'
path = "ledger-frontend/src/views/DashboardView.vue"
with open(path) as f:
    content = f.read()

replacements = [
    (
        "import CategoryBreakdownChart from '@/components/CategoryBreakdownChart.vue'",
        "import CategoryBreakdownChart from '@/components/CategoryBreakdownChart.vue'\nimport TagBreakdownChart from '@/components/TagBreakdownChart.vue'",
    ),
    (
        "type StatsSubTab = 'trend' | 'breakdown'",
        "type StatsSubTab = 'trend' | 'breakdown' | 'tagBreakdown'",
    ),
    (
        '''<button :class="{ active: statsSubTab === 'breakdown' }" @click="statsSubTab = 'breakdown'">支出分類統計</button>''',
        '''<button :class="{ active: statsSubTab === 'breakdown' }" @click="statsSubTab = 'breakdown'">支出分類統計</button>
            <button :class="{ active: statsSubTab === 'tagBreakdown' }" @click="statsSubTab = 'tagBreakdown'">消費品項排行</button>''',
    ),
    (
        '''<CategoryBreakdownChart v-else type="expense" :start-date="startDate" :end-date="endDate" />''',
        '''<CategoryBreakdownChart v-else-if="statsSubTab === 'breakdown'" type="expense" :start-date="startDate" :end-date="endDate" />
          <TagBreakdownChart v-else :start-date="startDate" :end-date="endDate" />''',
    ),
]

for old, new in replacements:
    if old not in content:
        raise SystemExit(f"❌ 找不到預期字串,請人工確認 DashboardView.vue:\n{old}")
    content = content.replace(old, new, 1)

with open(path, "w") as f:
    f.write(content)
print("✅ DashboardView.vue 已加入消費品項排行分頁")
PYEOF

echo ""
git add -A
git commit -m "fix: 修正 stats.py TransactionType 未定義問題,並於 DashboardView 加入消費品項排行分頁"
echo "✅ 已 commit"
git log --oneline -3