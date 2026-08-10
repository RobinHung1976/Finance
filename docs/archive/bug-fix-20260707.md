# Bug 修復紀錄彙整

建立日期:2026-07-07

## 一、本次(A3 分類統計)修復項目

### 1. `category_id` UUID 型別驗證錯誤

| 項目 | 內容 |
|---|---|
| 現象 | `GET /stats/category-breakdown` 500,前端顯示「載入分類統計失敗」 |
| 錯誤訊息 | `pydantic_core._pydantic_core.ValidationError: category_id / Input should be a valid string, input_value=UUID(...), input_type=UUID` |
| 原因 | Recursive CTE 用 `db.execute(text(...))` 執行 raw SQL,不像 ORM query 會自動把 Postgres `UUID` 欄位轉成 Python `str`;`CategoryBreakdownItem.category_id` schema 宣告為 `str`,型別對不上 |
| 修正 | `app/routers/stats.py`:`category_id=str(r["category_id"])` |
| 復發原因 | 首次修正直接在 server 上用 `sed` 改檔案,未 commit/push;後續跑 `deploy.sh` 的 `git reset --hard origin/main` 把改動蓋掉,同一個錯誤重現 |

### 2. 統計圖表區塊無限往下延伸

| 項目 | 內容 |
|---|---|
| 現象 | 「支出分類統計」正常顯示圖表,但頁面持續向下延伸不停止 |
| 原因 | `.chart-wrap { flex: 1 }` 位於 `flex-direction: column` 容器內,父層(`.category-breakdown { height: 100% }`)無明確高度基準;Chart.js `responsive: true` 依容器尺寸重繪,雙方互相撐大形成無界迴圈 |
| 修正 | `CategoryBreakdownChart.vue`:`.chart-wrap` 改固定 `height: 320px`,移除 `.category-breakdown` 的 `height: 100%` |
| 復發原因 | 同上,server 端直接 `sed` 修改未進版控,被 `deploy.sh` 蓋掉,需二次修復 |

### 3. 根本流程問題(本次踩坑的共同原因)

- `deploy.sh` 每次執行 `git fetch && git reset --hard origin/main`,任何未 commit/push 的本機(server 端)手動修改都會被清除
- 前兩項 bug 都因為「先在 server 上直接 `sed` 改檔案驗證 → 沒有回寫 git repo → 下次 deploy 蓋掉」而重複出現兩次
- **SOP 修正**:所有程式異動一律走「本機 repo 改 → `git commit` → `git push origin main` → server `./deploy.sh`」單一路徑,禁止在 server 上直接手動改程式檔案(現況已在 `github-feature-20260707.md` 第五節提及,本次是實際踩坑驗證)

## 二、歷史修復紀錄(彙整自既有文件,供追溯對照)

### 出處:`finance-2nd-A1-A2-20260707.md`

| # | Bug | 原因 | 修正 |
|---|---|---|---|
| 1 | Alembic migration 遺失(`abb9d370cb81` 找不到) | 舊版 zip 打包流程曾遺失 migration 檔案 | 另見 `migration-history-20260706.md`;`deploy.sh` 新增防呆機制(檢查 `alembic/versions/*.py` 數量,為 0 則拒絕部署) |
| 2 | TypeScript 型別錯誤:`formatCurrency` 不接受 `null` | Chart.js tooltip callback 的 `ctx.parsed.y` 型別為 `number \| null`,原函式簽名只接受 `number` | 函式簽名改為 `(value: number \| null)`,`null` 時回傳 `'-'` |
| 3 | `deploy.sh` 缺少 `mkdir -p "$WEB_ROOT"` | zip-based 改寫成 git-based 部署時漏帶原本指令 | 補回 `mkdir -p`,清除手動補救造成的重複行 |
| 4 | 登入失敗:`.env.production` 遺失,內網 IP 被打包進 production build | `.env.production`(相對路徑用)未曾進版控,遺失後 `.env`(內網 IP)殘留磁碟並生效,build 產物打包進錯誤 API URL | 重建 `.env.production` 並強制加入版控(內容不含機密);刪除 `.env`;判斷入庫標準改為「是否含機密」而非檔名慣例 |

### 出處:`github-feature-20260707.md`

| # | 問題 | 原因 | 解法 |
|---|---|---|---|
| 1 | `git remote add` 報 `not a git repository` | `git init` 實際未執行成功即往下跑後續指令 | 重新確認 `.git` 是否存在,補跑 `git init` |
| 2 | `node_modules/` 被整包 commit | `.gitignore` 建立指令未真正寫入檔案 | `git reset` 撤銷 staging,確認 `.gitignore` 內容存在後重新 `git add` |
| 3 | `git commit` 報 `Author identity unknown` | server 上從未設定 git 身份 | `git config user.email` / `user.name` |
| 4 | `ssh -T github-finance` 報 `Could not resolve hostname` | `~/.ssh/config` 檔案不存在(建立指令未被執行到) | 重新用 `cat > ~/.ssh/config` 建立並確認內容 |
| 5 | `git push` 被 `[rejected]`(fetch first) | GitHub 建 repo 時自動產生初始 commit,兩邊 history 不相關 | 確認 remote 只有無關緊要內容後 `git push --force` |
| 6 | Push 成功但提示 repo moved | GitHub 帳號/repo 路徑大小寫正規化 | `git remote set-url origin` 改為正規化後路徑 |

## 三、共同教訓與後續 SOP

1. **驗證修正是否生效,不能只看 server 當下行為**:必須確認改動已進 git history,否則下次 `deploy.sh`/`git reset --hard` 會無聲蓋回舊版本
2. **UUID / DB 原生型別 與 Pydantic schema 型別要顯式轉換**:凡使用 raw SQL(`text()`)取代 ORM query,一律檢查回傳欄位型別是否需要手動 `str()`/`float()` 轉換
3. **Flex 佈局搭配第三方 responsive 元件(Chart.js 等)要給固定高度基準**,避免 `flex: 1` 在無界容器內與 canvas 自身 resize 邏輯形成迴圈
4. **本機改 → commit → push → server deploy** 為唯一合法修改路徑,`update.sh`/`updateN.sh` 模式應持續作為預設修改方式,取代逐檔案手動 sed
