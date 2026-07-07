#!/usr/bin/env bash
set -euo pipefail

APPS_DIR=/root/apps
WEB_ROOT=/var/www/ledger-frontend

cd "$APPS_DIR"

# ---------- Pull 最新版 ----------
git fetch origin
git reset --hard origin/main

# ---------- 防呆:確認 migration 檔案存在 ----------
migration_count=$(find ledger-backend/alembic/versions -name "*.py" | wc -l)
if [ "$migration_count" -eq 0 ]; then
    echo "ERROR: alembic/versions/ 沒有任何 migration 檔案,拒絕部署" >&2
    exit 1
fi
echo "確認 migration 檔案數量: $migration_count"

# ---------- Backend ----------
systemctl stop ledger-api

cd ledger-backend
[ -d venv ] || python3 -m venv venv
source venv/bin/activate
pip install -q -r requirements.txt
alembic upgrade head
deactivate

systemctl start ledger-api
cd ..

# ---------- Frontend ----------
cd ledger-frontend
npm install
npm run build

mkdir -p "$WEB_ROOT"
rm -rf "${WEB_ROOT:?}"/*
cp -r dist/* "$WEB_ROOT"/
cd ..

nginx -t && systemctl reload nginx

# ---------- Health check ----------
echo "--- ledger-api ---"
systemctl is-active ledger-api
echo "--- nginx :17756 ---"
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:17756/
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:17756/health
