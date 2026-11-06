#!/usr/bin/env bash
# update53.sh — 文件更新:ledger-backup 還原 bug 修正 + 首次還原演練紀錄
# 執行位置:server 的 /root/apps(root)
set -euo pipefail

CURRENT=53

# ---------- 前置驗證 ----------
[ -d .git ] && [ -d ledger-backend ] && [ -f docs/PROJECT-OVERVIEW.md ] \
  || { echo "❌ 請在 Finance repo 根目錄執行(需有 .git、ledger-backend/、docs/PROJECT-OVERVIEW.md)" >&2; exit 1; }
if ! grep -q "20261103-server-rebuild-ssd-failure" docs/PROJECT-OVERVIEW.md; then
  echo "❌ 尚未套用 update52.sh,請先確認" >&2; exit 1
fi
if grep -q "20261104-restore-drill-fix" docs/PROJECT-OVERVIEW.md; then
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
| `20261104-restore-drill-fix.md` |

### Archive(已整併原始檔,保留回溯)

含三版 `update-deploy-sop-*` + 自動歸檔增修文件(已整併進 `ops/ops-deployment.md`)、三份消費品項疊代式功能文件(已整併進 `features/feature-tags.md`)、及其餘所有原始 `bug-fix-*`/`finance-*`/`software-architecture`/`github-feature`/`infra-public-access`/`migration-sop`/`第二期任務清單` 原檔。

## 六、已知待處理事項(截至 2026-11-03)

1. **Deploy key 為 write access**:2026-11-04 決定維持(server 上 commit/push 流程),接受 server 被入侵時可改寫 repo 的風險
   - ✅ Proxmox 整台 VM 備份已設定(每日 02:30 → `sata1t`、04:00 → 192.168.100.107)
   - ✅ 還原演練已完成(2026-11-04),之後每季一次,見 `ops/ops-backup.md`
   - ✅ `docs/` 已隨 `update52.sh` 重新進版控並部署到 server
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

- 11-04 fix: `ledger-backup restore` 讀不到備份檔(postgres 身分無法讀 root 暫存目錄)+ 首次還原演練成功 → [詳情](changelog-details/20261104-restore-drill-fix.md)
- 11-03 infra: ESXi 主機 SSD 故障導致 FinanceServer VM 與資料庫遺失(無備份);改於 Proxmox VM 205 以 `rebuild-server.sh` 重建(資料庫為空)→ [詳情](changelog-details/20261103-server-rebuild-ssd-failure.md)
- 11-03 ops: 新增每日資料庫備份 `ledger-backup`(VM 本機 + SMB 192.168.100.107,保留 3 天)與災難復原流程 → 見 `ops/ops-backup.md`
- 11-03 docs: `CHANGELOG.md` 輪替,2026-07、2026-08 索引封存至 `changelog-archive/CHANGELOG-2026-H2.md`
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
- ✅ 還原演練完成(2026-11-04,見 `changelog-details/20261104-restore-drill-fix.md`)
- ✅ `docs/` 已由 `update52.sh` 提交並部署到 server
__DOC_EOF__

cat > 'docs/changelog-details/20261104-restore-drill-fix.md' << '__DOC_EOF__'
# 2026-11-04 ledger-backup 還原 bug 修正 + 首次還原演練

## 現象

第一次執行 `ledger-backup restore ledger_20261104_100040.tar.gz` 時:

```
pg_restore: error: could not open input file "/tmp/tmp.vC5jcE6dxF/ledger_db.dump": Permission denied
⚠️  pg_restore 有回報錯誤(常見為無害的權限訊息),請確認網站資料是否正確
```

資料庫實際上**完全沒有被還原**,但訊息讓人以為只是無害警告。

## 原因

1. 備份檔解壓到 `mktemp -d` 建立的暫存目錄(權限 700,只有 root 可讀),但 `pg_restore` 以 `sudo -u postgres` 執行,讀不到檔案
2. `pg_restore` 失敗時的訊息寫成「常見為無害的權限訊息」,錯誤判斷

## 修正

```bash
# 由 root 讀檔,經 stdin 交給 postgres 身分的 pg_restore
if sudo -u postgres pg_restore --clean --if-exists -d "$DB_NAME" < "$tmp/ledger_db.dump"; then
  log "✅ 資料庫還原完成"
else
  log "❌ pg_restore 失敗,資料庫可能未還原或只還原一部分,請檢查上方錯誤訊息"
  log "   還原前的狀態在 $safety,可用 pg_restore 手動還原"
fi
```

已更新 `/usr/local/sbin/ledger-backup` 與原始檔(本機 `Finance\Developing\ledger-backup.sh`)。備份(`pg_dump`)不受影響:輸出由 root 的 shell 重新導向寫檔,權限沒有問題。

## 還原演練結果

| 步驟 | 結果 |
|---|---|
| 1. `ledger-backup run` → `ledger_20261104_100040.tar.gz` | ✅ 本機 + SMB 比對一致 |
| 2. 網頁新增一筆收入 500 | ✅ |
| 3. `ledger-backup restore ledger_20261104_100040.tar.gz` | ✅ 先自動備份到 `pre-restore/pre-restore_20261104_100615.tar.gz`,再還原 |
| 4. 網頁確認 | ✅ 500 那筆消失,其餘帳本、帳戶、交易都在,可正常登入 |

結論:備份 → 異機存放 → 還原整條流程可用。之後每季演練一次(見 `ops/ops-backup.md` 第五節)。
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

最近一次還原演練:**2026-11-04,成功**(見 `changelog-details/20261104-restore-drill-fix.md`)。

| 頻率 | 項目 |
|---|---|
| 每週 | `ledger-backup status`:`LAST` 有在跑、紀錄沒有 ❌;Windows 上確認 `\\192.168.100.107\dbbackup\finance` 有最近 3 天的檔案;Proxmox Datacenter → Backup 的任務紀錄(Tasks)沒有失敗 |
| 每季 | **還原演練**:另建測試 VM(或在 VM 上用 `restore` 還原後再還原回來),確認備份檔真的能用 |
| 主機變動時 | Proxmox 換碟、Windows 備份主機改密碼/改 IP → 重跑 `ledger-backup install` |
__DOC_EOF__

git add docs
git commit -m "docs: ledger-backup 還原 bug 修正紀錄 + 首次還原演練完成"

echo
git log --oneline -2
echo
echo "✅ 完成。確認無誤後:git push origin main && ./deploy.sh"
