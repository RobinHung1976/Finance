"""
重新計算並回補帳戶餘額(Account.balance)。

背景:
    bug-fix-20260708-excel-import-export.md 記錄的 bug 1 —— Excel 匯入功能上線後一段時間,
    process_import() 沒有同步更新 Account.balance,導致匯入的交易在交易紀錄看得到,
    但帳戶餘額沒有對應增減。程式碼已修正(僅影響之後的匯入),本腳本用來回補「修正前」
    已匯入、餘額未正確反映的歷史資料。

計算方式:
    正確餘額 = 該帳戶所有交易「收入」金額加總 - 「支出」金額加總
    (與 bug-fix 文件「後續可考慮事項」第 1 點所寫的重算方式一致)

安全機制:
- 預設 dry-run,只顯示每個帳戶「目前餘額」vs「重新計算後應該是多少」的差異,不寫入任何異動
- --execute 才會真正寫入,且只更新「有差異」的帳戶,沒有差異的帳戶不會被觸碰
- 可用 --account-id 限定只處理單一帳戶,或用 --household-id 限定單一帳本,不帶參數則檢查全部帳戶
- 全程單一 DB transaction,任何步驟失敗自動 rollback

用法(需在 ledger-backend 目錄下,已啟動 venv,且能連上實際 DB):
    python scripts/recalc_account_balances.py                              # 預覽:檢查所有帳戶
    python scripts/recalc_account_balances.py --household-id <uuid>        # 預覽:只檢查某帳本
    python scripts/recalc_account_balances.py --account-id <uuid>          # 預覽:只檢查單一帳戶
    python scripts/recalc_account_balances.py --execute                   # 真正回補所有有差異的帳戶
"""
import argparse
import sys
from decimal import Decimal
from pathlib import Path

# 確保不論從哪個目錄執行,都能 import 到 ledger-backend/app
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import func  # noqa: E402

from app.database import SessionLocal  # noqa: E402
from app.models import Account, EntryType, Transaction  # noqa: E402


def compute_correct_balance(db, account_id: str) -> Decimal:
    income_total = (
        db.query(func.coalesce(func.sum(Transaction.amount), 0))
        .filter(Transaction.account_id == account_id, Transaction.type == EntryType.income)
        .scalar()
    )
    expense_total = (
        db.query(func.coalesce(func.sum(Transaction.amount), 0))
        .filter(Transaction.account_id == account_id, Transaction.type == EntryType.expense)
        .scalar()
    )
    return Decimal(income_total) - Decimal(expense_total)


def main() -> None:
    parser = argparse.ArgumentParser(description="重新計算並回補帳戶餘額")
    parser.add_argument("--account-id", help="只檢查/回補單一帳戶")
    parser.add_argument("--household-id", help="只檢查/回補單一帳本底下的所有帳戶")
    parser.add_argument("--execute", action="store_true", help="真正寫入回補(預設僅 dry-run 預覽)")
    args = parser.parse_args()

    if args.account_id and args.household_id:
        print("❌ --account-id 與 --household-id 不能同時使用,請只擇一")
        sys.exit(1)

    db = SessionLocal()
    try:
        query = db.query(Account)
        if args.account_id:
            query = query.filter(Account.id == args.account_id)
        elif args.household_id:
            query = query.filter(Account.household_id == args.household_id)

        accounts = query.order_by(Account.household_id, Account.name).all()

        if not accounts:
            print("ℹ️  沒有符合條件的帳戶。")
            return

        print("=" * 70)
        print(f"{'帳戶':<20}{'目前餘額':>14}{'正確餘額':>14}{'差異':>14}")
        print("-" * 70)

        mismatches = []
        for account in accounts:
            correct = compute_correct_balance(db, account.id)
            current = Decimal(account.balance)
            diff = correct - current
            flag = "  ⚠️ 不符" if diff != 0 else ""
            print(f"{account.name:<20}{current:>14}{correct:>14}{diff:>14}{flag}")
            if diff != 0:
                mismatches.append((account, current, correct, diff))

        print("=" * 70)
        print(f"共檢查 {len(accounts)} 個帳戶,發現 {len(mismatches)} 個餘額不符。")

        if not mismatches:
            print("✅ 沒有需要回補的帳戶。")
            return

        if not args.execute:
            print()
            print("ℹ️  這是預覽模式(dry-run),沒有任何資料被寫入。")
            print("   確認無誤後,加上 --execute 參數才會真正回補。")
            return

        print()
        print(f"⚠️  即將回補以上 {len(mismatches)} 個帳戶的餘額,此操作會覆蓋 Account.balance 目前的值。")
        confirm = input("輸入 yes 以確認執行:")
        if confirm.strip().lower() != "yes":
            print("❌ 已取消,沒有任何資料被寫入。")
            sys.exit(1)

        for account, current, correct, diff in mismatches:
            account.balance = correct
        db.commit()

        print()
        print("✅ 回補完成:")
        for account, current, correct, diff in mismatches:
            print(f"  - {account.name}: {current} → {correct}(差異 {diff:+})")

    except Exception as e:
        db.rollback()
        print(f"❌ 發生錯誤,已 rollback,沒有任何資料被寫入:{e}")
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    main()
