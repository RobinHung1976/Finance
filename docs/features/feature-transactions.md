# 功能現況:交易紀錄(Transactions)

## 一、後端

`app/routers/transactions.py`:

- CRUD(`create_transaction`/`update_transaction` 同步處理帳戶餘額連動與 `TransactionTag` 關聯)
- `list_transactions` 查詢參數:日期區間、`account_id`、`category_id`、`min_amount`/`max_amount`、`tag_ids: list[str] | None`
- 消費品項篩選為 **OR 語意**(交易掛任一被選取品項即列入)+ `join TransactionTag` + `.distinct()`(避免重複列出)

## 二、前端

頁面 `/transactions`(`src/views/TransactionsView.vue`)直接渲染 `src/components/TransactionList.vue`,分兩個面板:

**交易查詢**(條件一變就自動重新查詢,快速連續變動時只採用最後一次查詢結果)

- 開始/結束日期 + 快選 本月/上月/近 3 個月/今年(`utils/date.ts` 的 `presetRange()`,本地時區);預設本月 1 號 ~ 今天
- 類型 LED 按鍵:支出/收入,可只看其中一種(**前端篩選**,後端無 type 參數)
- 金額區間(後端 `min_amount`/`max_amount`)
- 「進階篩選」按鈕(顯示已套用數量)展開帳戶/分類/消費品項三個篩選器:
  - 帳戶:搜尋框 + 攤開按鈕網格(`AccountFilterPicker.vue`)
  - 分類:逐層鑽取麵包屑(`CategoryFilterPicker.vue`)+ 搜尋跨層級跳轉 + 清除
  - 消費品項:「最近使用/全部品項」分區 + 搜尋(`TagFilterPicker.vue`)+ 清除
- 「清除條件」:重設日期以外的所有條件(含類型、搜尋字)

**交易明細**

- 統計卡片:筆數、收入、支出、結餘(收入 − 支出)、帳戶總餘額(目前);下方一排各帳戶餘額(負數紅色)。筆數/收入/支出/結餘依**畫面上目前顯示的結果**計算(含類型與搜尋篩選)
- 搜尋框(前端):比對分類完整路徑、帳戶、消費品項、備註、金額
- 表格:日期(今天/昨天加註)、類型色塊、分類(`父 - 子` 完整路徑)、帳戶、消費品項 chip、備註、金額(收入綠 `+`、支出紅 `-`)、編輯/刪除;日期與金額欄可點擊排序(穩定排序,預設日期新到舊)
- 匯出 CSV(`utils/csv.ts`,前端產生):匯出目前畫面上的結果與排序;UTF-8 BOM(Excel 中文不亂碼);欄位 日期/類型/分類/帳戶/消費品項/備註/金額/收支(支出為負);文字格以 `= + - @` Tab CR 開頭時前面補單引號,避免 Excel 當公式執行(CSV injection);檔名 `交易紀錄_<起>_<迄>.csv`

**新增/編輯**:對話框 `src/components/TransactionFormDialog.vue`(原生 `<dialog>`,Esc 關閉),新增與編輯共用同一表單:

- 欄位:收支類型(LED 按鍵)、金額(正整數)、日期、帳戶、備註、分類(`CategoryPicker`)、消費品項(`TagPicker`)
- 新增時沿用上一次新增的類型/帳戶/分類,金額/備註/品項清空、日期重設為今天;第一次新增預設帳戶為 `is_default_expense`
- 切換收入/支出時清空分類(兩邊分類樹不同)
- 前端驗證:帳戶、分類必選,金額需為大於 0 的整數
- 儲存/刪除成功後重新載入帳戶(餘額已變動)與交易;刪除前 `confirm()` 顯示日期/分類/金額

`src/api/ledgerApi.ts`(原 `ledger.ts`,因與 `types/ledger.ts` 同名易混淆而改名):`fetchTransactions` 用 `URLSearchParams` 手動組 query string(而非讓 axios 序列化陣列參數),確保 `tag_ids` 重複 key 格式與 FastAPI `Query(list[str])` 相容。

## 三、已知限制 / 後續可考慮

1. 消費品項篩選僅支援 OR 語意,若未來需要 AND(必須同時掛滿所有勾選品項),需額外設計 `HAVING COUNT(DISTINCT tag_id) = 選取數量` 或子查詢
2. 分類篩選為「精確符合單一分類」,不含子分類
3. 「進階篩選」目前是單一收合區塊,篩選欄位若持續增加可評估改用分頁籤
4. 類型篩選與搜尋為前端篩選,只作用在已查回的資料;交易量大時若要分頁,需改為後端參數
5. 表格在窄螢幕需橫向捲動(手機版擱置,見 `feature-ui-theme.md`)

## 四、沿革

| 日期 | 內容 | 詳情 |
|---|---|---|
| 2026-07-07 | CategoryPicker 搜尋功能上線 | `changelog-details/20260707-category-picker-search.md` |
| 2026-07-07 | 消費品項掛載、chip 顯示、金額範圍篩選 | `changelog-details/20260707-tag-feature-launch.md` |
| 2026-07-10 | 消費品項篩選 + 篩選 UI 改為進階篩選面板(含帳戶/分類篩選器改版) | `changelog-details/20260710-transaction-tag-filter-advanced-search.md` |
| 2026-11-06 | 改為查詢面板 + 報表表格(統計卡片、排序、搜尋、類型篩選)、新增/編輯改對話框、匯出 CSV | `changelog-details/20261106-transactions-report-view.md` |
