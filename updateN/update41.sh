#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
[ -d "$BACKEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

echo "=== update41.sh:修正 schemas_ledger.py 缺少 date import ==="

# ---------- 0. 自動歸檔 ----------
mkdir -p updateN
CURRENT=41
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

# ---------- 1. 檢查並修正 date import ----------
python3 << 'PYEOF'
import re

path = "ledger-backend/app/schemas_ledger.py"
with open(path) as f:
    content = f.read()

# 情況 A:已有 "from datetime import ..." 但沒有 date
pattern = re.compile(r"^from datetime import (.+)$", re.MULTILINE)
match = pattern.search(content)

if match:
    names = [n.strip() for n in match.group(1).split(",")]
    if "date" in names:
        print("⏭  已有 'from datetime import date',無需修改")
    else:
        names.append("date")
        new_line = f"from datetime import {', '.join(names)}"
        content = content[:match.start()] + new_line + content[match.end():]
        with open(path, "w") as f:
            f.write(content)
        print(f"✅ 已補上 date:{new_line}")
else:
    # 情況 B:完全沒有 datetime import,插入檔案最前面
    content = "from datetime import date\n" + content
    with open(path, "w") as f:
        f.write(content)
    print("⚠️  找不到既有的 'from datetime import ...',已在檔案最前面新增獨立 import")
    print("   請人工確認檔案開頭沒有變成重複 import 或位置不理想")
PYEOF

echo ""
echo "=== 修正後 schemas_ledger.py 前 15 行(供核對)==="
head -15 ledger-backend/app/schemas_ledger.py

# ---------- 2. 保險:全檔案掃描其他可能未定義的殘留名稱 ----------
echo ""
echo "=== 檢查 TagBreakdownItem/TagBreakdownOut 是否還有其他未定義風險 ==="
grep -n "EntryType\|date\b" ledger-backend/app/schemas_ledger.py | tail -20

git add -A
git commit -m "fix: schemas_ledger.py 補上缺少的 date import"
echo "✅ 已 commit"
git log --oneline -3