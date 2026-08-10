# 功能現況:消費品項(Tag)

## 一、設計概念

消費品項與分類是**兩個正交維度**,不互相取代:

- **分類**:負責結構性歸類(如「飲食 > 午餐」),分類樹完全維持既有的兩層結構(大類 > 細項)
- **消費品項(Tag)**:負責可能橫跨多個分類、需要共用的具體店家/項目名稱(如「三媽」同時出現在午餐、晚餐)

一筆交易可掛 0~多個消費品項(多對多),透過既有 `Tag`/`TransactionTag` 資料表實作,household 內名稱唯一性由 DB constraint 把關。

## 二、後端

| 檔案 | 說明 |
|---|---|
| `app/schemas_tag.py` | `TagCreate`、`TagUpdate`、`TagOut`(含 `usage_count: int`、`last_used_date: str \| None`) |
| `app/routers/tags.py` | 消費品項 CRUD(`GET/POST /tags`、`PATCH/DELETE /tags/{id}`);`list_tags` 用 `outerjoin`(`Tag` → `TransactionTag` → `Transaction`)+ `func.count`/`func.max(date)` 在 DB 層一次彙總,依 `usage_count desc, name asc` 排序 |
| `app/routers/transactions.py` | `create_transaction`/`update_transaction` 同步處理 `TransactionTag` 關聯(`_validate_tag_ids`、`_set_transaction_tags`);`list_transactions` 支援 `min_amount`/`max_amount` 篩選 |
| `app/models.py` | `Transaction.tags` relationship(`viewonly=True`,寫入一律由 router 手動操作 `TransactionTag`) |

## 三、前端

| 元件 | 說明 |
|---|---|
| `TagPicker.vue` | 交易表單消費品項多選器。分「最近使用」(依 `last_used_date`,取前 8)/「全部品項」兩區,搜尋時收斂為單一清單;支援就地新增 |
| `TagList.vue` | 消費品項管理頁。搜尋框 + chip 網格版面(取代逐行排列);分「最近使用」(取前 12)/「全部品項」兩區;點擊 chip 開單一詳情面板(使用次數、最後使用日期、改名/刪除);刪除確認文字依 `usage_count` 是否為 0 顯示不同訊息 |
| `CategoryFilterPicker.vue` | 篩選列專用分類選擇器,按鈕觸發 + 搜尋 + 下拉結果清單,取代原生 `<select>`(因分類已 80+ 項) |
| `TransactionList.vue` | 新增/編輯表單掛 `TagPicker`;交易卡片消費品項改為獨立彩色 chip 顯示,與帳戶/備註分行 |

## 四、統計串接

統計頁「消費品項排行」子分頁(`TagBreakdownChart.vue`)採**長條圖**(非圓餅圖,因消費品項是多對多、加總可能超過支出總額),詳見 `feature-stats.md`。金額計算採「該筆交易全額計入每個掛載品項」,不依品項數量分攤。

## 五、已知限制 / 後續可考慮

1. 「最近使用」目前依**交易日期**排序,而非實際建立時間;若未來大量補登舊帳,排序會失準。要改精確版需在 `transactions` 加 `created_at` 欄位(需 migration)
2. 尚無「新增時相似名稱提醒」(如「50嵐」vs「50嵐飲料」)與「合併重複品項」功能
3. 若需要「某分類底下有哪些常見消費品項」的交叉統計,需另外設計 API,屬於較大工程

## 六、沿革(異動歷史)

| 日期 | 內容 | 詳情 |
|---|---|---|
| 2026-07-07 | 初版上線;分類樹第三層店家節點遷移為消費品項(`migrate_leaf_categories_to_tags.py`) | `changelog-details/20260707-tag-feature-launch.md` |
| 2026-07-08 | UX 改善:搜尋、使用統計、最近使用分區、chip 版面 | `changelog-details/20260708-tag-ux-improvement.md` |
| 2026-07-08 | 統計圖表加入消費品項排行 | `changelog-details/20260708-tag-breakdown-stats.md` |
