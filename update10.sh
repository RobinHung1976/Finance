#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
FRONTEND=ledger-frontend
[ -d "$BACKEND" ] && [ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

python3 << 'PYEOF'
path = "ledger-frontend/src/views/DashboardView.vue"
with open(path) as f:
    content = f.read()

old = '''<router-link to="/members" style="font-size: 13px; color: var(--color-primary); text-decoration: none">
          成員管理
        </router-link>'''
new = '''<router-link to="/members" style="font-size: 13px; color: var(--color-primary); text-decoration: none">
          成員管理
        </router-link>
        <router-link
          v-if="auth.role === 'admin'"
          to="/audit-logs"
          style="font-size: 13px; color: var(--color-primary); text-decoration: none"
        >
          操作紀錄
        </router-link>'''

if old not in content:
    raise SystemExit("❌ 不符,請貼目前實際檔案內容")
content = content.replace(old, new)

with open(path, "w") as f:
    f.write(content)
print("✅ DashboardView.vue 已加入操作紀錄連結")
PYEOF

git add -A
git commit -m "feat: Dashboard 加入操作紀錄連結入口(admin only)"
echo "✅ 已 commit,請執行 'git push origin main',再到 server 跑 ./deploy.sh"