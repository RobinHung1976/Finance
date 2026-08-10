#!/usr/bin/env bash
set -euo pipefail

# ========================================
# update48.sh
# 新增:管理員手動重設密碼 CLI(ledger-backend/reset_password.py)
# 背景:忘記密碼信件功能入口暫停,管理員需要臨時手動重設使用者密碼的方式
# ========================================

# ---- 0. 自動歸檔(固定寫法,與功能改動分開 commit) ----
CURRENT=48
mkdir -p "update${CURRENT}"
for f in update*.sh; do
  [ "$f" = "update${CURRENT}.sh" ] && continue
  [ -f "$f" ] || continue
  git mv "$f" "update${CURRENT}/$f" 2>/dev/null || mv "$f" "update${CURRENT}/$f"
done
git add -A
if ! git diff --cached --quiet; then
  git commit -m "chore: 歸檔已執行的 updateN.sh 腳本"
fi

# ---- 1. 新增檔案:ledger-backend/reset_password.py(全新檔案,完整覆寫) ----
cat > ledger-backend/reset_password.py << 'PYEOF'
"""
管理員手動重設使用者密碼 CLI

用途:忘記密碼信件功能暫時不可用期間,由管理員直接於 server 端執行,
      為指定使用者產生新密碼並寫入 DB。

用法:
    cd ledger-backend
    source venv/bin/activate
    python reset_password.py <username> <新密碼>

已依實際 models.py / auth.py / households.py 核對:
    - User model:app.models.User,查詢鍵用 username(唯一鍵)
    - 密碼雜湊:app.security.hash_password,與 auth.py 的 register/reset-password 邏輯一致
    - 稽核紀錄:直接寫入 AuditLog model(未呼叫 app.audit.log_action,
      因為該函式內部如何從 user 物件組出 household_id/actor_name 未知,
      CLI 場景也沒有 current_user 可傳,直接指定欄位語意更明確)
"""
import sys

from app.database import SessionLocal
from app.models import AuditLog, User
from app.security import hash_password


def reset_password(username: str, new_password: str) -> None:
    if len(new_password) < 8:
        print("❌ 新密碼長度至少需 8 碼", file=sys.stderr)
        sys.exit(1)

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.username == username).first()
        if user is None:
            print(f"❌ 找不到 username={username} 的使用者", file=sys.stderr)
            sys.exit(1)

        user.password_hash = hash_password(new_password)

        db.add(AuditLog(
            household_id=user.household_id,
            user_id=None,  # 操作者是管理員 CLI,非本人操作,不歸給被改密碼的使用者
            action="update",
            resource_type="user",
            resource_id=user.id,
            detail=f"管理員透過 CLI 手動重設密碼：{username}",
            actor_name="admin-cli",
        ))

        db.commit()
        print(f"✅ 已重設使用者 {username}(household_id={user.household_id})的密碼")
    except Exception as e:
        db.rollback()
        print(f"❌ 執行失敗,未寫入任何變更:{e}", file=sys.stderr)
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("用法:python reset_password.py <username> <新密碼>", file=sys.stderr)
        sys.exit(1)

    reset_password(sys.argv[1], sys.argv[2])
PYEOF

# ---- 2. commit(feat,與歸檔分開) ----
git add ledger-backend/reset_password.py
git commit -m "feat: 新增管理員手動重設密碼 CLI(reset_password.py)"

# ---- 3. 確認 commit 真的產生(務必執行,不能只看終端機有無錯誤字樣) ----
echo "---- git log --oneline -1 ----"
git log --oneline -1
