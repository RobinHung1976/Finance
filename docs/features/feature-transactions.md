# 功能現況:交易紀錄(Transactions)

## 一、後端

`app/routers/transactions.py`:

- CRUD(`create_transaction`/`update_transaction` 同步處理帳戶餘額連動與 `TransactionTag` 關聯)
- `list_transactions` 查詢參數:日期區間、`account_id`、`category_id`、`min_amount`/`max_amount`、`tag_ids: list[str] | None`
- 消費品項篩選為 **OR 語意**(交易掛任一被選取品項即列入)+ `join TransactionTag` + `.distinct()`(避免重複列出)

## 二、前端

`src/components/TransactionList.vue`:

- 新增/編輯表單:`date`/`amount` 編輯時帶入原始值,搭配 `CategoryPicker`(搜尋)、`TagPicker`(消費品項多選)
- 交易卡片:消費品項獨立彩色 chip 顯示,與帳戶/備註分行
- 篩選列:日期區間、金額區間永遠可見;帳戶/分類/消費品項收合進「進階篩選」按鈕(顯示已套用篩選數量),展開後:
  - 帳戶:搜尋框 + 攤開按鈕網格(`AccountFilterPicker.vue`)
  - 分類:逐層鑽取麵包屑(`CategoryFilterPicker.vue`)+ 搜尋跨層級跳轉 + 清除
  - 消費品項:「最近使用/全部品項」分區 + 搜尋(`TagFilterPicker.vue`)+ 清除

`src/api/ledgerApi.ts`(原 `ledger.ts`,因與 `types/ledger.ts` 同名易混淆而改名):`fetchTransactions` 用 `URLSearchParams` 手動組 query string(而非讓 axios 序列化陣列參數),確保 `tag_ids` 重複 key 格式與 FastAPI `Query(list[str])` 相容。

## 三、已知限制 / 後續可考慮

1. 消費品項篩選僅支援 OR 語意,若未來需要 AND(必須同時掛滿所有勾選品項),需額外設計 `HAVING COUNT(DISTINCT tag_id) = 選取數量` 或子查詢
2. 分類篩選為「精確符合單一分類」,不含子分類
3. 「進階篩選」目前是單一收合區塊,篩選欄位若持續增加可評估改用分頁籤

## 四、沿革

| 日期 | 內容 | 詳情 |
|---|---|---|
| 2026-07-07 | CategoryPicker 搜尋功能上線 | `changelog-details/20260707-category-picker-search.md` |
| 2026-07-07 | 消費品項掛載、chip 顯示、金額範圍篩選 | `changelog-details/20260707-tag-feature-launch.md` |
| 2026-07-10 | 消費品項篩選 + 篩選 UI 改為進階篩選面板(含帳戶/分類篩選器改版) | `changelog-details/20260710-transaction-tag-filter-advanced-search.md` |
