#!/usr/bin/env bash
set -euo pipefail

FRONTEND=ledger-frontend
[ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

echo "=== update39.sh:修正 update38.sh 造成的 import 語法錯誤(重複逗號) ==="

# ---------- 0. 自動歸檔 ----------
mkdir -p updateN
CURRENT=39
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

# ---------- 1. 修正 import 區塊的重複逗號 ----------
python3 << 'PYEOF'
import re

path = "ledger-frontend/src/api/ledger.ts"
with open(path) as f:
    content = f.read()

# 找出從 @/types/ledger import 的那一行
pattern = re.compile(r"^import\s+(type\s+)?\{([^}]*)\}\s*from\s*['\"]@/types/ledger['\"]\s*;?\s*$", re.MULTILINE)
match = pattern.search(content)

if not match:
    raise SystemExit("❌ 找不到 @/types/ledger 的 import 行,請人工確認檔案內容")

names_raw = match.group(2)
# 拆解成獨立名稱,過濾空字串,去除重複,保留原順序
names = [n.strip() for n in names_raw.split(",")]
names = [n for n in names if n]  # 去掉空字串(重複逗號造成的)
seen = set()
unique_names = []
for n in names:
    if n not in seen:
        seen.add(n)
        unique_names.append(n)

new_names = ", ".join(unique_names)
new_line = f"import {match.group(1) or ''}{{ {new_names} }} from '@/types/ledger'"

content = content[:match.start()] + new_line + content[match.end():]

with open(path, "w") as f:
    f.write(content)

print("✅ import 行已修正")
print(f"   修改後:{new_line}")
PYEOF

echo ""
echo "=== 修正後的 import 區塊(前 15 行) ==="
head -15 ledger-frontend/src/api/ledger.ts

git add -A
git commit -m "fix: 修正 api/ledger.ts import 語法錯誤(重複逗號)"
echo "✅ 已 commit"
git log --oneline -3