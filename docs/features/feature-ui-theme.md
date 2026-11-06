# 功能現況:前端版面與主題(UI Theme / Layout)

## 一、範圍

- 全站金屬主題(拉絲鋼內容區、深色拉絲側欄、金屬面板與按鍵),品牌色墨綠 `#1f5f4f`(同 PWA `theme_color`)
- 登入後頁面共用側欄 + 頂部列版面(`AppLayout.vue`),功能頁一律為子路由
- 登入/註冊/忘記密碼/重設密碼頁的卡片上方顯示品牌列
- 只做桌面版;窄螢幕(≤ 860px)僅保留側欄疊到上方的基本樣式,完整手機版未做(見第六節)

## 二、路由與版面

| 路徑 | 頁面 | 說明 |
|---|---|---|
| `/` | — | 名稱 `dashboard`,導向 `/stats`(`LoginView`/`RegisterHouseholdView`/路由守衛都以 `dashboard` 導向首頁) |
| `/stats` | `StatsView.vue` | 四個統計子分頁 + 日期區間(見 `feature-stats.md`) |
| `/transactions` | `TransactionsView.vue` | 包 `TransactionList.vue` |
| `/accounts` | `AccountsView.vue` | 包 `AccountList.vue` |
| `/categories` | `CategoriesView.vue` | 包 `CategoryList.vue` |
| `/tags` | `TagsView.vue` | 包 `TagList.vue` |
| `/transfer` | `TransferView.vue` | 包 `ExcelImportExport.vue` |
| `/members` | `MembersView.vue` | 成員管理(見 `feature-household.md`) |
| `/audit-logs` | `AuditLogView.vue` | 操作紀錄,`meta.requiresAdmin`,非管理者導回首頁 |
| 其他未知路徑 | — | 導向 `dashboard` |

以上子路由的父路由為 `src/layouts/AppLayout.vue`,頁面標題取自 `route.meta.title`。

`AppLayout.vue` 內容:

| 區塊 | 說明 |
|---|---|
| 品牌列 | `BrandBlock.vue`:帳本圖示 +「家庭理財 / Household Finance Ledger」+「FINANCE LEDGER」琥珀色指示燈;登入類頁面共用同一元件 |
| 目前帳本 | `fetchMyHousehold()` 取得名稱,失敗時顯示「載入中…」不阻斷畫面;一個使用者只屬於一個帳本,不做切換清單 |
| 選單 | 報表(統計、交易紀錄)/ 帳務設定(帳戶、分類、消費品項、匯入/匯出)/ 帳本管理(成員管理、操作紀錄),「操作紀錄」僅 `role === 'admin'` 顯示;`router-link` 的 `active-class` 標示目前頁面 |
| 側欄底部 | 台北時間時鐘(`Intl.DateTimeFormat`,`timeZone: 'Asia/Taipei'`,每 15 秒更新) |
| 頂部列 | 頁面標題、登入身分(管理者/使用者)、登出按鈕 |

## 三、樣式檔案

| 檔案 | 說明 |
|---|---|
| `src/styles/theme.css` | 主題本體:`:root` 設計變數(金屬漸層、品牌色、狀態色、圓角、陰影)+ 版面(`.layout`/`.sidebar`/`.topbar`/`.content`)+ 元件 class |
| `src/style.css` | **相容層**:舊 class(`.btn-primary`/`.field`/`.error-banner`/`.auth-page`/`.auth-card`/`.auth-switch`)沿用名稱、改成金屬外觀;舊變數(`--color-primary`/`--color-border`/`--color-surface` …)對應到新變數。`main.ts` 先載入 `theme.css` 再載入本檔 |
| `src/components/AppIcon.vue` | 線條圖示元件(24×24 stroke),圖示路徑為檔內常數,`v-html` 不含使用者輸入 |

`theme.css` 的元件 class(新頁面/改版頁面請用這些,不要再寫 inline style):

| class | 用途 |
|---|---|
| `.panel` / `.panel-head` / `.panel-body` | 金屬面板;每個子路由頁面最外層都是 `.panel` |
| `.btn` / `.btn.primary` / `.btn.sm` / `.btn.ghost` / `.btn.danger` / `.btn.on` | 金屬按鍵;`.primary` 為深色鍵,`.on` 為按下狀態(如日期快選目前區間) |
| `.keypad` + `.key` / `.key.active` | 單選按鍵,底部 LED 燈條(未選灰、選取亮綠);用於統計子分頁 |
| `.grid`(table)+ `.num` / `.nowrap` | 金屬表頭表格,`.num` 數字右對齊等寬 |
| `.pill` / `.pill.ok` / `.warn` / `.bad`、`.household-badge` | 標籤 |
| `.form-grid` + `.form-field`(`.wide` / `.span2`) | 查詢/表單欄位格線,標籤在上 |
| `.stat-grid` + `.stat`(`.stat-value.income` / `.expense`) | 報表統計卡片 |
| `.badge.income` / `.badge.expense`、`.chip`、`.amount.income` / `.expense` | 類型色塊、消費品項小標籤、金額正負色 |
| `.toolbar`、`.grid th.sortable` | 表格上方工具列、可點擊排序表頭 |
| `dialog.modal` + `.modal-foot` | 原生 `<dialog>` 對話框(`showModal()`) |
| `.hint` / `.empty` / `.row` / `.notice` / `.flash` | 輔助樣式 |
| 全域 `input` / `select` / `textarea` | 內凹金屬輸入框(元件 scoped style 仍可覆寫) |

## 四、日期工具

`src/utils/date.ts`:`todayLocal()`、`toLocalISODate()`、`presetRange('thisMonth' | 'lastMonth' | 'last3Months' | 'thisYear')`。**一律以瀏覽器本地時區組日期字串,不可用 `toISOString()`**(UTC,台北 00:00–07:59 會得到前一天)。`TransactionList.vue` 內另有同邏輯的 `todayLocalISODate()`,改版該頁時可改用此工具。

## 五、改版進度

| 階段 | 內容 | 狀態 |
|---|---|---|
| 第 0 步 | Dashboard 分頁改子路由 + `AppLayout` | ✅ 2026-11-06 |
| 第 1 步 | `theme.css` + 相容層 + 品牌列 + 統計頁/成員管理/操作紀錄套用新樣式 | ✅ 2026-11-06 |
| 第 2 步 | 逐頁清除 inline style 與寫死色碼,改用 `theme.css` class(交易紀錄 → 帳戶 → 分類 → 消費品項 → 匯入匯出);全部改完後移除 `style.css` 相容層 | 進行中:交易紀錄 ✅ 2026-11-06(查詢面板 + 報表表格,見 `feature-transactions.md`) |
| 第 3 步 | 圖表配色統一(抽 `utils/chartTheme.ts`,三張圖表共用收入/支出色與分類色盤) | 未開始 |

## 六、已知限制 / 後續可考慮

1. 手機版未做(2026-11-06 決定先取消):窄螢幕時側欄整塊疊在內容上方,需捲動才看到內容;如重啟,需另做抽屜選單或底部導覽列,並關掉 `body` 的 `background-attachment: fixed`(iOS Safari 不支援且捲動易卡頓)
2. 第 2 步完成前,帳戶/分類/消費品項/匯入匯出頁面內部仍是舊樣式(白色卡片 + inline style),外框已是金屬面板
3. `AppLayout` 與 `MembersView` 各自呼叫一次 `fetchMyHousehold()`;在成員管理頁改帳本名稱後,側欄名稱要重新整理才更新

## 七、沿革

| 日期 | 內容 | 詳情 |
|---|---|---|
| 2026-11-06 | 金屬主題 + 側欄版面上線,Dashboard 分頁改子路由(`update54.sh`) | `changelog-details/20261106-ui-metal-theme-layout.md` |
| 2026-11-06 | E2 交易紀錄頁改版,`theme.css` 新增表單格線/統計卡片/對話框等 class(`update56.sh`) | `changelog-details/20261106-transactions-report-view.md` |
