# 第二期 A1+A2:月收支趨勢圖 + 結餘計算

建立日期:2026-07-07

## 一、範圍

對照 `finance-1st-core-feature-20260706.md` 第三節統計功能清單:
- A1:每月收入/支出趨勢圖(近 6-12 個月)
- A2:結餘計算(收入 - 支出)

## 二、後端變更

### 新增檔案
- `app/routers/stats.py`:`GET /stats/monthly-trend?months=12`

### 技術重點
- 用 DB 層 `date_trunc('month', ...)` + `group by` 彙總,不把整年交易拉回 Python 迭代
- 缺資料的月份補 0(先建立完整月份骨架),避免前端圖表出現斷點
- A2(結餘)直接內含在同一支 API 回應裡(`total_balance`),沒有另開 endpoint

### 修改檔案
- `app/schemas_ledger.py`:新增 `MonthlySummary`、`MonthlyTrendOut`
- `app/main.py`:註冊 `stats.router`
- `requirements.txt`:新增 `python-dateutil`(`relativedelta` 用)

## 三、前端變更

### 新增檔案
- `src/components/MonthlyTrendChart.vue`:折線圖(收入/支出)+ 結餘卡片,原生 Chart.js(非 vue-chartjs,減少依賴)

### 修改檔案
- `src/api/ledger.ts` / `src/types/ledger.ts`:新增 `fetchMonthlyTrend` 與對應型別
- `src/views/DashboardView.vue`:新增「統計」分頁,設為預設頁
- `package.json`:新增 `chart.js`

## 四、部署基礎建設(本次功能連帶完成的架構調整)

原本前端是 `vite --host` dev server 直接對外曝露,趁這次上線一併轉正式架構:

| 項目 | 調整內容 |
|---|---|
| 前端 | 轉 `vite build`,由 Nginx serve 靜態檔,不再跑 node process |
| Nginx | 單一入口,靜態檔 + API reverse proxy 同一個 origin,前端呼叫改用相對路徑,拿掉 CORS 依賴 |
| 對外連線 | 原規劃 Cloudflare Tunnel 已暫停,改用 FortiGate VIP 對外,詳見下方「對外連線」 |
| Port | 對外 `17756` → FortiGate DNAT → 內部 Nginx `17756`(細節詳見待建立的 infra 文件) |

> **建議**:上表這塊其實跟「統計功能」本身無關,是部署架構的變更,建議另外抽成 `infra-public-access-20260707.md`,詳見本文件最後一節建議。

## 五、Bug 修復紀錄

### 1. Alembic migration 遺失(`abb9d370cb81` 找不到)
- 詳細原因與修復過程見獨立文件:`migration-history-20260706.md`
- 本次影響:部署腳本因此新增防呆機制(見下方 deploy.sh)

### 2. TypeScript 型別錯誤:`formatCurrency` 不接受 `null`
- **原因**:Chart.js tooltip callback 的 `ctx.parsed.y` 型別是 `number | null`,原函式簽名只接受 `number`
- **修正**:
```typescript
function formatCurrency(value: number | null): string {
  if (value === null) return '-'
  return value.toLocaleString('zh-TW', { style: 'currency', currency: 'TWD', maximumFractionDigits: 0 })
}
```
- **踩坑紀錄**:多次用 `sed`/字串比對式的 patch 修正都靜默失敗或被還原,最終改用「整份檔案覆寫 + md5 checksum 驗證」才確認修正確實生效。根本原因不明確(懷疑終端機貼上內容混到舊 scrollback,或有其他 process 寫回舊版檔案),**後續若重演建議直接排查是否有其他人/腳本在同一時間操作同一個檔案**

### 3. `deploy.sh` 缺少 `mkdir -p "$WEB_ROOT"`
- **原因**:把部署方式從 zip-based 改寫成 git-based 時,漏帶原本 zip 版本裡的 `mkdir -p`
- **現象**:`/var/www/ledger-frontend` 目錄不存在,`cp` 失敗,Nginx 回 403/500
- **修正**:已在 `deploy.sh` 補回,並清除因手動補救造成的重複行

## 六、目前 `deploy.sh`(git-based,含 migration 防呆)

```bash
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
```

## 七、目前狀態

- ✅ 後端 `/stats/monthly-trend` 已上線
- ✅ 前端「統計」分頁已顯示折線圖 + 結餘卡片
- ✅ `curl` 驗證:`frontend: 200`、`backend health: 200`
- ⏳ 待瀏覽器實測圖表實際渲染狀況(登入後看「統計」分頁)

## 八、下一步

- A3:分類統計(圓餅/甜甜圈圖)—— 需先確認 `categories.py` 現有的分類查詢邏輯,決定是否新增遞迴 CTE
- 建議把「部署基礎建設」(第四節)拆成獨立文件,見下方建議

## 九、文件拆分建議

目前這份文件混了兩件事:「統計功能開發」與「部署基礎建設轉正式環境」。建議拆成:
- `finance-2nd-A1-A2-20260707.md`(本檔,只留功能開發 + bug 修復)
- `infra-public-access-20260707.md`(新增,只留 Nginx + FortiGate + 對外連線相關設定)

這樣之後 A3、A4...等後續功能文件,可以直接引用 infra 文件,不用每份都重複貼一次部署架構。
