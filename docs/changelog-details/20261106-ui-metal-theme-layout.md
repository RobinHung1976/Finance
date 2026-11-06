# 2026-11-06 前端改版:金屬主題 + 側欄版面(第 0、1 步)

## 背景

想把前端改成與 Teams Call Report Web 版相同的金屬風格(拉絲鋼底、深色側欄、立體按鍵、LED 燈條),但不使用該專案的易通科技品牌。原本前端狀況:

- `App.vue` 只有 `<router-view />`,沒有共用版面;主要功能全在 `DashboardView.vue` 以 `ref` 切換六個分頁,不是路由
- 樣式分散:全域 `style.css` 2.3KB、23 個 `.vue` 檔共 135 處 inline style、約 25 種寫死色碼,混用 Finance 綠/Tailwind 灰/靛藍三套配色
- 完全沒有 `@media`

## 決策

| 項目 | 決定 | 理由 |
|---|---|---|
| 分頁 vs 路由 | 改為子路由(`/stats` 等),父路由 `AppLayout.vue` | 側欄可直接用 `router-link` 與 active 狀態;瀏覽器上一頁可用;PWA 可直接開到某頁 |
| 品牌色 | 墨綠金屬,基準 `#1f5f4f` | 本來就是 Finance 的主色與 PWA `theme_color`,同時與 TCR 的藍色區隔 |
| 品牌 | 「家庭理財 / Household Finance Ledger」+ 帳本圖示 | 不使用易通科技名稱與 ESi 字標 |
| 手機版 | 先不做 | 僅保留窄螢幕側欄疊上方的基本樣式,避免手機上完全擠壞 |
| 舊 class 衝突 | 不改名,`style.css` 改為相容層 | 原規劃把 12 個檔案的 `.btn-primary`/`.field` 換成 TCR 命名;實作時改為沿用舊名稱、換金屬外觀,這次就不必動元件檔,降低風險,留到第 2 步逐頁整理時再換 |
| 統計頁篩選狀態 | 放 Pinia store(`statsFilter.ts`) | 改成路由後切頁會 unmount,用 store 保留原本「切到別的分頁再回來,區間不變」的行為 |
| `TransactionList` 的 `refreshKey` | 固定傳 `0` | 原用途是帳戶/分類變動後通知交易頁重載;改成路由後每次進入交易頁都會重新掛載並載入,不再需要 |

## 修改內容(`update54.sh`)

新增:

- `src/styles/theme.css`:主題本體(由 TCR `app.css` 移植並精簡,藍色金屬改墨綠金屬,移除 TCR 專用樣式)
- `src/layouts/AppLayout.vue`:側欄(品牌列、目前帳本、選單、時鐘)+ 頂部列(標題、身分、登出)
- `src/components/AppIcon.vue`、`src/components/BrandBlock.vue`
- `src/views/StatsView.vue`(統計子分頁改 `.key` LED 按鍵)、`TransactionsView`/`AccountsView`/`CategoriesView`/`TagsView`/`TransferView.vue`(以 `.panel` 包既有元件)
- `src/stores/statsFilter.ts`、`src/utils/date.ts`

修改:

- `router/index.ts`:子路由 + `meta.title`;`dashboard` 改為導向 `stats`;未知路徑導回首頁
- `main.ts`:先載入 `styles/theme.css` 再載入 `style.css`
- `style.css`:改為相容層
- `DateRangePicker.vue`:快選改為 本月/上月/近 3 個月/今年,目前區間按鈕呈按下狀態
- `MembersView.vue`、`AuditLogView.vue`:移除各自的頁首(返回首頁、登出改由版面提供),改用面板/表格/按鍵樣式;移除過時提示文字「交易紀錄、多帳戶與統計圖表功能將在下一步接續開發」
- `LoginView`/`RegisterHouseholdView`/`ForgotPasswordView`/`ResetPasswordView.vue`:卡片上方加 `<BrandBlock />`

刪除:`DashboardView.vue`

## Bug 修正:統計頁「今天」在早上 8 點前變成昨天

- **現象**:台北時間 00:00–07:59 開統計頁,預設結束日是前一天,當天交易不會算進統計
- **原因**:`DashboardView.vue` 與 `DateRangePicker.vue` 以 `new Date().toISOString().slice(0, 10)` 取今天;`toISOString()` 回傳 UTC,台北為 UTC+8
- **修正**:新增 `utils/date.ts`,以 `getFullYear()`/`getMonth()`/`getDate()`(本地時區)組字串;統計頁預設區間與快選都改用 `presetRange()`

## 部署與驗證

- `update54.sh`:前置驗證以 sha256 比對 11 個要覆寫/刪除的檔案,與產生腳本時看到的版本不一致就中止;腳本內先跑 `npm install && npm run build`,失敗自動還原、不 commit
- commit:`59775dc`(chore 歸檔)、`aa49cff`(feat)
- `deploy.sh`:`ledger-api` active,`/` 與 `/health` 皆 200
- 使用者實測(2026-11-06):登入頁品牌列、登入後進 `/stats`、側欄各頁 active 狀態與帳本名稱、交易新增/編輯/刪除/進階篩選、統計四個子分頁與日期快選(切頁回來區間保留)、成員管理改名、瀏覽器上一頁,全部正常

## 目前狀態

第 0、1 步完成。第 2 步(逐頁清 inline style、移除相容層)、第 3 步(圖表配色)未開始,見 `features/feature-ui-theme.md` 第五節。
