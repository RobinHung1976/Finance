#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# update47.sh
# 修正 update46.sh 遺漏:前端 TS 型別定義 CategoryBreakdownItem 缺少 is_self 欄位,
# 導致 vue-tsc 型別檢查失敗、deploy.sh 中止在 npm run build 這一步。
#
# 前置驗證:確認 update46.sh 已經套用(stats.py 已含 is_self 邏輯),
# 且 ledger.ts 的 CategoryBreakdownItem 仍是尚未加 is_self 的舊版內容。
#
# 影響檔案:
#   - ledger-frontend/src/types/ledger.ts (精確字串比對,只加一個欄位)
# =============================================================================

CURRENT=47

echo "===> [1/3] 自動歸檔已執行的 updateN.sh"
mkdir -p "update${CURRENT}"
for f in update*.sh; do
  [ "$f" = "update${CURRENT}.sh" ] && continue
  [ -f "$f" ] || continue
  git mv "$f" "update${CURRENT}/$f" 2>/dev/null || mv "$f" "update${CURRENT}/$f"
done
git add -A
if ! git diff --cached --quiet; then
  git commit -m "chore: 歸檔已執行的 updateN.sh 腳本"
  echo "    已歸檔並 commit"
else
  echo "    無需歸檔的舊腳本"
fi

echo "===> [2/3] 前置驗證:確認 update46.sh 已套用、且 ledger.ts 尚未修正"
if ! grep -q "is_self: bool = False" ledger-backend/app/schemas_ledger.py; then
  echo "❌ stats.py/schemas_ledger.py 尚未包含 update46.sh 的改動,請先確認 update46.sh 是否已成功套用" >&2
  exit 1
fi

python3 << 'PYEOF'
import sys

path = "ledger-frontend/src/types/ledger.ts"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

old = """export interface CategoryBreakdownItem {
  category_id: string
  category_name: string
  amount: number
  percentage: number
  has_children: boolean
}"""

new = """export interface CategoryBreakdownItem {
  category_id: string
  category_name: string
  amount: number
  percentage: number
  has_children: boolean
  is_self: boolean
}"""

if old not in content:
    print("❌ ledger.ts 內容與預期不符(可能已經修正過,或內容跟預期不一致),中止不寫入任何檔案", file=sys.stderr)
    sys.exit(1)

content = content.replace(old, new, 1)
with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("    ledger.ts 修正完成")
PYEOF

echo "===> [3/3] Commit 本次修正"
git add ledger-frontend/src/types/ledger.ts

if git diff --cached --quiet; then
  echo "⚠️  沒有偵測到檔案差異,略過 commit"
else
  git commit -m "fix: 補上前端 CategoryBreakdownItem 型別缺少的 is_self 欄位,修正 vue-tsc 建置失敗"
fi

echo ""
echo "===> 完成,確認 commit 是否真的產生:"
git log --oneline -3
