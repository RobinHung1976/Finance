#!/usr/bin/env bash
# update52.sh — 文件更新:2026-11-03 主機重建、備份機制、CHANGELOG 輪替、修正 docs 位置說明
# 執行位置:server 的 /root/apps(root)
set -euo pipefail

CURRENT=52

# ---------- 前置驗證 ----------
[ -d .git ] && [ -d ledger-backend ] && [ -f docs/PROJECT-OVERVIEW.md ] \
  || { echo "❌ 請在 Finance repo 根目錄執行(需有 .git、ledger-backend/、docs/PROJECT-OVERVIEW.md)" >&2; exit 1; }
if ! grep -q "20260810-a9-top-transactions.md" docs/PROJECT-OVERVIEW.md; then
  echo "❌ docs/PROJECT-OVERVIEW.md 不是預期的 2026-08-10 版本,請先確認後再執行" >&2; exit 1
fi
if grep -q "20261103-server-rebuild-ssd-failure" docs/PROJECT-OVERVIEW.md; then
  echo "❌ 已套用過本次更新,不需重跑" >&2; exit 1
fi

# ---------- 自動歸檔 ----------
mkdir -p "update${CURRENT}"
for f in update*.sh; do
  [ "$f" = "update${CURRENT}.sh" ] && continue
  [ -f "$f" ] || continue
  git mv "$f" "update${CURRENT}/$f" 2>/dev/null || mv "$f" "update${CURRENT}/$f"
done
git add -A "update${CURRENT}" 2>/dev/null || true
if ! git diff --cached --quiet; then
  git commit -m "chore: 歸檔已執行的 updateN.sh 腳本"
fi

# ---------- 寫入文件(整份覆寫) ----------
mkdir -p docs/ops docs/changelog-details docs/changelog-archive
cat > 'docs/PROJECT-OVERVIEW.md' << '__DOC_EOF__'
# Finance Ledger — 專案總覽

本文件是專案文件的**入口**。想知道「現在系統長什麼樣子」,從這裡開始找對應的 `features/feature-*.md`;想知道「什麼時候改了什麼」,看 `CHANGELOG.md`。

## 一、文件分類與記錄規則

| 類型 | 位置 | 內容原則 | 更新方式 |
|---|---|---|---|
| 總覽入口 | `PROJECT-OVERVIEW.md`(本文件) | 環境資訊、開發慣例、文件索引 | 原地更新 |
| 變更索引 | `CHANGELOG.md` | 一行式索引 + 連結,只保留最近 2 個月 | 新增條目,每滿 2 個月輪替封存 |
| 變更詳情 | `changelog-details/*.md` | 每次變更完整細節(背景/決策/修改內容/目前狀態) | **永久保留,不搬動,只增不減** |
| 索引封存 | `changelog-archive/CHANGELOG-<年>-H<半年>.md` | 超過 2 個月的 `CHANGELOG.md` 索引 | 半年封存一次,封存後不再變動 |
| 功能現況 | `features/feature-*.md` | 只寫「現在長什麼樣子」,不寫演變過程 | **原地覆蓋更新**,永遠只有一份 |
| 維運文件 | `ops/ops-*.md` | server 環境、部署、GitHub 連線 | 原地更新 |
| 已合併原始檔 | `archive/*.md` | 被整併掉的原始檔案(疊代式舊版 SOP、舊版功能紀錄、bug 修復紀錄原檔等),保留供回溯對照 | 不刪除、不編輯 |

## 二、未來記錄規則(動手改東西前先看這裡)

1. 改到現有功能 → 直接編輯對應的 `feature-*.md`,更新成新現況;同時在 `CHANGELOG.md` 加一行索引,細節寫成獨立檔案放 `changelog-details/日期-關鍵字.md`
2. 修 bug → 細節寫進 `changelog-details/`(格式比照現有 Bug 修復紀錄的「現象/原因/修正」),`CHANGELOG.md` 加一行索引;如果修完後行為跟文件描述的不一樣了,才回頭同步 `feature-*.md`
3. 新功能 → 新增一份 `feature-<名稱>.md`,並在本文件「文件索引」章節加一行連結
4. 檔名不帶日期(`feature-*.md` 一律不帶日期;`changelog-details/` 檔名帶日期是例外,因為它本質就是時間序記錄)
5. 舊的疊代式版本(如同一份 SOP 改了三次、同一功能連續寫了三份紀錄)不再各自留在根目錄:整併成一份現況寫進對應 `feature-*.md`/`ops-*.md`,原始檔搬進 `archive/` 保留
6. `CHANGELOG.md` 每滿 2 個月做一次輪替:把最舊的月份剪下,貼進 `changelog-archive/CHANGELOG-<年>-H<半年>.md`
7. `changelog-details/` 底下的檔案永久保留、不搬動,確保索引裡的連結永遠有效
8. 新增 API 端點 → 去對應領域的 `routers/*.py` 加一個 route
9. 修改 `models.py` → 依 `ops/ops-migration-sop.md` 產生 migration,不可省略
10. 版控/部署走 `updateN.sh`/`deploy.sh` 慣例(前置驗證 + 精確比對/整份覆寫 + 自動歸檔 + 驗證清單),細節見 `ops/ops-deployment.md`

## 三、文件目錄結構(server 實際路徑)

本專案文件(即本文件所屬的整套 `PROJECT-OVERVIEW.md`/`CHANGELOG.md`/`ops/`/`features/`/`changelog-details/`/`changelog-archive/`/`archive/`)存放於 server:

```
/root/apps/docs/
├── PROJECT-OVERVIEW.md
├── CHANGELOG.md
├── archive/               # 已整併原始檔(不刪除、不編輯)
├── changelog-details/     # 依日期,永久保留
├── changelog-archive/     # CHANGELOG.md 超過 2 個月的索引封存(半年一次)
├── features/              # feature-*.md,只寫現況
└── ops/                   # ops-*.md,server/部署/GitHub 相關
```

與 `ledger-backend/`、`ledger-frontend/` 同層,**同屬 `RobinHung1976/Finance` repo 的 `docs/` 目錄**(2026-11-03 重建時確認;先前本節誤記為獨立於 repo)。文件異動在 server 的 `/root/apps` 以 `updateN.sh`(或直接 `git add/commit/push`)提交。**未 commit 的修改會被下次 `deploy.sh` 的 `git reset --hard` 蓋掉**,改完務必先 commit + push 再部署。

## 四、環境資訊速查

| 用途 | 路徑 |
|---|---|
| Repo | `RobinHung1976/Finance`(monorepo:`ledger-backend/` + `ledger-frontend/`) |
| 部署目錄 | `/root/apps` |
| 文件目錄(Finance repo 的 `docs/`,見第三節) | `/root/apps/docs` |
| 後端 | `ledger-backend/`(FastAPI,systemd service `ledger-api`) |
| 前端 | `ledger-frontend/`(Vue3 + TS + Vite,`npm run build` 產出靜態檔由 Nginx serve) |
| 前端靜態檔輸出 | `/var/www/ledger-frontend` |
| 對外 port | `17756`(FortiGate VIP 轉內部,無 HTTPS,見 `ops/ops-infra-public-access.md`) |
| 主機 | Proxmox `pve02` 上的 VM 205 `finance-server`(Ubuntu 24.04,`192.168.100.205`,時區 `Asia/Taipei`) |
| 備份 | 每日 02:00 `ledger-backup` → VM 本機 + `//192.168.100.107/dbbackup/finance`,見 `ops/ops-backup.md` |

完整架構、部署流程、GitHub 連線設定、`updateN.sh`/`deploy.sh` 慣例,見 `ops/ops-server-requirements.md`、`ops/ops-deployment.md`、`ops/ops-github-workflow.md`。

## 五、文件索引

### Features(現況文件)

| 檔案 | 內容 |
|---|---|
| `feature-auth.md` | 登入/註冊/忘記密碼、JWT 效期 |
| `feature-household.md` | 帳本改名/防呆/封存解封、成員刪除、CLI 永久刪除 |
| `feature-accounts.md` | 帳戶 CRUD、餘額連動、回補腳本 |
| `feature-categories.md` | 分類樹、CategoryPicker/CategoryList/CategoryFilterPicker |
| `feature-tags.md` | 消費品項(Tag)CRUD、UX、統計串接 |
| `feature-transactions.md` | 交易 CRUD、進階篩選面板 |
| `feature-stats.md` | 月收支趨勢、分類統計、消費品項排行、待開發項目清單 |
| `feature-excel-import-export.md` | Excel 匯入/匯出 |

### Ops

| 檔案 | 內容 |
|---|---|
| `ops-server-requirements.md` | 系統架構、Service 現況、Python 環境 |
| `ops-deployment.md` | `updateN.sh`/`deploy.sh` 撰寫與執行 SOP |
| `ops-github-workflow.md` | GitHub 連線設定、日常部署流程 |
| `ops-infra-public-access.md` | FortiGate + Nginx 對外連線設定 |
| `ops-migration-sop.md` | Alembic migration 產生流程 |
| `ops-backup.md` | 資料庫每日備份、Proxmox VM 備份、還原與災難復原流程 |

### Changelog-details(依日期,永久保留)

| 檔案 |
|---|
| `20260707-household-name-fix.md` |
| `20260707-session-member-delete.md` |
| `20260707-bug-fix-batch.md` |
| `20260707-category-picker-search.md` |
| `20260707-monthly-trend-balance.md` |
| `20260707-excel-import-export-launch.md` |
| `20260707-tag-feature-launch.md` |
| `20260708-household-management.md` |
| `20260708-account-balance-recalc.md` |
| `20260708-category-management-search.md` |
| `20260708-excel-import-export-fix.md` |
| `20260708-tag-ux-improvement.md` |
| `20260708-tag-breakdown-stats.md` |
| `20260710-transaction-tag-filter-advanced-search.md` |
| `20260713-category-breakdown-self-amount.md` |
| `20260810-admin-reset-password-cli.md` |
| `20260810-a10-clarify-tag-breakdown-fix.md` |
| `20260810-pwa-docs-and-tree-fix.md` |
| `20260810-a9-top-transactions.md` |
| `20261103-server-rebuild-ssd-failure.md` |

### Archive(已整併原始檔,保留回溯)

含三版 `update-deploy-sop-*` + 自動歸檔增修文件(已整併進 `ops/ops-deployment.md`)、三份消費品項疊代式功能文件(已整併進 `features/feature-tags.md`)、及其餘所有原始 `bug-fix-*`/`finance-*`/`software-architecture`/`github-feature`/`infra-public-access`/`migration-sop`/`第二期任務清單` 原檔。

## 六、已知待處理事項(截至 2026-11-03)

1. **Deploy key 為 write access**:2026-11-04 決定維持(server 上 commit/push 流程),接受 server 被入侵時可改寫 repo 的風險
   - ✅ Proxmox 整台 VM 備份已設定(每日 02:30 → `sata1t`、04:00 → 192.168.100.107)
   - **還原演練尚未執行**,見 `ops/ops-backup.md`
   - **`/root/apps/docs` 文件集隨舊 VM 遺失**,需從副本放回 server
2. **自動化部署尚未建立**:push 後自動觸發部署,目前暫緩,先手動跑穩定後再考慮
3. **無 HTTPS**:純 public IP 對外,無域名無法申請憑證,JWT token 可能被側錄,見 `ops/ops-infra-public-access.md`
4. **忘記密碼信件功能入口暫停**:程式碼已完成,Postfix 入口暫停
5. **歷史帳戶餘額落差已回補完成**,屬一次性腳本,非持續機制
6. **`client.ts` 全域固定 `Content-Type: application/json`**:未來新增檔案上傳功能時需記得清除此 header

## 七、下一步開發(優先順序,截至 2026-08-10)

**統計功能(A 系列,A1-A3、A9、A10 已完成)**
- [~] A4 分類趨勢比較(依賴 A3)——**擱置**(2026-08-10 討論後決定暫停;如重啟,需先定案 UX:多分類疊圖 vs 單分類切換)
- [~] A5 同期比較 MoM/YoY(依賴 A1)——**擱置**(2026-08-10 討論後決定暫停;YoY 資料量不足,系統 2026-07-07 才上線,MoM 意義也有限)
- [~] A6 成員別統計——**擱置**(2026-08-10 討論後決定暫停;如重啟,需先決定成員被刪除後 `Transaction.user_id` 變 `None` 的交易如何呈現)
- [~] A7 帳戶別統計——**擱置**(2026-08-10 討論後決定暫停;如重啟,需講清楚「區間交易總額」與帳戶現有 `balance` 是兩個不同概念,避免使用者混淆)
- [~] A8 月底預估(依賴 A1)——**擱置**(2026-08-10 討論後決定暫停;估算邏輯尚未定案,貿然做易產生誤導性數字)
- [x] A9 最大單筆排行 Top5(2026-08-10 完成,見 `features/feature-stats.md`)
- [x] A10 自訂區間統計(原已完成,文件先前誤列,2026-08-10 釐清,見 `features/feature-stats.md`)

**預算功能(B,`Budget` model 已存在,尚缺 API/前端)**
- [ ] B1 Budget schema + router(CRUD)
- [ ] B2 前端「設定預算」頁面
- [ ] B3 預算達成率(依賴 B1 + A1)

**CSV 匯入/匯出(C,獨立模組)**
- [ ] C1 CSV 匯出
- [ ] C2 CSV 匯入(格式驗證)
- [ ] C3 重複資料偵測

**報表匯出(D,依賴 A 圖表穩定)**
- [ ] D1 統計頁面「匯出」按鈕
- [ ] D2 PDF 版面

**選配 / 未定案**
- [ ] 重複交易(固定週期)——排入第三期,先不處理
- [ ] 分類篩選/統計含子分類彙總(遞迴查詢)
- [ ] 消費品項合併重複 / 新增時相似名稱提醒
__DOC_EOF__

cat > 'docs/CHANGELOG.md' << '__DOC_EOF__'
# CHANGELOG

只放「最近 2 個月」的一行式索引,詳細內容請點連結進 `changelog-details/`。超過 2 個月的索引會依半年封存進 `changelog-archive/`(規則見 `PROJECT-OVERVIEW.md` 開發慣例章節)。

## 2026-11

- 11-03 infra: ESXi 主機 SSD 故障導致 FinanceServer VM 與資料庫遺失(無備份);改於 Proxmox VM 205 以 `rebuild-server.sh` 重建(資料庫為空)→ [詳情](changelog-details/20261103-server-rebuild-ssd-failure.md)
- 11-03 ops: 新增每日資料庫備份 `ledger-backup`(VM 本機 + SMB 192.168.100.107,保留 3 天)與災難復原流程 → 見 `ops/ops-backup.md`
- 11-03 docs: `CHANGELOG.md` 輪替,2026-07、2026-08 索引封存至 `changelog-archive/CHANGELOG-2026-H2.md`
__DOC_EOF__

cat > 'docs/changelog-archive/CHANGELOG-2026-H2.md' << '__DOC_EOF__'
# CHANGELOG 封存 2026 下半年(H2)

從 `CHANGELOG.md` 輪替出來的索引,封存後不再變動。連結指向 `changelog-details/`(永久保留)。

## 2026-08

- 08-10 feat: A9 最大單筆排行上線,統計頁新增第四個子分頁(後端 join 帳戶/分類名稱 + 前端 TopTransactionsList.vue) → [詳情](../changelog-details/20260810-a9-top-transactions.md)
- 08-10 docs: 記錄前端 PWA plugin 現況(無 HTTPS 下形同虛設)+ 修正 server 目錄樹過時項目 → [詳情](../changelog-details/20260810-pwa-docs-and-tree-fix.md)
- 08-10 docs/fix: 釐清 A10 自訂區間統計已完成(文件先前誤列尚未開始);`tag-breakdown` 的 `start_date`/`end_date` 改為選填+預設,與其他統計 API 一致 → [詳情](../changelog-details/20260810-a10-clarify-tag-breakdown-fix.md)
- 08-10 feat: 新增管理員手動重設密碼 CLI(Postfix 忘記密碼信件入口暫停期間的臨時替代方案) → [詳情](../changelog-details/20260810-admin-reset-password-cli.md)

## 2026-07

- 07-13 fix: 分類統計下鑽補「本分類直接交易」項目(頂層/下鑽 CTE 起點不一致導致金額對不起來,`stats.py` 修正 + `update46/47.sh` 部署) → [詳情](../changelog-details/20260713-category-breakdown-self-amount.md)
- 07-10 feat: 交易紀錄消費品項篩選 + 篩選 UI 改為進階篩選面板(帳戶/分類篩選器改版) → [詳情](../changelog-details/20260710-transaction-tag-filter-advanced-search.md)
- 07-08 feat: 統計圖表加入消費品項排行(長條圖,非圓餅圖)+ 部署中斷 bug 修復(`TransactionType`/`date` import) → [詳情](../changelog-details/20260708-tag-breakdown-stats.md)
- 07-08 feat: 消費品項(Tag)UX 改善 —— 搜尋、使用統計、最近使用分區、Chip 版面 → [詳情](../changelog-details/20260708-tag-ux-improvement.md)
- 07-08 fix: Excel 匯入/匯出功能(帳戶餘額未更新、格式死板、中文檔名 500、下載檔名前端寫死) → [詳情](../changelog-details/20260708-excel-import-export-fix.md)
- 07-08 feat: 分類管理頁 UX 改善 —— 搜尋改名/刪除、移除多餘選取提示 → [詳情](../changelog-details/20260708-category-management-search.md)
- 07-08 feat: 帳本改名 + 名稱防呆 + 封存/解封 + CLI 永久刪除 → [詳情](../changelog-details/20260708-household-management.md)
- 07-08 fix: 歷史資料回補 —— 帳戶餘額重新計算腳本 → [詳情](../changelog-details/20260708-account-balance-recalc.md)
- 07-08 sop: update.sh/deploy.sh 增修(自動歸檔 + 自動產出腳本檔案)→ 已整併進 `ops/ops-deployment.md`,原始版本見 `archive/deploy-sop-auto-archive-file-output-20260708.md`
- 07-07 feat: 消費品項(Tag)功能 + 分類管理優化 + 交易搜尋,含分類樹第三層遷移為 Tag → [詳情](../changelog-details/20260707-tag-feature-launch.md)
- 07-07 feat: 登入效期延長(1天→30天)+ 成員刪除功能 → [詳情](../changelog-details/20260707-session-member-delete.md)
- 07-07 fix: Dashboard 標題顯示錯誤 household 名稱 → [詳情](../changelog-details/20260707-household-name-fix.md)
- 07-07 fix: A3 分類統計 bug 修復彙整(`category_id` UUID 型別、flex 無界延伸)+ 歷史踩坑彙整 → [詳情](../changelog-details/20260707-bug-fix-batch.md)
- 07-07 feat: 交易分類編輯 UX 優化(CategoryPicker 搜尋功能) → [詳情](../changelog-details/20260707-category-picker-search.md)
- 07-07 feat: 月收支趨勢圖 + 結餘計算(A1+A2),連帶完成部署架構轉正式環境 → [詳情](../changelog-details/20260707-monthly-trend-balance.md)
- 07-07 feat: Excel 匯入/匯出功能初版上線 → [詳情](../changelog-details/20260707-excel-import-export-launch.md)
- 07-07 infra: 對外連線改用 FortiGate + Nginx(取代原規劃的 Cloudflare Tunnel) → 已整併進 `ops/ops-infra-public-access.md`
- 07-07 sop: GitHub / Git 化部署流程建立 → 已整併進 `ops/ops-github-workflow.md`
- 07-07 sop: update.sh/deploy.sh 標準作業流程初版 → 已整併進 `ops/ops-deployment.md`,原始版本見 `archive/update-deploy-sop-20260707.md`
__DOC_EOF__

cat > 'docs/changelog-details/20261103-server-rebuild-ssd-failure.md' << '__DOC_EOF__'
# 2026-11-03 FinanceServer 主機 SSD 故障、資料遺失與重建

## 現象

ESXi 主機(192.168.100.229)上,`FinanceServer`、`OVOC-8-2-1342`、`rbsbcha01`、`ESI-WebServer-Backup` 四台 VM 狀態顯示「無效」,名稱變成 `.vmx` 路徑;datastore `SSD01` 容量 0 B。

## 原因

`SSD01` 所在的 Transcend **TS1TSSD230S 1TB SSD** 硬體故障:

| 時間 | 跡象 |
|---|---|
| 一開始 | 所有寫入指令失敗(`Cmd 0x2a`,sense `0x4/0x44` Hardware Error / Internal target failure),VMFS 需寫入鎖定資料,因此無法掛載。讀取仍正常 |
| SMART | Health 顯示 OK,但 Reallocated Sector Count 215、Reallocation Event 129,快閃記憶體已大量出現壞區塊 |
| 救援過程中 | 讀取也開始失敗(`READ DMA EXT` / `ABRT`),最後連 VMFS 中繼資料區都讀不到,`vmfs6-fuse` 無法開啟檔案系統 |

這顆 SSD 同時是 ESXi 的開機碟,拔除後 ESXi 主機無法開機。

## 救援嘗試(失敗)

1. 用 Ubuntu Live USB 接上 SSD,以 `vmfs6-tools`(Ubuntu 26.04 套件庫已移除,改裝 `vmfs6-tools_0.2.1-1build2_amd64.deb`)唯讀掛載,一度可列出 FinanceServer 檔案(`-flat.vmdk` 最後修改 11/2 00:27)
2. `rsync` 複製到本機 NTFS 分割時,速度在 ESI-WebServer-Backup 的資料區掉到 145 kB/s,dmesg 出現大量讀取錯誤
3. 改用 `ddrescue` 前,VMFS 目錄區已無法讀取,救援中止
4. **沒有任何其他備份**,決定放棄舊資料、重建

教訓:發現 SSD 可讀時應**第一時間用 `ddrescue` 對整個分割做映像**(一次讀完、跳過壞區塊),而不是逐檔 `rsync`;也應**先救最重要的 FinanceServer**(rsync 依字母順序先處理了 ESI)。

## 影響

- **帳本資料全部遺失**(PostgreSQL 在 VM 內):household、使用者、帳戶、分類、交易、消費品項皆無法救回
- 程式碼無影響(在 GitHub `RobinHung1976/Finance`)
- server 上的 `/root/apps/docs` 文件集一併遺失;Claude 專案與本機 `Finance\reorg\` 有副本

## 重建內容

### 主機

| 項目 | 舊 | 新 |
|---|---|---|
| Hypervisor | ESXi(192.168.100.229) | **Proxmox VE**(node `pve02`),系統碟 512GB SSD,備份碟 SATA 1TB(原 Seagate ST1000DM003,已清空) |
| VM | FinanceServer | **VM 205 `finance-server`**:q35、2 vCPU(x86-64-v2-AES)、4 GB RAM、50 GB(local-lvm,discard/ssd)、virtio 網卡 vmbr0 |
| OS | — | Ubuntu Server 24.04 LTS,使用者 `fiadmin`,時區 `Asia/Taipei`,已裝 `qemu-guest-agent` |
| IP | 192.168.100.205 | 沿用 192.168.100.205(FortiGate VIP 不用改) |

### 應用程式

以新的 `rebuild-server.sh` 一次完成:PostgreSQL、clone repo、`.env`、venv、建表、`ledger-api` systemd、前端 build、Nginx(:17756)、ufw。

- **資料表建立方式**:baseline migration `6f900ce6a7ff` 為空,全新 DB 無法 `alembic upgrade head`,改用 `Base.metadata.create_all()` + `alembic stamp head`
- **新的 `SECRET_KEY` 與 DB 密碼**:舊值已遺失,重新產生
- **GitHub deploy key**(Title `Finance-Server`)重建時先設為唯讀;評估改由 Windows 本機 commit/push 不便後,2026-11-04 決定維持原流程(server 上 commit/push),key 重新加回並開啟 write access
- 確認 `docs/` 屬於 Finance repo(`PROJECT-OVERVIEW.md` 第三節原記載為獨立,已更正)
- 腳本 bug 修正:GitHub 認證成功時 `ssh -T` 仍回傳 1,搭配 `set -o pipefail` 被誤判為失敗、卡在貼 key 的迴圈 → 改為 `{ ssh -T github-finance 2>&1 || true; } | grep -q "successfully authenticated"`

重建後驗證:11 張資料表皆存在、`alembic_version` 1 筆,其餘 0 筆,需重新註冊帳本。

### 備份(本次新增)

見 `ops/ops-backup.md`。第一層 `ledger-backup` 已上線:每日 02:00 備份資料庫 + `.env` 到 VM 本機與 `//192.168.100.107/dbbackup/finance`,保留 3 天;首次備份 `ledger_20261103_165411.tar.gz` 兩邊比對一致。

## 目前狀態

- ✅ Finance 服務重建完成,資料庫為空
- ✅ 第一層每日資料庫備份上線
- ✅ 第二層 Proxmox 整台 VM 備份上線:每日 02:30 → `sata1t`(保留 7 天)、04:00 → 192.168.100.107 `win10-backup-pve02`(保留 4 天),首次備份已完成
- ⏳ 還原演練尚未執行
- ⏳ `/root/apps/docs` 文件集需從副本放回 server
__DOC_EOF__

cat > 'docs/ops/ops-backup.md' << '__DOC_EOF__'
# 備份與災難復原

2026-11-03 原 FinanceServer VM 隨 ESXi 主機 SSD 故障一併遺失,且**當時完全沒有備份**,資料庫無法救回(事件經過見 `changelog-details/20261103-server-rebuild-ssd-failure.md`)。本文件記錄重建後建立的備份機制與還原流程。

## 一、備份架構(兩層)

| 層級 | 內容 | 頻率 / 保留 | 存放位置 | 用途 |
|---|---|---|---|---|
| 第一層:資料庫 | `pg_dump -Fc ledger_db` + `ledger-backend/.env` | 每日 02:00,保留 3 天(可調) | VM 本機 `/var/backups/ledger/` + SMB `//192.168.100.107/dbbackup/finance/` | **主要保護**。任何主機掛掉都能救回帳本資料 |
| 第二層:整台 VM | Proxmox vzdump(pve02 上所有 VM) | 每日 02:30,保留 7 天 | Proxmox 本機 SATA 1TB(storage `sata1t`) | 快速整台還原(含 Nginx、systemd、`.env`) |
| 第二層:整台 VM(異機) | Proxmox vzdump(pve02 上所有 VM) | 每日 04:00,保留 4 天 | Windows 192.168.100.107 `E:\ProxmoxBackup`(storage `win10-backup-pve02`) | Proxmox 主機整台故障時的整台還原 |

**關鍵原則**:備份一定要有一份放在**另一台實體設備**上。目前資料庫(第一層)與整台 VM(第二層 `win10-backup-pve02`)都各有一份在 192.168.100.107。

## 二、第一層:`ledger-backup`

### 1. 檔案位置

| 用途 | 路徑 |
|---|---|
| 工具本體 | `/usr/local/sbin/ledger-backup`(原始檔:本機 `Finance\Developing\ledger-backup.sh`) |
| 設定檔 | `/etc/ledger-backup.conf`(權限 600) |
| SMB 帳密 | `/etc/ledger-backup.cred`(權限 600,帳號 `bkadmin`) |
| 排程 | `ledger-backup.timer` / `ledger-backup.service`(systemd) |
| 本機備份 | `/var/backups/ledger/ledger_YYYYMMDD_HHMMSS.tar.gz` |
| 還原前自動備份 | `/var/backups/ledger/pre-restore/` |
| SMB 備份 | `\\192.168.100.107\dbbackup\finance\` |

備份檔 `ledger_YYYYMMDD_HHMMSS.tar.gz` 內含:
- `ledger_db.dump`:`pg_dump -Fc` 格式,產生後立即用 `pg_restore -l` 驗證可讀
- `env`:`.env` 副本(含 `SECRET_KEY`、DB 密碼)

> ⚠️ 備份檔含機密(`SECRET_KEY`、DB 密碼),SMB 分享資料夾只能開放給 `bkadmin` 與管理員。

### 2. 指令

| 用途 | 指令 |
|---|---|
| 立即備份 | `ledger-backup run` |
| 調整保留天數 | `ledger-backup set-retention 7` |
| 調整每日備份時間 | `ledger-backup set-time 03:00` |
| 列出本機與 SMB 備份 | `ledger-backup list` |
| 排程狀態 / 最近執行紀錄 | `ledger-backup status` |
| 還原 | `ledger-backup restore ledger_20261103_020000.tar.gz` |
| 重新設定 SMB 帳密 | `ledger-backup install` |

### 3. 運作細節

- **保留天數 N** = 保留「今天往前 N-1 天」到今天的所有檔案,依**檔名日期**判斷(含手動備份)。本機與 SMB 套用相同天數
- SMB 每次備份時才掛載,用完即卸載,不常駐;複製後以 `cmp` 比對兩邊一致
- SMB 失敗時本機備份仍保留,指令回傳非 0(`systemctl status ledger-backup.service` 會顯示 failed)
- 排程 `Persistent=true`:VM 在 02:00 關機的話,開機後會補跑一次
- 用 `flock` 防止同時執行兩份備份
- 目前**無失敗通知**(2026-11-03 決定先不做),需定期 `ledger-backup status` 檢查

### 4. 還原(只還原資料庫)

```bash
ledger-backup list                       # 找出要還原的檔名
ledger-backup restore <檔名>              # 需輸入 YES 確認
```

流程:本機找不到檔案會自動從 SMB 取回 → 驗證 dump → **先備份目前狀態到 `pre-restore/`** → 停 `ledger-api` → `pg_restore --clean --if-exists` → 啟動 `ledger-api`。

備份中的 `.env` 與目前不同時,不會自動覆蓋,另存為 `/var/backups/ledger/restored.env`。若要讓舊的登入 token 繼續有效,把其中的 `SECRET_KEY` 換回 `ledger-backend/.env` 後 `systemctl restart ledger-api`。

## 三、第二層:Proxmox 整台 VM 備份

### 1. 現行設定(2026-11-03 建立並測試完成)

Datacenter → Backup:

| Schedule | Storage | 實際位置 | Retention | Selection |
|---|---|---|---|---|
| 每日 02:30 | `sata1t` | pve02 本機 SATA 1TB | `keep-daily=7` | All(pve02 上所有 VM) |
| 每日 04:00 | `win10-backup-pve02` | 192.168.100.107 `E:\ProxmoxBackup\pve02\dump` | `keep-daily=4` | All |

- Selection 為 All,目前包含 205 `finance-server` 與 223 `esi-webserver-bk`,之後新增的 VM 也會自動納入
- 首次手動備份大小:205 約 2.89 GiB、223 約 3.92 GiB(zstd 壓縮),每日約 7 GiB;`sata1t` 7 天約 50 GiB、`win10-backup-pve02` 4 天約 28 GiB。新增 VM 時記得確認 192.168.100.107 的 `E:` 剩餘空間
- 02:30 與 02:00 資料庫備份相隔 30 分鐘,資料庫備份數秒內完成,不會互相干擾
- VM 已安裝 `qemu-guest-agent`,Snapshot 模式會先凍結檔案系統,備份一致性較佳
- 確認備份成功:`.log` 最後一行應為 `INFO: Finished Backup of VM <id>`;`.tmp` / `.vma.dat` 表示仍在進行中

### 2. 重新建立(Proxmox 重灌時)

1. Datacenter → Storage:確認 `sata1t`(Directory)與 `win10-backup-pve02`(SMB/CIFS → `//192.168.100.107`)的 Content 含 **VZDump backup file**
2. Datacenter → Backup → Add:依上表建立兩個排程,Mode `Snapshot`、Compression `ZSTD`
3. 選取排程 → **Run now**,完成後到 storage → Backups 確認有檔案

### 3. 還原整台 VM

`sata1t`(或 `win10-backup-pve02`)→ Backups → 選備份 → Restore。新的 Proxmox 主機要從 Windows 還原時,先把 `win10-backup-pve02` 加回 Storage 即可看到備份。若原 VM 205 仍在,會被覆蓋;要並存測試則改用新 VMID 並**先拔掉網路**,避免和 192.168.100.205 IP 衝突。

## 四、災難復原:主機整台不見時

前提:SMB 上有 `ledger_*.tar.gz`。

1. 建立新 VM:Ubuntu Server **24.04** LTS、固定 IP `192.168.100.205`、時區 `Asia/Taipei`(規格見 `ops/ops-server-requirements.md`)
2. 執行 `rebuild-server.sh`(本機 `Finance\Developing\`),依提示把新的 deploy key 加到 GitHub(勾選 Allow write access,見 `ops/ops-github-workflow.md`)
3. 上傳 `ledger-backup.sh` → `./ledger-backup.sh install`(SMB 路徑 `//192.168.100.107/dbbackup/finance`,子資料夾 `.`)
4. `ledger-backup list` → `ledger-backup restore <最新檔名>`
5. 用 `restored.env` 的 `SECRET_KEY` 取代新 `.env` 的 `SECRET_KEY`(可選,讓使用者不用重新登入)
6. 瀏覽器確認 `http://192.168.100.205:17756/` 資料正確

預估 20-30 分鐘(大部分是 `npm` build)。

### `rebuild-server.sh` 重點

- baseline migration `6f900ce6a7ff` 是**空的**(原始資料表不是 migration 建的),全新 DB 直接 `alembic upgrade head` 會失敗。腳本改為 `Base.metadata.create_all()` 建表 + `alembic stamp head`;已有資料表時才走 `alembic upgrade head`
- 會自動產生新的 DB 密碼與 `SECRET_KEY`;`.env` 已存在時沿用、不覆蓋
- 可重複執行,已完成的步驟會略過
- Python 套件版本(`requirements.txt`)需要 Python 3.12,**不要用 Ubuntu 26.04**;Vite 8 需要 Node ≥ 20.19,腳本改用 NodeSource 22.x

## 五、定期檢查

| 頻率 | 項目 |
|---|---|
| 每週 | `ledger-backup status`:`LAST` 有在跑、紀錄沒有 ❌;Windows 上確認 `\\192.168.100.107\dbbackup\finance` 有最近 3 天的檔案;Proxmox Datacenter → Backup 的任務紀錄(Tasks)沒有失敗 |
| 每季 | **還原演練**:另建測試 VM(或在 VM 上用 `restore` 還原後再還原回來),確認備份檔真的能用 |
| 主機變動時 | Proxmox 換碟、Windows 備份主機改密碼/改 IP → 重跑 `ledger-backup install` |
__DOC_EOF__

cat > 'docs/ops/ops-server-requirements.md' << '__DOC_EOF__'
# Server 環境需求

## 〇、主機與 VM(2026-11-03 重建後)

| 項目 | 設定 |
|---|---|
| Hypervisor | Proxmox VE,node `pve02`(系統碟 512GB SSD、備份碟 SATA 1TB) |
| VM | 205 `finance-server`:q35、2 vCPU(x86-64-v2-AES)、4 GB RAM、50 GB local-lvm(discard/ssd)、virtio 網卡 vmbr0、Qemu Agent |
| OS | Ubuntu Server **24.04** LTS(`requirements.txt` 需 Python 3.12,勿用 26.04),使用者 `fiadmin` |
| IP / 時區 | `192.168.100.205` 固定 IP / `Asia/Taipei` |
| Node | NodeSource 22.x(Vite 8 需 ≥ 20.19) |
| 重建方式 | 全新 VM 上以 root 執行 `rebuild-server.sh`(本機 `Finance\Developing\`),備份/還原見 `ops/ops-backup.md` |

## 一、系統架構

```
ledger-backend/                    # FastAPI
├── app/
│   ├── config.py                  # Settings(.env 讀取)
│   ├── database.py                # SQLAlchemy engine/session
│   ├── models.py                  # ORM: household/user/account/category/transaction/budget/tag/reset_token
│   ├── deps.py                    # get_current_user / require_admin
│   ├── security.py                # bcrypt hash、JWT 簽發/驗證、reset token
│   ├── audit.py                   # log_action():寫入 AuditLog
│   ├── email.py                   # Postfix relay 寄信
│   ├── validators.py              # 共用輸入驗證邏輯
│   ├── schemas.py                 # auth 相關 pydantic schema
│   ├── schemas_ledger.py          # account/category/transaction/stats schema
│   ├── schemas_tag.py             # 消費品項(Tag)schema
│   ├── schemas_import_export.py   # Excel 匯入/匯出 schema
│   ├── main.py                    # FastAPI app + CORS + router 掛載
│   ├── routers/
│   │   ├── auth.py                # register/login/forgot-password/reset-password
│   │   ├── households.py          # 家庭資訊、成員管理、改名/封存/解封
│   │   ├── accounts.py            # 帳戶 CRUD + 餘額調整連動
│   │   ├── categories.py          # 分類 CRUD(鄰接表)
│   │   ├── transactions.py        # 交易 CRUD + 帳戶餘額自動連動 + 進階篩選
│   │   ├── transactions_transfer.py  # Excel 匯入/匯出
│   │   ├── tags.py                # 消費品項 CRUD
│   │   └── stats.py               # 統計 API
│   └── services/
│       └── excel_transfer.py      # Excel 匯入/匯出實作邏輯
├── alembic/                       # migration
├── reset_password.py              # 管理員手動重設密碼 CLI(見 changelog-details/20260810-admin-reset-password-cli.md)
└── requirements.txt

ledger-frontend/                   # Vue3 + TS + Vite
├── vite.config.ts                 # 含 vite-plugin-pwa(registerType: autoUpdate,manifest 設定「家庭理財」App 名稱/icons)
│                                   # 目前無 HTTPS,Service Worker 實際不會註冊,見 ops-infra-public-access.md 已知限制
├── src/
│   ├── api/                       # client.ts(axios+JWT攔截)、auth.ts、ledgerApi.ts、importExport.ts
│   ├── stores/auth.ts             # Pinia:token/role/household_id
│   ├── router/index.ts            # 路由守衛
│   ├── types/                     # api.ts、ledger.ts、importExport.ts
│   ├── utils/                     # ledgerLabels.ts(中文標籤、幣別格式化)、validators.ts
│   ├── components/                # CategoryPicker/CategoryTreeNode/CategoryList/CategoryFilterPicker/
│   │                               # AccountList/AccountFilterPicker/TransactionList/TagPicker/TagList/
│   │                               # TagFilterPicker/DateRangePicker/MonthlyTrendChart/CategoryBreakdownChart/
│   │                               # TagBreakdownChart/ExcelImportExport
│   └── views/                     # LoginView/RegisterHouseholdView/DashboardView/MembersView/
│                                   # ForgotPasswordView/ResetPasswordView/AuditLogView
```

## 二、Service 現況

| Service | 狀態 | 說明 |
|---|---|---|
| PostgreSQL | systemd 常駐 | `systemctl enable --now postgresql` |
| `ledger-api`(後端) | systemd,已 enabled | `WorkingDirectory=/root/apps/ledger-backend`,開機自啟、當機自動重啟(`Restart=on-failure`) |
| 前端 | 非獨立 process | `vite build` 產出靜態檔,由 Nginx 直接 serve(不再用 `nohup npm run dev`) |
| Nginx | systemd 常駐 | 單一入口(靜態檔 + API reverse proxy),監聽對外 port `17756`,細節見 `ops/ops-infra-public-access.md` |
| Cloudflare Tunnel | 暫停使用 | 原規劃方案,改用 FortiGate 對外 |
| Postfix | systemd 常駐,入口暫停 | 忘記密碼信件功能已完成,入口暫停 |

## 三、Python 環境

虛擬環境:`ledger-backend/venv/`

```bash
cd ledger-backend
source venv/bin/activate
pip install -r requirements.txt
```

主要套件:`fastapi`、`sqlalchemy`、`alembic`、`python-dateutil`、`openpyxl`、`bcrypt`、`python-jose`(或對應 JWT 套件)。

## 四、完整目錄路徑對照表

| 用途 | 路徑 |
|---|---|
| 部署根目錄 | `/root/apps` |
| 後端目錄 | `/root/apps/ledger-backend/` |
| 前端目錄 | `/root/apps/ledger-frontend/` |
| 前端靜態檔輸出 | `/var/www/ledger-frontend` |
| Nginx 設定 | `/etc/nginx/sites-available/ledger` |
| systemd service | `/etc/systemd/system/ledger-api.service` |

## 五、部署方式

見 `ops/ops-deployment.md`(Git-based:`updateN.sh` + `deploy.sh`)。
__DOC_EOF__

cat > 'docs/ops/ops-github-workflow.md' << '__DOC_EOF__'
# GitHub 連線與部署流程

Repo:`Finance`(GitHub 帳號 `RobinHung1976`,大小寫已被 GitHub 正規化,注意 remote URL 需一致避免每次 push 出現轉址提示)。Monorepo 結構(`ledger-backend/` + `ledger-frontend/` 同一個 repo)。

## 一、Server 連上 GitHub(SSH Deploy Key)

### 1. 產生專用金鑰(不與個人 SSH key 混用)

```bash
ssh-keygen -t ed25519 -C "finance-server-deploy" -f ~/.ssh/finance_deploy_key -N ""
```

### 2. SSH 別名

```bash
cat > ~/.ssh/config << 'EOF'
Host github-finance
    HostName github.com
    User git
    IdentityFile ~/.ssh/finance_deploy_key
    IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config ~/.ssh/finance_deploy_key
```

### 3. GitHub 端設定

Repo → Settings → Deploy keys → Add deploy key,貼上公鑰。本專案在 server 上直接 `git commit` + `git push`,**勾選 Allow write access**。

> 2026-11-03 重建時曾改為唯讀,因 Windows 本機另建開發環境不便,2026-11-04 決定維持「server 上 commit/push」流程,key(Title `Finance-Server`)重新加回並開啟 write access。風險:server 被入侵時可改寫 repo,接受此風險。新主機的 key 由 `rebuild-server.sh` 產生並提示貼上。

### 4. 測試連線

```bash
ssh -T github-finance
# 預期:Hi RobinHung1976! You've successfully authenticated...
```

## 二、`.gitignore` 設計

```gitignore
# Python
ledger-backend/venv/
ledger-backend/__pycache__/
ledger-backend/**/__pycache__/
*.pyc

# Node
ledger-frontend/node_modules/
ledger-frontend/dist/

# 機密設定,不進版控
ledger-backend/.env
ledger-frontend/.env
ledger-frontend/.env.production

# 部署產物,不進版控
*.zip

# OS
.DS_Store
```

**關鍵原則**:`alembic/versions/*.py` **絕對不能被排除**——migration 檔案曾在舊版 zip 打包流程中遺失,是改用 Git 化部署的根本原因。

## 三、日常部署流程

```
本機改 code → git add/commit → git push origin main
                                        ↓(手動觸發,目前無自動化)
                              server: cd ~/apps && ./deploy.sh
                              (內部執行 git fetch + reset --hard origin/main)
```

- Server 端**不應直接修改程式碼**(改了會被下次 `deploy.sh` 的 `git reset --hard` 蓋掉,已多次踩坑驗證,見 `changelog-details/20260707-bug-fix-batch.md`)
- 是否接 GitHub Actions/webhook 做自動化部署:目前決定先手動跑,穩定後再考慮

## 四、`updateN.sh`/`deploy.sh` 撰寫慣例

見 `ops/ops-deployment.md`。

## 五、目前狀態

- ✅ Repo 已建立並可正常 push/pull,`deploy.sh` 已改為 git-based
- ⚠️ Deploy key 為 write access(2026-11-04 決定維持,見第一節第 3 點)
- ⏳ 自動化部署(push 後自動觸發)尚未建立,暫緩

## 六、已知問題排查(初始化過程曾踩過的坑)

| 問題 | 原因 | 解法 |
|---|---|---|
| `git remote add` 報 `not a git repository` | `git init` 未真正執行成功即往下跑 | 確認 `.git` 是否存在,補跑 `git init` |
| `node_modules/` 被整包 commit | `.gitignore` 建立指令未真正寫入檔案 | `git reset` 撤銷 staging,確認 `.gitignore` 內容後重新 `git add` |
| `git commit` 報 `Author identity unknown` | server 上從未設定 git 身份 | `git config user.email`/`user.name` |
| `ssh -T github-finance` 報 `Could not resolve hostname` | `~/.ssh/config` 不存在 | 重新用 `cat > ~/.ssh/config` 建立並確認內容 |
| `git push` 被 `[rejected]` | GitHub 建 repo 時自動產生初始 commit,兩邊 history 不相關 | 確認 remote 只有無關緊要內容後 `git push --force` |
| Push 成功但提示 repo moved | GitHub 帳號/repo 路徑大小寫正規化 | `git remote set-url origin git@github-finance:RobinHung1976/Finance.git` |
__DOC_EOF__

cat > 'docs/ops/ops-deployment.md' << '__DOC_EOF__'
# 部署流程

## 一、整體部署方式:Git-based(`updateN.sh` + `deploy.sh`)

改用 Git 追蹤原始碼取代逐檔覆蓋/整包 zip 替換,避免檔案遺失(如 migration 檔案曾在 zip 打包時遺失)、`.env` 忘記還原等風險。

- Repo:`RobinHung1976/Finance`(monorepo,`ledger-backend/` + `ledger-frontend/`)
- 本機改 → `updateN.sh` 覆寫檔案 + commit → `git push` → server 端 `./deploy.sh`
- **「本機 repo」= server 上的 `/root/apps`**:`updateN.sh` 在 server 上執行、commit、push,再於同一台 server 跑 `deploy.sh`(deploy key 有 write access)
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

Claude 直接建立實體 `updateN.sh` 檔案供下載(取代舊流程的終端機貼上存檔),使用者用 WinSCP 傳到 server 的 `/home/fiadmin`(fiadmin 無法直接寫入 `/root`),再以 root `mv` 到 `/root/apps`、`sed -i 's/\r$//'` 去除 Windows 換行後 `chmod +x updateN.sh && ./updateN.sh` 執行。若腳本內容需依 server 端實際檔案內容即時調整,會先在對話中確認邏輯,再產出最終版本檔案。

### 執行步驟(每次異動固定流程)

```bash
# 1. repo 根目錄(server:cd /root/apps)
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
__DOC_EOF__

git add docs
git commit -m "docs: 2026-11-03 主機重建紀錄、新增 ops-backup.md、修正 docs 位置說明、CHANGELOG 輪替"

echo
git log --oneline -2
echo
echo "✅ 完成。確認無誤後:git push origin main && ./deploy.sh"
