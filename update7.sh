#!/usr/bin/env bash
set -euo pipefail

FRONTEND=ledger-frontend
[ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

python3 << 'PYEOF'
path = "ledger-frontend/src/views/DashboardView.vue"
with open(path) as f:
    content = f.read()

old_script = """const refreshKey = ref(0)"""
new_script = """// 統計子分頁(圖表 tab 切換,取代原本 grid 併排)
type StatsSubTab = 'trend' | 'breakdown'
const statsSubTab = ref<StatsSubTab>('trend')

const refreshKey = ref(0)"""
if old_script not in content:
    raise SystemExit("❌ script 區塊不符")
content = content.replace(old_script, new_script)

old_template = """      <div v-if="activeTab === 'stats'">
        <div class="stats-toolbar">
          <DateRangePicker v-model:start-date="startDate" v-model:end-date="endDate" />
        </div>
        <div class="stats-grid">
          <div class="stats-panel">
            <h3>月收支趨勢</h3>
            <MonthlyTrendChart :start-date="startDate" :end-date="endDate" />
          </div>
          <div class="stats-panel">
            <h3>支出分類統計</h3>
            <CategoryBreakdownChart type="expense" :start-date="startDate" :end-date="endDate" />
          </div>
        </div>
      </div>"""
new_template = """      <div v-if="activeTab === 'stats'">
        <div class="stats-toolbar">
          <nav class="sub-tab-bar">
            <button :class="{ active: statsSubTab === 'trend' }" @click="statsSubTab = 'trend'">月收支趨勢</button>
            <button :class="{ active: statsSubTab === 'breakdown' }" @click="statsSubTab = 'breakdown'">支出分類統計</button>
          </nav>
          <DateRangePicker v-model:start-date="startDate" v-model:end-date="endDate" />
        </div>
        <div class="stats-panel">
          <MonthlyTrendChart v-if="statsSubTab === 'trend'" :start-date="startDate" :end-date="endDate" />
          <CategoryBreakdownChart v-else type="expense" :start-date="startDate" :end-date="endDate" />
        </div>
      </div>"""
if old_template not in content:
    raise SystemExit("❌ template 區塊不符")
content = content.replace(old_template, new_template)

old_style = """.stats-toolbar { display: flex; justify-content: flex-end; margin-bottom: 12px; }

/* 3fr:2fr — 折線圖需要橫向空間畫時間軸,圓餅圖不需要太寬 */
.stats-grid { display: grid; grid-template-columns: 3fr 2fr; gap: 1.5rem; align-items: stretch; }
/* 若想改上下堆疊,改成: grid-template-columns: 1fr; */

.stats-panel { background: #fff; border-radius: 8px; padding: 1rem; box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1); display: flex; flex-direction: column; }
.stats-panel h3 { margin: 0 0 12px; font-size: 15px; }
@media (max-width: 900px) { .stats-grid { grid-template-columns: 1fr; } }"""
new_style = """.stats-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  flex-wrap: wrap;
  gap: 12px;
}

.sub-tab-bar { display: flex; gap: 4px; }
.sub-tab-bar button {
  background: #f3f4f6;
  border: 1px solid #e5e7eb;
  padding: 6px 14px;
  font-size: 13px;
  color: #4b5563;
  cursor: pointer;
  border-radius: 6px;
  transition: background 0.15s;
}
.sub-tab-bar button:hover { background: #e5e7eb; }
.sub-tab-bar button.active { background: var(--color-primary); border-color: var(--color-primary); color: #fff; font-weight: 600; }

/* 單一 tab 全寬渲染,折線圖時間軸/圓餅圖標籤都有完整寬度可用 */
.stats-panel { background: #fff; border-radius: 8px; padding: 1rem; box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1); }"""
if old_style not in content:
    raise SystemExit("❌ style 區塊不符")
content = content.replace(old_style, new_style)

with open(path, "w") as f:
    f.write(content)
print("✅ DashboardView.vue 已改為統計子分頁切換")
PYEOF

echo "✅ 完成"
git add -A
git commit -m "feat: 統計頁改為 tab 切換(月收支趨勢/支出分類統計),取代 grid 併排"
echo "✅ 已 commit,請執行 'git push origin main',再到 server 跑 ./deploy.sh"