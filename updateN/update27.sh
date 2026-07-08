#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
[ -d "$BACKEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

python3 << 'PYEOF'
path = "ledger-backend/app/routers/transactions_transfer.py"
with open(path) as f:
    content = f.read()

old_import = "from app.deps import get_current_user, get_db"
new_import = "from app.deps import get_current_user, get_db\nfrom app.models import Household"
if old_import not in content:
    raise SystemExit("❌ import 錨點不符,請人工檢查")
content = content.replace(old_import, new_import, 1)

old_export = '''    buf = build_export_workbook(db, current_user.household_id, year)
    filename = f"{year}-記帳表.xlsx"
    ascii_fallback = f"{year}-ledger-export.xlsx"'''
new_export = '''    buf = build_export_workbook(db, current_user.household_id, year)
    household = db.get(Household, current_user.household_id)
    household_name = household.name if household else "記帳表"
    filename = f"{year}-{household_name}.xlsx"
    ascii_fallback = f"{year}-ledger-export.xlsx"'''
if old_export not in content:
    raise SystemExit("❌ export_excel 錨點不符,請人工檢查(可能因上次修改內容已變動)")
content = content.replace(old_export, new_export, 1)

with open(path, "w") as f:
    f.write(content)
print("✅ transactions_transfer.py: 匯出檔名改用「年份-帳本名稱.xlsx」")
PYEOF

git add -A
git commit -m "feat: Excel 匯出檔名改用「年份-帳本名稱」,取代原本固定的「記帳表」文字"
echo "✅ 已 commit,請 push + deploy"