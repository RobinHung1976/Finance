#!/usr/bin/env bash
set -euo pipefail

# ---------- 0. 自動歸檔:把非本次腳本的 updateM.sh 搬進 updateN/ ----------
mkdir -p updateN
CURRENT=44
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
# 【前置檢查】確認 update43.sh 已套用成功(本次改動建立在其之上)
# ============================================================
if ! grep -q "AccountFilterPicker from './AccountFilterPicker.vue'" "$FRONTEND/src/components/TransactionList.vue"; then
  echo "❌ TransactionList.vue 尚未包含 update43.sh 的改動(找不到 AccountFilterPicker import),請先確認 update43.sh 是否已成功套用" >&2
  exit 1
fi
echo "✅ 確認 update43.sh 的改動已存在,可以繼續套用本次異動"

# ============================================================
# 1. AccountFilterPicker.vue:改為「一直攤開」樣式(拿掉點擊彈出的小面板)
# ============================================================
cat > "$FRONTEND/src/components/AccountFilterPicker.vue" << 'EOF'
<script setup lang="ts">
import { computed, ref } from 'vue'
import type { AccountOut } from '@/types/ledger'

const props = defineProps<{
  accounts: AccountOut[]
  modelValue: string
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

const searchQuery = ref('')

const filteredAccounts = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  const list = q ? props.accounts.filter((a) => a.name.toLowerCase().includes(q)) : props.accounts
  return [...list].sort((a, b) => a.name.localeCompare(b.name))
})

function selectAccount(id: string) {
  emit('update:modelValue', id)
}
function clearSelection() {
  emit('update:modelValue', '')
}
</script>

<template>
  <div class="filter-picker-box">
    <input v-model="searchQuery" type="text" class="search-input" placeholder="搜尋帳戶…" />
    <div class="option-grid">
      <button type="button" class="option-btn" :class="{ selected: !modelValue }" @click="clearSelection">
        所有帳戶
      </button>
      <button
        v-for="a in filteredAccounts"
        :key="a.id"
        type="button"
        class="option-btn"
        :class="{ selected: a.id === modelValue }"
        @click="selectAccount(a.id)"
      >
        {{ a.name }}
      </button>
      <p v-if="filteredAccounts.length === 0" class="no-result">沒有符合的帳戶</p>
    </div>
  </div>
</template>

<style scoped>
.filter-picker-box {
  border: 1px solid var(--color-border);
  border-radius: 8px;
  padding: 10px;
  background: var(--color-bg);
}
.search-input {
  width: 100%;
  padding: 6px 10px;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  font-size: 13px;
  margin-bottom: 8px;
  box-sizing: border-box;
}
.option-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  max-height: 240px;
  overflow-y: auto;
}
.option-btn {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 6px;
  padding: 6px 12px;
  font-size: 13px;
  cursor: pointer;
}
.option-btn.selected {
  border-color: var(--color-primary);
  color: var(--color-primary);
  font-weight: 600;
}
.no-result {
  font-size: 12px;
  color: #6b7a74;
  margin: 0;
}
</style>
EOF
echo "✅ AccountFilterPicker.vue 已改為攤開式樣式"

# ============================================================
# 2. CategoryFilterPicker.vue:改為「一直攤開」樣式,顯示完整路徑
# ============================================================
cat > "$FRONTEND/src/components/CategoryFilterPicker.vue" << 'EOF'
<script setup lang="ts">
import { computed, ref } from 'vue'
import type { CategoryOut } from '@/types/ledger'

const props = defineProps<{
  categories: CategoryOut[]
  modelValue: string
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

const searchQuery = ref('')

function ancestorChain(category: CategoryOut): CategoryOut[] {
  const chain: CategoryOut[] = []
  let node: CategoryOut | undefined = category
  while (node) {
    chain.unshift(node)
    node = node.parent_id ? props.categories.find((c) => c.id === node!.parent_id) : undefined
  }
  return chain
}
function fullPathLabel(category: CategoryOut): string {
  return ancestorChain(category).map((c) => c.name).join(' › ')
}

const filteredResults = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  const list = q ? props.categories.filter((c) => c.name.toLowerCase().includes(q)) : props.categories
  return list
    .map((c) => ({ category: c, label: fullPathLabel(c) }))
    .sort((a, b) => a.label.localeCompare(b.label))
    .slice(0, 50)
})

function selectCategory(id: string) {
  emit('update:modelValue', id)
}
function clearSelection() {
  emit('update:modelValue', '')
}
</script>

<template>
  <div class="filter-picker-box">
    <input v-model="searchQuery" type="text" class="search-input" placeholder="搜尋分類…" />
    <div class="option-grid">
      <button type="button" class="option-btn" :class="{ selected: !modelValue }" @click="clearSelection">
        所有分類
      </button>
      <button
        v-for="r in filteredResults"
        :key="r.category.id"
        type="button"
        class="option-btn"
        :class="{ selected: r.category.id === modelValue }"
        @click="selectCategory(r.category.id)"
      >
        {{ r.label }}
      </button>
      <p v-if="filteredResults.length === 0" class="no-result">沒有符合的分類</p>
    </div>
  </div>
</template>

<style scoped>
.filter-picker-box {
  border: 1px solid var(--color-border);
  border-radius: 8px;
  padding: 10px;
  background: var(--color-bg);
}
.search-input {
  width: 100%;
  padding: 6px 10px;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  font-size: 13px;
  margin-bottom: 8px;
  box-sizing: border-box;
}
.option-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  max-height: 240px;
  overflow-y: auto;
}
.option-btn {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 6px;
  padding: 6px 12px;
  font-size: 13px;
  cursor: pointer;
}
.option-btn.selected {
  border-color: var(--color-primary);
  color: var(--color-primary);
  font-weight: 600;
}
.no-result {
  font-size: 12px;
  color: #6b7a74;
  margin: 0;
}
</style>
EOF
echo "✅ CategoryFilterPicker.vue 已改為攤開式樣式"

# ============================================================
# 3. TagFilterPicker.vue:改為「一直攤開」樣式(複選)
# ============================================================
cat > "$FRONTEND/src/components/TagFilterPicker.vue" << 'EOF'
<script setup lang="ts">
import { computed, ref } from 'vue'
import type { TagOut } from '@/types/ledger'

const props = defineProps<{
  tags: TagOut[]
  modelValue: string[]
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string[]] }>()

const searchQuery = ref('')

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
function clearSelection() {
  emit('update:modelValue', [])
}
</script>

<template>
  <div class="filter-picker-box">
    <input v-model="searchQuery" type="text" class="search-input" placeholder="搜尋消費品項…" />
    <div class="option-grid">
      <button type="button" class="option-btn" :class="{ selected: modelValue.length === 0 }" @click="clearSelection">
        所有品項
      </button>
      <button
        v-for="t in filteredTags"
        :key="t.id"
        type="button"
        class="option-btn"
        :class="{ selected: isSelected(t.id) }"
        @click="toggleTag(t.id)"
      >
        <span>{{ t.name }}</span>
        <span v-if="isSelected(t.id)" class="check-mark">✓</span>
      </button>
      <p v-if="filteredTags.length === 0" class="no-result">沒有符合的消費品項</p>
    </div>
  </div>
</template>

<style scoped>
.filter-picker-box {
  border: 1px solid var(--color-border);
  border-radius: 8px;
  padding: 10px;
  background: var(--color-bg);
}
.search-input {
  width: 100%;
  padding: 6px 10px;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  font-size: 13px;
  margin-bottom: 8px;
  box-sizing: border-box;
}
.option-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  max-height: 240px;
  overflow-y: auto;
}
.option-btn {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 6px;
  padding: 6px 12px;
  font-size: 13px;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 4px;
}
.option-btn.selected {
  border-color: var(--color-primary);
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
  margin: 0;
}
</style>
EOF
echo "✅ TagFilterPicker.vue 已改為攤開式樣式"

# ============================================================
# 4. TransactionList.vue:篩選列改為「進階篩選」收合按鈕 + 展開面板
# ============================================================
python3 << 'PYEOF'
path = "ledger-frontend/src/components/TransactionList.vue"
with open(path, encoding="utf-8") as f:
    content = f.read()

replacements = [
    (
        "const filterAccountId = ref('')\n"
        "const filterCategoryId = ref('')\n"
        "const filterTagIds = ref<string[]>([])\n"
        "const filterMinAmount = ref<number | null>(null)\n"
        "const filterMaxAmount = ref<number | null>(null)",
        "const filterAccountId = ref('')\n"
        "const filterCategoryId = ref('')\n"
        "const filterTagIds = ref<string[]>([])\n"
        "const filterMinAmount = ref<number | null>(null)\n"
        "const filterMaxAmount = ref<number | null>(null)\n"
        "const showAdvancedFilter = ref(false)",
    ),
    (
        "watch(\n"
        "  [filterStartDate, filterEndDate, filterAccountId, filterCategoryId, filterTagIds, filterMinAmount, filterMaxAmount],\n"
        "  loadTransactions\n"
        ")\n"
        "\n"
        "const totalExpense = computed(() =>",
        "watch(\n"
        "  [filterStartDate, filterEndDate, filterAccountId, filterCategoryId, filterTagIds, filterMinAmount, filterMaxAmount],\n"
        "  loadTransactions\n"
        ")\n"
        "\n"
        "const activeAdvancedFilterCount = computed(() => {\n"
        "  let count = 0\n"
        "  if (filterAccountId.value) count++\n"
        "  if (filterCategoryId.value) count++\n"
        "  if (filterTagIds.value.length) count++\n"
        "  return count\n"
        "})\n"
        "\n"
        "const totalExpense = computed(() =>",
    ),
    (
        "      <AccountFilterPicker v-model=\"filterAccountId\" :accounts=\"accounts\" />\n"
        "      <CategoryFilterPicker v-model=\"filterCategoryId\" :categories=\"categories\" />\n"
        "      <TagFilterPicker v-model=\"filterTagIds\" :tags=\"tags\" />\n"
        "      <input\n"
        "        v-model.number=\"filterMinAmount\"\n"
        "        type=\"number\"\n"
        "        min=\"0\"\n"
        "        placeholder=\"最低金額\"\n"
        "        class=\"filter-input\"\n"
        "        style=\"width: 100px\"\n"
        "      />\n"
        "      <span style=\"color: #6b7a74\">至</span>\n"
        "      <input\n"
        "        v-model.number=\"filterMaxAmount\"\n"
        "        type=\"number\"\n"
        "        min=\"0\"\n"
        "        placeholder=\"最高金額\"\n"
        "        class=\"filter-input\"\n"
        "        style=\"width: 100px\"\n"
        "      />\n"
        "    </div>\n"
        "\n"
        "    <div v-if=\"loadError\" class=\"error-banner\">{{ loadError }}</div>",
        "      <button type=\"button\" class=\"filter-input advanced-filter-toggle\" @click=\"showAdvancedFilter = !showAdvancedFilter\">\n"
        "        進階篩選<span v-if=\"activeAdvancedFilterCount\">（{{ activeAdvancedFilterCount }}）</span>\n"
        "      </button>\n"
        "      <input\n"
        "        v-model.number=\"filterMinAmount\"\n"
        "        type=\"number\"\n"
        "        min=\"0\"\n"
        "        placeholder=\"最低金額\"\n"
        "        class=\"filter-input\"\n"
        "        style=\"width: 100px\"\n"
        "      />\n"
        "      <span style=\"color: #6b7a74\">至</span>\n"
        "      <input\n"
        "        v-model.number=\"filterMaxAmount\"\n"
        "        type=\"number\"\n"
        "        min=\"0\"\n"
        "        placeholder=\"最高金額\"\n"
        "        class=\"filter-input\"\n"
        "        style=\"width: 100px\"\n"
        "      />\n"
        "    </div>\n"
        "\n"
        "    <div v-if=\"showAdvancedFilter\" class=\"advanced-filter-panel\">\n"
        "      <div class=\"advanced-filter-block\">\n"
        "        <h4 class=\"advanced-filter-label\">帳戶</h4>\n"
        "        <AccountFilterPicker v-model=\"filterAccountId\" :accounts=\"accounts\" />\n"
        "      </div>\n"
        "      <div class=\"advanced-filter-block\">\n"
        "        <h4 class=\"advanced-filter-label\">分類</h4>\n"
        "        <CategoryFilterPicker v-model=\"filterCategoryId\" :categories=\"categories\" />\n"
        "      </div>\n"
        "      <div class=\"advanced-filter-block\">\n"
        "        <h4 class=\"advanced-filter-label\">消費品項</h4>\n"
        "        <TagFilterPicker v-model=\"filterTagIds\" :tags=\"tags\" />\n"
        "      </div>\n"
        "    </div>\n"
        "\n"
        "    <div v-if=\"loadError\" class=\"error-banner\">{{ loadError }}</div>",
    ),
    (
        ".filter-input {\n"
        "  padding: 6px 10px;\n"
        "  border: 1px solid var(--color-border);\n"
        "  border-radius: 6px;\n"
        "  font-size: 13px;\n"
        "  background: var(--color-surface);\n"
        "}",
        ".filter-input {\n"
        "  padding: 6px 10px;\n"
        "  border: 1px solid var(--color-border);\n"
        "  border-radius: 6px;\n"
        "  font-size: 13px;\n"
        "  background: var(--color-surface);\n"
        "}\n"
        "\n"
        ".advanced-filter-toggle {\n"
        "  cursor: pointer;\n"
        "}\n"
        "\n"
        ".advanced-filter-panel {\n"
        "  display: flex;\n"
        "  flex-direction: column;\n"
        "  gap: 12px;\n"
        "  margin-bottom: 12px;\n"
        "  padding: 12px;\n"
        "  background: var(--color-surface);\n"
        "  border: 1px solid var(--color-border);\n"
        "  border-radius: 8px;\n"
        "}\n"
        "\n"
        ".advanced-filter-block {\n"
        "  display: flex;\n"
        "  flex-direction: column;\n"
        "  gap: 6px;\n"
        "}\n"
        "\n"
        ".advanced-filter-label {\n"
        "  font-size: 12px;\n"
        "  color: #6b7a74;\n"
        "  text-transform: uppercase;\n"
        "  letter-spacing: 0.04em;\n"
        "  margin: 0;\n"
        "  font-weight: 600;\n"
        "}",
    ),
]

for old, new in replacements:
    if old not in content:
        raise SystemExit(f"❌ 內容不符,請人工檢查以下片段是否存在:\n{old[:80]}...")
    content = content.replace(old, new)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("✅ TransactionList.vue 已改為「進階篩選」收合面板設計")
PYEOF

echo "✅ 檔案異動完成,commit..."
git add -A
git commit -m "feat: 交易紀錄篩選改為進階篩選收合面板,帳戶/分類/品項改為搜尋+攤開按鈕網格樣式"
echo "---- 確認 commit 是否真的產生 ----"
git log --oneline -1
git status
echo "✅ 若上方 git log 顯示的是本次 feat commit、git status 顯示 clean,才代表成功"
echo "接下來請執行:git push origin main,再到 server 跑 ./deploy.sh"
