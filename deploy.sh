#!/usr/bin/env bash
set -euo pipefail

APPS_DIR=/root/apps
WEB_ROOT=/var/www/ledger-frontend

# ---------- 防呆:部署前檢查 zip 裡的 migration 檔案是否完整 ----------
migration_count=$(unzip -l "$APPS_DIR/ledger-backend.zip" | grep -c "alembic/versions/.*\.py$" || true)
if [ "$migration_count" -eq 0 ]; then
    echo "ERROR: ledger-backend.zip 裡 alembic/versions/ 沒有任何 migration 檔案,拒絕部署" >&2
    echo "上次事故就是這樣搞丟 abb9d370cb81,先確認 zip 內容再重跑" >&2
    exit 1
fi
echo "確認 migration 檔案數量: $migration_count"

# ---------- Backend ----------
cp "$APPS_DIR/ledger-backend/.env" /tmp/ledger-backend.env.bak
# 額外備份現有 alembic/versions,萬一新 zip 漏檔還有得救
cp -r "$APPS_DIR/ledger-backend/alembic/versions" /tmp/ledger-backend-versions.bak

systemctl stop ledger-api

cd "$APPS_DIR"
rm -rf ledger-backend
unzip -q ledger-backend.zip
cp /tmp/ledger-backend.env.bak ledger-backend/.env

cd ledger-backend
[ -d venv ] || python3 -m venv venv
source venv/bin/activate
pip install -q -r requirements.txt
alembic upgrade head
deactivate

systemctl start ledger-api

# ---------- Frontend ----------
pkill -f "vite --host" || true

cd "$APPS_DIR"
rm -rf ledger-frontend
unzip -q ledger-frontend.zip
cd ledger-frontend
npm install
npm run build

mkdir -p "$WEB_ROOT"
rm -rf "${WEB_ROOT:?}"/*
cp -r dist/* "$WEB_ROOT"/

nginx -t && systemctl reload nginx

echo "--- ledger-api ---"
systemctl is-active ledger-api
echo "--- nginx :17756 ---"
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:17756/
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:17756/health
