#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
[ -d "$BACKEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

python3 << 'PYEOF'
path = "ledger-backend/app/services/excel_transfer.py"
with open(path) as f:
    content = f.read()

old_import = "from app.models import Category, Transaction, EntryType"
new_import = "from app.models import Account, Category, Transaction, EntryType"
if old_import not in content:
    raise SystemExit("❌ import 錨點不符,請人工檢查")
content = content.replace(old_import, new_import, 1)

old_init = """    imported = 0
    skipped_duplicates = 0
    created_categories = 0"""
new_init = """    imported = 0
    skipped_duplicates = 0
    created_categories = 0
    balance_delta = 0.0  # 累計這批匯入對帳戶餘額的淨影響(收入+/支出-)"""
if old_init not in content:
    raise SystemExit("❌ 初始化變數錨點不符")
content = content.replace(old_init, new_init, 1)

old_write = """        if not forced:
            seen_in_batch.add(dedupe_key)
        if not dry_run and category_id_for_tx:
            db.add(Transaction(
                household_id=household_id, user_id=user_id, account_id=account_id,
                category_id=category_id_for_tx, amount=parsed["amount"],
                type=parsed["type"], date=parsed["date"], note=None,
            ))
            imported += 1

    if not dry_run:
        db.commit()"""
new_write = """        if not forced:
            seen_in_batch.add(dedupe_key)
        if not dry_run and category_id_for_tx:
            db.add(Transaction(
                household_id=household_id, user_id=user_id, account_id=account_id,
                category_id=category_id_for_tx, amount=parsed["amount"],
                type=parsed["type"], date=parsed["date"], note=None,
            ))
            imported += 1
            if parsed["type"] == EntryType.income:
                balance_delta += parsed["amount"]
            else:
                balance_delta -= parsed["amount"]

    if not dry_run:
        if balance_delta != 0:
            account = db.get(Account, account_id)
            account.balance = float(account.balance) + balance_delta
        db.commit()"""
if old_write not in content:
    raise SystemExit("❌ Transaction 寫入區塊錨點不符,請人工檢查")
content = content.replace(old_write, new_write, 1)

with open(path, "w") as f:
    f.write(content)
print("✅ excel_transfer.py: process_import 已補上帳戶餘額更新邏輯")
PYEOF

git add -A
git commit -m "fix: Excel 匯入交易時漏更新 Account.balance,導致帳戶餘額與交易紀錄總額對不起來"
echo "✅ 已 commit,請 push + deploy"