# 部署流程

## 一、整體部署方式:Git-based(`updateN.sh` + `deploy.sh`)

改用 Git 追蹤原始碼取代逐檔覆蓋/整包 zip 替換,避免檔案遺失(如 migration 檔案曾在 zip 打包時遺失)、`.env` 忘記還原等風險。

- Repo:`RobinHung1976/Finance`(monorepo,`ledger-backend/` + `ledger-frontend/`)
- 本機改 → `updateN.sh` 覆寫檔案 + commit → `git push` → server 端 `./deploy.sh`
- **禁止**在 server 上直接手動改任何程式檔案(`sed`/vim 皆算),下次 `deploy.sh` 的 `git reset --hard` 會蓋掉

## 二、`updateN.sh` 撰寫與執行 SOP

### 核心原則

1. **動手寫前,先看過所有要改動的檔案目前實際內容**,不依賴記憶或聊天紀錄裡的舊版本;牽涉多個檔案(前端+後端+型別定義)全部都要先看過
2. **改動範圍大 → 完整覆寫**(`cat > path << 'EOF'`);**改動範圍小(1-2 處)→ `python3` 精確字串比對**,對不上直接中止(不用 `sed`,對特殊字元易誤判)
3. 同一支腳本內若對同一檔案有多個修改步驟,**後面步驟的比對字串要以「前面步驟執行完之後」的狀態為準**,不能假設是原始內容(曾發生前面步驟已改了 import 路徑,後面步驟比對字串仍寫舊路徑而中止)
4. 若腳本建立在**前一支 `updateN-1.sh` 已套用**的假設上,腳本開頭固定加入「前置驗證」:`grep` 前一支應留下的特徵字串,對不上就直接中止,不寫入任何檔案
5. 若依賴假設無法直接用檔案核對(如 DB 欄位名稱),同樣在腳本最前面加前置驗證(`python3 -c "..."` 檢查 ORM 欄位是否存在),驗證不過不寫入任何檔案
6. 每支腳本開頭固定執行「自動歸檔」(把非本次編號的 `updateM.sh` 搬進 `updateN/` 資料夾),且與功能改動**分開 commit**(`chore:` vs `feat:`/`fix:`),避免 `git log` 被檔案搬移雜訊淹沒
7. **重跑修正腳本**時,對於上一次執行可能已建立的**全新檔案**,一律用完整覆寫處理,不假設它們不存在或內容乾淨——`git reset --hard` 只會還原**已追蹤**的檔案,對 untracked 新檔案完全不會動,腳本中止時容易造成「已追蹤改動被還原、但新檔案殘留」的半殘留狀態
8. 執行完 `updateN.sh` 後,**務必 `git log --oneline -1` 確認 commit 真的產生**(建議腳本結尾自動印出),不能只看終端機有沒有印出錯誤字樣就假設成功
9. 每支腳本附上明確的「驗證重點清單」給使用者核對(畫面新元素、操作結果、容易被波及但**不應該**受影響的既有功能)
10. bug 回報描述含糊時(如「點了不能修改」),先確認使用者實際點的是哪個元件,不要先動手改
11. 功能驗證通過、確定不會再改之後,補一份格式一致的 `md` 文件記錄決策脈絡(不需邊做邊寫)
12. `push` 與 `deploy.sh` 執行步驟刻意保留手動確認,不做自動化串接

### 自動歸檔固定寫法

```bash
CURRENT=<本次腳本編號>
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
```

### 前置驗證固定寫法

```bash
if ! grep -q "<上一支腳本會留下的特徵字串>" "<受影響的檔案路徑>"; then
  echo "❌ 尚未包含上一支腳本的改動,請先確認上一支腳本是否已成功套用" >&2
  exit 1
fi
```

### 交付方式

Claude 直接建立實體 `updateN.sh` 檔案供下載(取代舊流程的終端機貼上存檔),使用者下載後傳到 server、`chmod +x updateN.sh && ./updateN.sh` 執行即可。若腳本內容需依 server 端實際檔案內容即時調整,會先在對話中確認邏輯,再產出最終版本檔案。

### 執行步驟(每次異動固定流程)

```bash
# 1. 本機 repo 根目錄
chmod +x updateN.sh && ./updateN.sh

# 2. 確認 diff
git diff HEAD~1 --stat

# 3. 確認 commit 真的成功產生(務必執行,不能只看有無錯誤字樣)
git log --oneline -1

# 4. push(腳本內故意不含此步,避免誤觸發部署)
git push origin main

# 5. server 端部署(若已在 server shell 內,不需再 ssh 進自己)
cd /root/apps && ./deploy.sh

# 6. 瀏覽器強制重整清快取(Ctrl+Shift+R)
```

## 三、`deploy.sh` 核心邏輯

```bash
#!/usr/bin/env bash
set -euo pipefail

APPS_DIR=/root/apps
WEB_ROOT=/var/www/ledger-frontend

cd "$APPS_DIR"

# Pull 最新版
git fetch origin
git reset --hard origin/main

# 防呆:確認 migration 檔案存在,沒有就拒絕部署
migration_count=$(find ledger-backend/alembic/versions -name "*.py" | wc -l)
[ "$migration_count" -gt 0 ] || { echo "ERROR: 無 migration 檔案,拒絕部署" >&2; exit 1; }

# Backend:停服務 → venv → pip install → alembic upgrade head → 啟動服務
systemctl stop ledger-api
cd ledger-backend && source venv/bin/activate
pip install -q -r requirements.txt
alembic upgrade head
deactivate && cd ..
systemctl start ledger-api

# Frontend:npm build → 覆蓋靜態檔輸出目錄
cd ledger-frontend && npm install && npm run build
rm -rf "${WEB_ROOT:?}"/* && cp -r dist/* "$WEB_ROOT"/
cd ..

nginx -t && systemctl reload nginx

# Health check
systemctl is-active ledger-api
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:17756/
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:17756/health
```

回滾:`git reset --hard <部署前的 commit hash>` 後重跑 `deploy.sh`。

## 四、常見錯誤與排查

| 現象 | 原因 | 對策 |
|---|---|---|
| `chmod: cannot access 'updateN.sh'` | 腳本內容直接貼進終端機執行,未存成檔案 | 先 `cat > updateN.sh <<'EOF'` 存檔再 `chmod +x` |
| 500 / 版面異常修正後又復發 | 先前直接在 server 上 `sed` 改檔案,未進版控,被 `deploy.sh` 的 `git reset --hard` 蓋掉 | 一律走本機 repo 改 → commit → push → server deploy |
| `python3` heredoc 印出「❌ ... 不符」 | 目標檔案實際內容與腳本假設不一致(可能手動改過,或依賴的前一支腳本尚未套用) | 重新取得目前檔案內容,重新產生對應 `updateN.sh` |
| 腳本輸出看起來正常,但功能沒生效 | 只看終端機輸出、沒有實際確認 `git log`,腳本可能中途中止 | 依第二節第 8 點,每次都用 `git log --oneline -1` 確認 |

## 五、SOP 沿革

三版增修的完整脈絡(問題重現、決策過程)已整併進上方現況說明,原始三份文件保留於 `archive/`:
`archive/update-deploy-sop-20260707.md`、`archive/update-deploy-sop-20260708.md`、`archive/update-deploy-sop-20260710.md`、`archive/deploy-sop-auto-archive-file-output-20260708.md`
