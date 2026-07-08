#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
[ -d "$BACKEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

python3 << 'PYEOF'
path = "ledger-backend/app/services/excel_transfer.py"
with open(path) as f:
    content = f.read()

old = '''def _excel_serial_to_date(value) -> date:
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    return (EXCEL_EPOCH + timedelta(days=float(value))).date()'''

new = '''def _excel_serial_to_date(value) -> date:
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    # 可能是使用者手動打成 YYYYMMDD 整數格式(例如 20260708),而非真正的 Excel 日期
    if isinstance(value, (int, float)) and float(value) == int(value):
        ival = int(value)
        if 19000101 <= ival <= 99991231:
            try:
                return datetime.strptime(str(ival), "%Y%m%d").date()
            except ValueError:
                pass  # 不是合法日期(例如 20261332),繼續往下當 Excel 序列值處理
    # 一般情況:Excel 序列值(距離 1899-12-30 的天數)
    return (EXCEL_EPOCH + timedelta(days=float(value))).date()'''

if old not in content:
    raise SystemExit("❌ _excel_serial_to_date 錨點不符,請人工檢查")
content = content.replace(old, new, 1)

old_validate = '''    try:
        tx_date = _excel_serial_to_date(raw["date_raw"])
    except (TypeError, ValueError):
        return None, f"日期格式錯誤: {raw['date_raw']!r}"'''
new_validate = '''    try:
        tx_date = _excel_serial_to_date(raw["date_raw"])
    except (TypeError, ValueError, OverflowError):
        return None, f"日期格式錯誤: {raw['date_raw']!r}"'''
if old_validate not in content:
    raise SystemExit("❌ _validate_row 錨點不符,請人工檢查")
content = content.replace(old_validate, new_validate, 1)

with open(path, "w") as f:
    f.write(content)
print("✅ excel_transfer.py: 支援 YYYYMMDD 整數日期格式,並補上 OverflowError 攔截")
PYEOF

git add -A
git commit -m "fix: 日期欄位為 YYYYMMDD 整數格式(如 20260708)時誤判成 Excel 序列值導致 OverflowError,新增格式判斷並補上例外攔截"
echo "✅ 已 commit,請 push + deploy"
