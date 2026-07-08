#!/usr/bin/env bash
set -euo pipefail

FRONTEND=ledger-frontend
[ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

python3 << 'PYEOF'
path = "ledger-frontend/src/components/TransactionList.vue"
with open(path) as f:
    content = f.read()

old = """            <div class="tx-card-info">
              <strong class="tx-category">{{ categoryName(tx.category_id) }}</strong>
              <span class="tx-sub">
                {{ accountName(tx.account_id) }}<template v-if="tx.note"> · {{ tx.note }}</template>
                <template v-if="tx.tags.length"> · {{ tx.tags.map((t) => t.name).join('、') }}</template>
              </span>
            </div>"""

new = """            <div class="tx-card-info">
              <strong class="tx-category">{{ categoryName(tx.category_id) }}</strong>
              <span class="tx-sub">{{ accountName(tx.account_id) }}<template v-if="tx.note"> · {{ tx.note }}</template></span>
              <div v-if="tx.tags.length" class="tx-tags">
                <span v-for="t in tx.tags" :key="t.id" class="tag-chip">{{ t.name }}</span>
              </div>
            </div>"""

if old not in content:
    raise SystemExit("❌ 內容不符,請人工檢查 TransactionList.vue 現況")
content = content.replace(old, new, 1)

old_style_anchor = """.tx-sub {
  font-size: 12px;
  color: #6b7a74;
}"""
new_style_anchor = """.tx-sub {
  font-size: 12px;
  color: #6b7a74;
}

.tx-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  margin-top: 4px;
}

.tag-chip {
  display: inline-block;
  background: #fef3c7;
  color: #92400e;
  border: 1px solid #fde68a;
  border-radius: 999px;
  padding: 2px 10px;
  font-size: 11px;
  font-weight: 600;
}"""
if old_style_anchor not in content:
    raise SystemExit("❌ style 錨點不符")
content = content.replace(old_style_anchor, new_style_anchor, 1)

with open(path, "w") as f:
    f.write(content)
print("✅ TransactionList.vue: 消費品項改成彩色 chip,獨立於分類/帳戶顯示")
PYEOF

git add -A
git commit -m "feat: 交易列表消費品項改成獨立彩色標籤顯示,不再與帳戶/備註混在同一行文字"
echo "✅ 已 commit"