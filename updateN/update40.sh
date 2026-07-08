#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
[ -d "$BACKEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

echo "=== update40.sh:修正 schemas_ledger.py 的 TransactionType 未定義問題 ==="

# ---------- 0. 自動歸檔 ----------
mkdir -p updateN
CURRENT=40
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

# ---------- 1. 修正 schemas_ledger.py ----------
python3 << 'PYEOF'
path = "ledger-backend/app/schemas_ledger.py"
with open(path) as f:
    content = f.read()

old = "    type: TransactionType\n    start_date: date\n    end_date: date"
new = "    type: EntryType\n    start_date: date\n    end_date: date"

if old not in content:
    raise SystemExit("❌ 找不到預期字串,請人工確認 schemas_ledger.py 中 TagBreakdownOut 的內容")

content = content.replace(old, new)

with open(path, "w") as f:
    f.write(content)
print("✅ schemas_ledger.py:TagBreakdownOut.type 已修正為 EntryType")
PYEOF

# ---------- 2. 保險:全檔案掃描,確認沒有其他殘留的 TransactionType ----------
if grep -rn "TransactionType" ledger-backend/app/ 2>/dev/null; then
  echo ""
  echo "⚠️  上面列出的行仍包含 TransactionType,可能還有殘留,請人工確認是否需要處理"
else
  echo "✅ 全專案已無 TransactionType 殘留"
fi

echo ""
echo "=== 修正後的 TagBreakdownOut 區塊 ==="
grep -A5 "class TagBreakdownOut" ledger-backend/app/schemas_ledger.py

git add -A
git commit -m "fix: schemas_ledger.py TagBreakdownOut 使用未定義的 TransactionType,修正為 EntryType"
echo "✅ 已 commit"
git log --oneline -3