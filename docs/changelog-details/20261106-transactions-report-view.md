# 2026-11-06 交易紀錄頁改為查詢面板 + 報表表格(前端改版 E2-1)

## 背景

前端金屬主題上線後(`20261106-ui-metal-theme-layout.md`),交易紀錄頁內部仍是舊樣式:依日期分組的白色卡片、135 處 inline style 中最大宗(16 處 + 247 行 scoped style)。希望改成與 Teams Call Report 相同的「查詢表單 + 報表」版面:欄位標籤在上的查詢區、LED 類型按鍵、統計卡片、可排序表格、匯出 CSV。

## 決策

| 項目 | 決定 | 理由 |
|---|---|---|
| 新增/編輯位置 | 對話框(原生 `<dialog>`),新增與編輯共用 `TransactionFormDialog.vue` | 改成表格後,列內展開放不下 `CategoryPicker`/`TagPicker`;共用表單避免兩份驗證邏輯不一致 |
| 查詢觸發 | 條件一變就自動查詢(維持原行為),不加「執行查詢」按鈕 | 本機 DB 查詢很快;TCR 用按鈕是因為 Microsoft Graph 查詢慢 |
| 匯出 CSV | 這次一起做,前端產生目前畫面結果 | 順便完成待辦 C1;不需新增後端 API |
| 類型篩選 | 前端篩選 | 後端 `list_transactions` 沒有 type 參數,資料已全部查回,不值得為此改 API |
| 日期分組 | 改為表格日期欄,今天/昨天加註 | 表格可排序後分組標題不再適用 |
| 新增預設值 | 沿用上一次新增的類型/帳戶/分類 | 原本表單關閉後也保留這三項,連續記帳較快,維持此行為 |

## 修改內容(`update56.sh`)

新增:

- `src/components/TransactionFormDialog.vue`:新增/編輯對話框,`defineExpose({ openCreate, openEdit })` 供父元件呼叫,儲存成功 emit `saved`
- `src/utils/csv.ts`:`toCsv()`(每格加雙引號、跳脫雙引號、文字格防公式注入)、`downloadCsv()`(UTF-8 BOM、Blob 下載)

修改:

- `src/components/TransactionList.vue`:整份改寫(查詢面板、統計卡片、搜尋、排序表格、CSV);移除 `refreshKey` prop(改成路由後每次進入頁面都重新掛載載入,已無作用);查詢加序號,快速連續變動條件時只採用最後一次結果
- `src/views/TransactionsView.vue`:不再外包 `.panel`(`TransactionList` 自帶兩個面板)
- `src/styles/theme.css`:新增 `.form-grid`/`.form-field`、`.stat-grid`/`.stat`、`.badge`、`.chip`、`.amount`、`.toolbar`、`.grid th.sortable`、`dialog.modal`、`.modal-foot`
- `src/components/AppIcon.vue`:新增 income/expense/plus/edit/trash/download/search/filter/x/table 圖示

## 驗證

- 開發環境以 Playwright + 假資料實測:類型切換、搜尋、排序、CSV 內容(BOM、欄位、負數、公式字元前綴)、新增(驗證訊息、送出 payload)、編輯(PATCH payload)、刪除(確認訊息、DELETE)皆正常
- `update56.sh`:sha256 比對 4 個既有檔案,腳本內建置通過才 commit
- 部署後 `ledger-api` active、`/` 與 `/health` 皆 200
- 使用者實測(2026-11-06):新增(沿用上一筆帳戶/分類、未選分類的錯誤訊息)、編輯(金額/日期/收支互換,餘額更新)、刪除(確認訊息、餘額回補)、進階篩選與清除條件、CSV 以 Excel 開啟中文正常且筆數一致、其他頁不受影響,全部正常

## 目前狀態

交易紀錄頁完成 E2;帳戶 → 分類 → 消費品項 → 匯入匯出尚未改版,`style.css` 相容層仍保留。
