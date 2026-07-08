#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
[ -d "$BACKEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

python3 << 'PYEOF'
path = "ledger-backend/app/routers/transactions_transfer.py"
with open(path) as f:
    content = f.read()

old_import = "from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException"
new_import = "from urllib.parse import quote\n\nfrom fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException"
if old_import not in content:
    raise SystemExit("❌ import 錨點不符,請人工檢查")
content = content.replace(old_import, new_import, 1)

old_export = '''    buf = build_export_workbook(db, current_user.household_id, year)
    filename = f"{year}-記帳表.xlsx"
    return StreamingResponse(
        buf,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )'''
new_export = '''    buf = build_export_workbook(db, current_user.household_id, year)
    filename = f"{year}-記帳表.xlsx"
    ascii_fallback = f"{year}-ledger-export.xlsx"
    encoded_filename = quote(filename)
    return StreamingResponse(
        buf,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition": (
                f'attachment; filename="{ascii_fallback}"; '
                f"filename*=UTF-8''{encoded_filename}"
            )
        },
    )'''
if old_export not in content:
    raise SystemExit("❌ export_excel 錨點不符,請人工檢查")
content = content.replace(old_export, new_export, 1)

with open(path, "w") as f:
    f.write(content)
print("✅ transactions_transfer.py: Content-Disposition 檔名改用 RFC 5987 UTF-8 編碼,修正中文檔名導致 latin-1 編碼錯誤")
PYEOF

git add -A
git commit -m "fix: Content-Disposition header 塞入中文檔名導致 UnicodeEncodeError('latin-1' codec無法編碼中文),改用 RFC 5987 UTF-8 檔名編碼並提供 ASCII 備援檔名"
echo "✅ 已 commit,請 push + deploy"