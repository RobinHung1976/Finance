#!/usr/bin/env bash
set -euo pipefail

# 固定在 repo 根目錄(~/apps)執行,跟 deploy.sh 同一層
cd "$(dirname "$0")"

BACKEND_DIR="ledger-backend"
ENV_FILE="$BACKEND_DIR/.env"
PURGE_SCRIPT="scripts/purge_household.py"

[ -d "$BACKEND_DIR" ] || { echo "❌ 找不到 $BACKEND_DIR,請確認在 ~/apps 目錄下執行"; exit 1; }
[ -f "$ENV_FILE" ] || { echo "❌ 找不到 $ENV_FILE"; exit 1; }
[ -f "$BACKEND_DIR/$PURGE_SCRIPT" ] || { echo "❌ 找不到 $BACKEND_DIR/$PURGE_SCRIPT"; exit 1; }

# ---------- 讀取 DATABASE_URL(去掉 SQLAlchemy 專用的 +psycopg2,psql 看不懂) ----------
RAW_URL=$(grep '^DATABASE_URL=' "$ENV_FILE" | head -1 | cut -d '=' -f2- | tr -d '"'"'"'')
if [ -z "$RAW_URL" ]; then
    echo "❌ 讀不到 DATABASE_URL,請確認 $ENV_FILE 內容"
    exit 1
fi
PSQL_URL=$(echo "$RAW_URL" | sed 's/+psycopg2//')

# ---------- 1. 列出可刪除(已封存)的帳本 ----------
echo "===== 目前已封存(可刪除)的帳本 ====="
ARCHIVED_LIST=$(psql "$PSQL_URL" -c "SELECT id, name, created_at FROM households WHERE is_active = false ORDER BY created_at;")
echo "$ARCHIVED_LIST"

ARCHIVED_COUNT=$(psql "$PSQL_URL" -t -A -c "SELECT count(*) FROM households WHERE is_active = false;")
if [ "$ARCHIVED_COUNT" -eq 0 ]; then
    echo ""
    echo "ℹ️  目前沒有任何已封存的帳本,沒有東西可以刪除。"
    echo "   請先在網頁上用該帳本的 admin 帳號封存後,再執行本腳本。"
    exit 0
fi

# ---------- 2. 輸入要刪除的帳本名稱 ----------
echo ""
read -rp "請輸入要刪除的帳本名稱:" TARGET_NAME

if [ -z "$TARGET_NAME" ]; then
    echo "❌ 未輸入名稱,已取消。"
    exit 1
fi

ESCAPED_NAME=$(echo "$TARGET_NAME" | sed "s/'/''/g")
MATCHES=$(psql "$PSQL_URL" -t -A -F'|' -c \
  "SELECT id, name FROM households WHERE is_active = false AND name = '$ESCAPED_NAME';")

if [ -z "$MATCHES" ]; then
    echo "❌ 找不到名稱為「$TARGET_NAME」且已封存的帳本,已取消。"
    echo "   (只有已封存 is_active=false 的帳本能被刪除,請確認名稱與封存狀態)"
    exit 1
fi

MATCH_COUNT=$(echo "$MATCHES" | grep -c .)
if [ "$MATCH_COUNT" -gt 1 ]; then
    echo "⚠️  找到 $MATCH_COUNT 筆同名且已封存的帳本,無法用名稱唯一定位,請改手動指定 id:"
    echo "$MATCHES" | awk -F'|' '{print "  - id=" $1 "  name=" $2}'
    echo "   改用: cd $BACKEND_DIR && python $PURGE_SCRIPT --household-id <上面其中一個 id>"
    exit 1
fi

TARGET_ID=$(echo "$MATCHES" | cut -d'|' -f1)

# ---------- 3. 二次確認(輸入帳本名稱) ----------
echo ""
echo "即將刪除帳本:$TARGET_NAME(id=$TARGET_ID)"
read -rp "請再次輸入帳本名稱「$TARGET_NAME」以確認刪除:" CONFIRM_NAME

if [ "$CONFIRM_NAME" != "$TARGET_NAME" ]; then
    echo "❌ 兩次輸入的名稱不一致,已取消,沒有任何資料被刪除。"
    exit 1
fi

# ---------- 執行刪除 ----------
# purge_household.py 內部還會再要求輸入一次帳本名稱做最終確認,
# 這裡用管線把剛才已經確認過的名稱帶進去,避免同一件事被問第三次。
echo ""
echo "===== 開始刪除 ====="
(
  cd "$BACKEND_DIR"
  # shellcheck disable=SC1091
  source venv/bin/activate
  echo "$TARGET_NAME" | python "$PURGE_SCRIPT" --household-id "$TARGET_ID" --execute
  deactivate
)

# ---------- 4. 列出刪除後的所有帳本狀態 ----------
echo ""
echo "===== 刪除後,目前所有帳本狀態 ====="
psql "$PSQL_URL" -c "SELECT id, name, is_active, created_at FROM households ORDER BY created_at;"
