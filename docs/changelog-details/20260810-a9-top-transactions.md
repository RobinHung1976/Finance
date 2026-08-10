# A9 最大單筆排行上線

## 一、背景

`feature-stats.md` 下一步開發清單的 A 系列統計項目之一。討論設計方向後定案採簡單版:比照 `tag-breakdown` 的 filter 慣例(`start_date`/`end_date`/`type`,選填+預設今年區間),不接進階篩選(帳戶/分類/消費品項篩選),優先求快、跟現有模式一致。

## 二、決策

- **Filter 範圍**:只吃 `start_date`/`end_date`/`type`,不比照交易列表的進階篩選面板,降低工作量,真的有需求再疊加
- **`limit` 可調**:預設 5、上限 20(前端下拉選單 5/10/20)
- **直接 join 帳戶/分類名稱回傳**:排行榜屬一次性瀏覽情境,後端直接組好 `account_name`/`category_name`,前端不用另外查表 map,減少前端邏輯
- **收入/支出皆可查**:預設 `expense`,可切換 `income`,跟 `category-breakdown`/`tag-breakdown` 的切換模式一致

## 三、修改內容

### 後端(`update50.sh`)

- `app/schemas_ledger.py`:新增 `TopTransactionItem`(`id`/`amount`/`date`/`note`/`account_name`/`category_name`)、`TopTransactionsOut`
- `app/routers/stats.py`:新增 `GET /stats/top-transactions`
  - join `Account`/`Category` 取得名稱,依 `amount` 降冪排序、`limit` 截斷
  - 沿用既有 `_resolve_range()` 處理選填區間,與 `monthly-trend`/`category-breakdown`/`tag-breakdown` 行為一致

### 前端(`update51.sh`)

- `src/types/ledger.ts`:新增對應型別
- `src/api/ledgerApi.ts`:新增 `fetchTopTransactions()`
- 新元件 `src/components/TopTransactionsList.vue`:排版比照 `TagBreakdownChart.vue`(收支切換 + 長條圖列表),額外多一個 `limit` 下拉選單,每列顯示排名/分類/帳戶/金額/日期
- `src/views/DashboardView.vue`:新增第四個統計子分頁「最大單筆排行」,與其他三個子分頁共用同一組 `DateRangePicker`

### 未變動

- 未修改 `models.py`,無需 Alembic migration
- 不接進階篩選(帳戶/分類/消費品項篩選)
- `monthly-trend`/`category-breakdown`/`tag-breakdown` 三支既有 API 邏輯未受影響

## 四、目前狀態

- ✅ 後端 API 測試正確(預設 5 筆降冪排列、`limit`/`type` 參數皆正常運作)
- ✅ 前端四個統計子分頁切換正常,排行榜顯示正確,`vue-tsc` 型別檢查通過、`deploy.sh` 完整跑完
- ✅ 使用者實際測試通過
