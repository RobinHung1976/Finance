#!/usr/bin/env bash
set -euo pipefail

FRONTEND=ledger-frontend
[ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

python3 << 'PYEOF'
path = "ledger-frontend/src/views/DashboardView.vue"
with open(path) as f:
    content = f.read()

# ---------- import ----------
old_import = "import DateRangePicker from '@/components/DateRangePicker.vue'"
new_import = old_import + "\nimport ExcelImportExport from '@/components/ExcelImportExport.vue'"
if old_import not in content:
    raise SystemExit("❌ import 錨點不符,請人工檢查")
content = content.replace(old_import, new_import, 1)

# ---------- Tab type ----------
old_type = "type Tab = 'stats' | 'transactions' | 'accounts' | 'categories'"
new_type = "type Tab = 'stats' | 'transactions' | 'accounts' | 'categories' | 'transfer'"
if old_type not in content:
    raise SystemExit("❌ Tab type 錨點不符,請人工檢查")
content = content.replace(old_type, new_type, 1)

# ---------- Nav 按鈕 ----------
old_nav = """      <button :class="{ active: activeTab === 'categories' }" @click="activeTab = 'categories'">分類</button>
    </nav>"""
new_nav = """      <button :class="{ active: activeTab === 'categories' }" @click="activeTab = 'categories'">分類</button>
      <button :class="{ active: activeTab === 'transfer' }" @click="activeTab = 'transfer'">匯入/匯出</button>
    </nav>"""
if old_nav not in content:
    raise SystemExit("❌ nav 錨點不符,請人工檢查")
content = content.replace(old_nav, new_nav, 1)

# ---------- Tab 內容 ----------
old_section = """      <CategoryList v-else-if="activeTab === 'categories'" @changed="handleReferenceDataChanged" />
    </section>"""
new_section = """      <CategoryList v-else-if="activeTab === 'categories'" @changed="handleReferenceDataChanged" />
      <ExcelImportExport v-else-if="activeTab === 'transfer'" />
    </section>"""
if old_section not in content:
    raise SystemExit("❌ section 錨點不符,請人工檢查")
content = content.replace(old_section, new_section, 1)

with open(path, "w") as f:
    f.write(content)
print("✅ DashboardView.vue 已加入「匯入/匯出」tab")
PYEOF

git add -A
git commit -m "feat: Dashboard 新增「匯入/匯出」tab,掛載 ExcelImportExport 元件"
echo "✅ 已 commit,請執行 'git push origin main',再到 server 跑 ./deploy.sh"