"""
永久刪除已封存帳本(households)及其所有關聯資料。

安全機制:
- 只能刪除 is_active = False(已封存)的帳本,拒絕刪除使用中的帳本
- 預設 dry-run,只顯示即將刪除的資料統計,不會寫入任何異動
- --execute 才會真正執行,且需要手動輸入完整帳本名稱二次確認
- 全程單一 DB transaction,任何步驟失敗自動 rollback

刪除順序(刻意避開 Transaction.category_id 的 ON DELETE RESTRICT 限制):
    transactions 必須在 categories 之前刪除,否則資料庫會擋下 categories 的刪除。
    其餘資料表之間都是 ON DELETE CASCADE,沒有嚴格順序限制。

用法(需在 ledger-backend 目錄下,已啟動 venv,且能連上實際 DB):
    python scripts/purge_household.py --household-id <uuid>            # 預覽
    python scripts/purge_household.py --household-id <uuid> --execute  # 真正執行
"""
import argparse
import sys
from pathlib import Path

# 確保不論從哪個目錄執行,都能 import 到 ledger-backend/app
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.database import SessionLocal  # noqa: E402
from app.models import (  # noqa: E402
    Household,
    User,
    Account,
    Category,
    Transaction,
    Budget,
    Tag,
    AuditLog,
    PasswordResetToken,
)


def count_stats(db, household_id: str) -> dict:
    return {
        "members": db.query(User).filter(User.household_id == household_id).count(),
        "accounts": db.query(Account).filter(Account.household_id == household_id).count(),
        "categories": db.query(Category).filter(Category.household_id == household_id).count(),
        "transactions": db.query(Transaction).filter(Transaction.household_id == household_id).count(),
        "budgets": db.query(Budget).filter(Budget.household_id == household_id).count(),
        "tags": db.query(Tag).filter(Tag.household_id == household_id).count(),
        "audit_logs": db.query(AuditLog).filter(AuditLog.household_id == household_id).count(),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="永久刪除已封存帳本")
    parser.add_argument("--household-id", required=True, help="要刪除的 household id")
    parser.add_argument("--execute", action="store_true", help="真正執行刪除(預設僅 dry-run 預覽)")
    args = parser.parse_args()

    db = SessionLocal()
    try:
        household = db.get(Household, args.household_id)
        if household is None:
            print(f"❌ 找不到 household id = {args.household_id}")
            sys.exit(1)

        if household.is_active:
            print(f"❌ 帳本「{household.name}」目前仍在使用中(is_active=True),拒絕刪除。")
            print("   請先在網頁上封存此帳本,再執行本腳本。")
            sys.exit(1)

        stats = count_stats(db, household.id)

        print("=" * 50)
        print(f"帳本:{household.name}(id={household.id})")
        print(f"建立時間:{household.created_at}")
        print("即將刪除的資料:")
        for key, value in stats.items():
            print(f"  - {key}: {value} 筆")
        print("=" * 50)

        if not args.execute:
            print("ℹ️  這是預覽模式(dry-run),沒有任何資料被刪除。")
            print("   確認無誤後,加上 --execute 參數才會真正執行。")
            return

        print()
        print("⚠️  此操作無法復原!以上所有資料都會被永久刪除。")
        confirm_input = input(f"請輸入完整帳本名稱「{household.name}」以確認刪除:")
        if confirm_input != household.name:
            print("❌ 輸入的名稱不符,已取消,沒有任何資料被刪除。")
            sys.exit(1)

        # ---------- 依序刪除,避開 Transaction.category_id 的 ON DELETE RESTRICT ----------
        deleted_transactions = (
            db.query(Transaction)
            .filter(Transaction.household_id == household.id)
            .delete(synchronize_session=False)
        )
        deleted_budgets = (
            db.query(Budget)
            .filter(Budget.household_id == household.id)
            .delete(synchronize_session=False)
        )
        deleted_tags = (
            db.query(Tag)
            .filter(Tag.household_id == household.id)
            .delete(synchronize_session=False)
        )
        deleted_audit_logs = (
            db.query(AuditLog)
            .filter(AuditLog.household_id == household.id)
            .delete(synchronize_session=False)
        )
        # transactions 已刪除,此時刪 categories 不會違反 RESTRICT
        deleted_categories = (
            db.query(Category)
            .filter(Category.household_id == household.id)
            .delete(synchronize_session=False)
        )
        deleted_accounts = (
            db.query(Account)
            .filter(Account.household_id == household.id)
            .delete(synchronize_session=False)
        )

        user_ids = [u.id for u in db.query(User.id).filter(User.household_id == household.id)]
        deleted_reset_tokens = 0
        if user_ids:
            deleted_reset_tokens = (
                db.query(PasswordResetToken)
                .filter(PasswordResetToken.user_id.in_(user_ids))
                .delete(synchronize_session=False)
            )
        deleted_users = (
            db.query(User)
            .filter(User.household_id == household.id)
            .delete(synchronize_session=False)
        )

        db.delete(household)
        db.commit()

        print()
        print("✅ 刪除完成:")
        print(f"  - transactions: {deleted_transactions}")
        print(f"  - budgets: {deleted_budgets}")
        print(f"  - tags: {deleted_tags}")
        print(f"  - audit_logs: {deleted_audit_logs}")
        print(f"  - categories: {deleted_categories}")
        print(f"  - accounts: {deleted_accounts}")
        print(f"  - password_reset_tokens: {deleted_reset_tokens}")
        print(f"  - users: {deleted_users}")
        print(f"  - household「{household.name}」已永久刪除")

    except Exception as e:
        db.rollback()
        print(f"❌ 發生錯誤,已 rollback,沒有任何資料被刪除:{e}")
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    main()
