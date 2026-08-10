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

與 `ledger-backend/`、`ledger-frontend/` 同層,皆位於 `/root/apps` 底下,但**不屬於 `RobinHung1976/Finance` 這個程式碼 repo**,是獨立管理的文件集合。文件異動走一般 `git add/commit/push`,不需要 `updateN.sh`/`deploy.sh` 那套部署 SOP——那套 SOP(見第二節第 10 點、`ops/ops-deployment.md`)專門處理有實際服務重啟/DB migration 的程式碼異動。

## 四、環境資訊速查

| 用途 | 路徑 |
|---|---|
| Repo | `RobinHung1976/Finance`(monorepo:`ledger-backend/` + `ledger-frontend/`) |
| 部署目錄 | `/root/apps` |
| 文件目錄(獨立於 Finance repo,見第三節) | `/root/apps/docs` |
| 後端 | `ledger-backend/`(FastAPI,systemd service `ledger-api`) |
| 前端 | `ledger-frontend/`(Vue3 + TS + Vite,`npm run build` 產出靜態檔由 Nginx serve) |
| 前端靜態檔輸出 | `/var/www/ledger-frontend` |
| 對外 port | `17756`(FortiGate VIP 轉內部,無 HTTPS,見 `ops/ops-infra-public-access.md`) |

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

### Archive(已整併原始檔,保留回溯)

含三版 `update-deploy-sop-*` + 自動歸檔增修文件(已整併進 `ops/ops-deployment.md`)、三份消費品項疊代式功能文件(已整併進 `features/feature-tags.md`)、及其餘所有原始 `bug-fix-*`/`finance-*`/`software-architecture`/`github-feature`/`infra-public-access`/`migration-sop`/`第二期任務清單` 原檔。

## 六、已知待處理事項(截至 2026-07-10)

1. **Deploy key 尚未改回唯讀**:目前仍是 write access,待辦
2. **自動化部署尚未建立**:push 後自動觸發部署,目前暫緩,先手動跑穩定後再考慮
3. **無 HTTPS**:純 public IP 對外,無域名無法申請憑證,JWT token 可能被側錄,見 `ops/ops-infra-public-access.md`
4. **忘記密碼信件功能入口暫停**:程式碼已完成,Postfix 入口暫停
5. **歷史帳戶餘額落差已回補完成**,屬一次性腳本,非持續機制
6. **`client.ts` 全域固定 `Content-Type: application/json`**:未來新增檔案上傳功能時需記得清除此 header

## 七、下一步開發(優先順序,截至 2026-07-10)

**統計功能(A 系列,A1-A3 已完成)**
- [ ] A4 分類趨勢比較(依賴 A3)
- [ ] A5 同期比較 MoM/YoY(依賴 A1)
- [ ] A6 成員別統計
- [ ] A7 帳戶別統計
- [ ] A8 月底預估(依賴 A1)
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
