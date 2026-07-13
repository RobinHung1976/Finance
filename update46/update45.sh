#!/usr/bin/env bash
set -euo pipefail

# ---------- 0. 自動歸檔 ----------
mkdir -p updateN
CURRENT=45
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

FRONTEND=ledger-frontend
[ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

# ---------- 前置檢查:確認 update44.sh 已套用 ----------
if ! grep -q "advanced-filter-panel" "$FRONTEND/src/components/TransactionList.vue"; then
  echo "❌ TransactionList.vue 尚未包含 update44.sh 的改動(找不到 advanced-filter-panel),請先確認 update44.sh 是否已套用成功" >&2
  exit 1
fi
echo "✅ 確認 update44.sh 的改動已存在"

# ============================================================
# 1. CategoryFilterPicker.vue:改回逐層鑽取麵包屑(比照 CategoryPicker.vue),
#    額外加「所有分類」清除按鈕(表單用的 CategoryPicker 不需要這個,篩選情境才需要)
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

const path = ref<CategoryOut[]>([])
const searchQuery = ref('')

const currentParentId = computed<string | null>(() => {
  const last = path.value[path.value.length - 1]
  return last ? last.id : null
})

const currentLevelCategories = computed(() =>
  props.categories.filter((c) => c.parent_id === currentParentId.value)
)

function hasChildren(categoryId: string): boolean {
  return props.categories.some((c) => c.parent_id === categoryId)
}

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

function selectCategory(category: CategoryOut) {
  emit('update:modelValue', category.id)
  path.value.push(category)
}

function jumpToBreadcrumb(index: number) {
  if (index < 0) {
    path.value = []
    return
  }
  path.value = path.value.slice(0, index + 1)
  emit('update:modelValue', path.value[index].id)
}

function clearSelection() {
  emit('update:modelValue', '')
  path.value = []
}

const searchResults = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return []
  return props.categories
    .map((c) => ({ category: c, label: fullPathLabel(c) }))
    .filter((r) => r.category.name.toLowerCase().includes(q))
    .sort((a, b) => a.label.localeCompare(b.label))
    .slice(0, 30)
})

function selectFromSearch(category: CategoryOut) {
  emit('update:modelValue', category.id)
  path.value = ancestorChain(category).slice(0, -1)
  searchQuery.value = ''
}
</script>

<template>
  <div class="filter-picker-box">
    <input v-model="searchQuery" type="text" class="search-input" placeholder="搜尋分類(不限層級)…" />

    <template v-if="searchQuery.trim()">
      <div v-if="searchResults.length" class="search-results">
        <button
          v-for="r in searchResults"
          :key="r.category.id"
          type="button"
          class="search-result-btn"
          :class="{ selected: r.category.id === modelValue }"
          @click="selectFromSearch(r.category)"
        >
          {{ r.label }}
        </button>
      </div>
      <p v-else class="no-result">沒有符合「{{ searchQuery }}」的分類</p>
    </template>

    <template v-else>
      <div class="breadcrumb">
        <button type="button" class="crumb" :class="{ active: path.length === 0 }" @click="jumpToBreadcrumb(-1)">
          全部
        </button>
        <template v-for="(node, idx) in path" :key="node.id">
          <span class="crumb-sep">›</span>
          <button
            type="button"
            class="crumb"
            :class="{ active: idx === path.length - 1 }"
            @click="jumpToBreadcrumb(idx)"
          >
            {{ node.name }}
          </button>
        </template>
      </div>

      <div class="option-grid">
        <button type="button" class="option-btn" :class="{ selected: !modelValue }" @click="clearSelection">
          所有分類
        </button>
        <button
          v-for="c in currentLevelCategories"
          :key="c.id"
          type="button"
          class="option-btn"
          :class="{ selected: c.id === modelValue }"
          @click="selectCategory(c)"
        >
          {{ c.name }}
          <span v-if="hasChildren(c.id)" class="chevron">›</span>
        </button>
      </div>
    </template>
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
.search-results {
  display: flex;
  flex-direction: column;
  gap: 4px;
  max-height: 240px;
  overflow-y: auto;
}
.search-result-btn {
  text-align: left;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 6px;
  padding: 6px 10px;
  font-size: 13px;
  cursor: pointer;
}
.search-result-btn.selected {
  border-color: var(--color-primary);
  color: var(--color-primary);
  font-weight: 600;
}
.breadcrumb {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 4px;
  margin-bottom: 8px;
}
.crumb {
  background: none;
  border: none;
  font-size: 12px;
  color: #6b7a74;
  padding: 2px 4px;
  cursor: pointer;
}
.crumb.active {
  color: var(--color-primary);
  font-weight: 600;
}
.crumb-sep {
  color: #b7c2bd;
  font-size: 12px;
}
.option-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
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
.chevron {
  color: #9fb3ac;
  font-size: 11px;
}
.no-result {
  font-size: 12px;
  color: #6b7a74;
  margin: 0;
}
</style>
EOF
echo "✅ CategoryFilterPicker.vue 已改回逐層鑽取麵包屑樣式"

# ============================================================
# 2. TagFilterPicker.vue:改為「最近使用 / 全部品項」分區(比照 TagPicker.vue),
#    額外加「所有品項」清除按鈕
# ============================================================
cat > "$FRONTEND/src/components/TagFilterPicker.vue" << 'EOF'
<script setup lang="ts">
import { ref, computed } from 'vue'
import type { TagOut } from '@/types/ledger'

const RECENT_LIMIT = 8

const props = defineProps<{
  modelValue: string[]
  tags: TagOut[]
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string[]] }>()

const searchQuery = ref('')
const isSearching = computed(() => searchQuery.value.trim().length > 0)

const filteredTags = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return props.tags
  return props.tags.filter((t) => t.name.toLowerCase().includes(q))
})

const recentTags = computed(() => {
  return props.tags
    .filter((t) => t.last_used_date)
    .sort((a, b) => (b.last_used_date! < a.last_used_date! ? -1 : 1))
    .slice(0, RECENT_LIMIT)
})

const otherTags = computed(() => {
  const recentIds = new Set(recentTags.value.map((t) => t.id))
  return props.tags.filter((t) => !recentIds.has(t.id))
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
    </div>

    <template v-if="!isSearching">
      <div v-if="recentTags.length" class="tag-section-label">最近使用</div>
      <div v-if="recentTags.length" class="option-grid">
        <button
          v-for="t in recentTags"
          :key="t.id"
          type="button"
          class="option-btn"
          :class="{ selected: isSelected(t.id) }"
          @click="toggleTag(t.id)"
        >
          {{ t.name }}
        </button>
      </div>

      <div v-if="recentTags.length && otherTags.length" class="tag-section-label">全部品項</div>
      <div class="option-grid">
        <button
          v-for="t in otherTags"
          :key="t.id"
          type="button"
          class="option-btn"
          :class="{ selected: isSelected(t.id) }"
          @click="toggleTag(t.id)"
        >
          {{ t.name }}
        </button>
      </div>
    </template>

    <template v-else>
      <div class="option-grid">
        <button
          v-for="t in filteredTags"
          :key="t.id"
          type="button"
          class="option-btn"
          :class="{ selected: isSelected(t.id) }"
          @click="toggleTag(t.id)"
        >
          {{ t.name }}
        </button>
        <p v-if="filteredTags.length === 0" class="no-result">沒有符合的消費品項</p>
      </div>
    </template>
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
.tag-section-label {
  font-size: 11px;
  color: #8a948e;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  margin: 8px 0 4px;
}
.option-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.option-btn {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 999px;
  padding: 6px 14px;
  font-size: 13px;
  cursor: pointer;
}
.option-btn.selected {
  border-color: var(--color-primary);
  background: var(--color-primary);
  color: #fff;
  font-weight: 600;
}
.no-result {
  font-size: 12px;
  color: #6b7a74;
  margin: 0;
}
</style>
EOF
echo "✅ TagFilterPicker.vue 已改為最近使用/全部品項分區樣式"

echo "✅ 檔案異動完成,commit..."
git add -A
git commit -m "fix: 分類篩選改回逐層鑽取麵包屑,消費品項篩選改為最近使用/全部品項分區,減少一次攤開過多按鈕的雜亂感"
echo "---- 確認 commit 是否真的產生 ----"
git log --oneline -1
git status
echo "✅ 若上方 git log 顯示的是本次 fix commit、git status 顯示 clean,才代表成功"
echo "接下來請執行:git push origin main,再到 server 跑 ./deploy.sh"
