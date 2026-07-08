#!/usr/bin/env bash
set -euo pipefail

FRONTEND=ledger-frontend
[ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

echo "=== update38.sh:修正 api/ledger.ts 缺少 TagBreakdownOut import ==="

# ---------- 0. 自動歸檔 ----------
mkdir -p updateN
CURRENT=38
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

# ---------- 1. 修正 import ----------
python3 << 'PYEOF'
import re

path = "ledger-frontend/src/api/ledger.ts"
with open(path) as f:
    content = f.read()

if "TagBreakdownOut" in content and re.search(r"import\s+type?\s*\{[^}]*TagBreakdownOut[^}]*\}\s*from\s*['\"]@/types/ledger['\"]", content):
    print("⏭  TagBreakdownOut 已在 import 區塊,略過")
else:
    # 找出所有從 @/types/ledger import 的那一行(可能是 import type {...} 或 import {...})
    pattern = re.compile(r"^import\s+(type\s+)?\{([^}]*)\}\s*from\s*['\"]@/types/ledger['\"]\s*;?\s*$", re.MULTILINE)
    match = pattern.search(content)

    if match:
        existing_names = match.group(2)
        new_names = existing_names.rstrip() + ", TagBreakdownOut"
        new_line = f"import {match.group(1) or ''}{{{new_names} }} from '@/types/ledger'"
        content = content[:match.start()] + new_line + content[match.end():]
        with open(path, "w") as f:
            f.write(content)
        print("✅ 已將 TagBreakdownOut 附加進既有 import 區塊")
        print(f"   修改後該行內容:{new_line}")
    else:
        # 找不到既有的 @/types/ledger import,直接在檔案最前面新增一行
        new_import = "import type { TagBreakdownOut } from '@/types/ledger'\n"
        content = new_import + content
        with open(path, "w") as f:
            f.write(content)
        print("⚠️  找不到既有的 '@/types/ledger' import 行,已在檔案最前面新增獨立 import")
        print("   請人工確認檔案開頭沒有變成重複 import 或位置不理想")
PYEOF

echo ""
echo "=== 請人工核對修改後的 import 區塊 ==="
head -15 ledger-frontend/src/api/ledger.ts

git add -A
git commit -m "fix: api/ledger.ts 補上缺少的 TagBreakdownOut import"
echo "✅ 已 commit"
git log --oneline -3