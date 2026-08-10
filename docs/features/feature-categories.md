# 功能現況:分類(Categories)

## 一、結構

分類樹採**兩層結構**(大類 > 細項),原第三層「店家」節點已透過一次性遷移改用消費品項(Tag)表示,詳見 `feature-tags.md`。

## 二、後端

`app/routers/categories.py`:CRUD(鄰接表),`PATCH /{category_id}` 支援改名。分類統計(A3)採 Recursive CTE 撈樹 + 金額彙總,`category_id` 需顯式 `str()` 轉換(Postgres UUID 不會自動轉 Pydantic `str`)。

## 三、前端

| 元件 | 說明 |
|---|---|
| `CategoryPicker.vue` | 交易表單用,逐層鑽取 + 搜尋框(不限層級比對名稱,結果顯示完整路徑,最多 30 筆);新增同名分類會被阻擋 |
| `CategoryTreeNode.vue` | 遞迴摺疊樹節點,含改名按鈕(inline 編輯,同層重複名稱阻擋) |
| `CategoryList.vue` | 管理頁。上半部複用 `CategoryPicker`(`hideSelectedHint=true`,隱藏選取提示,因管理頁用不到選定分類這個功能)。下半部「全部分類」預設樹狀瀏覽;輸入搜尋框後改顯示扁平清單(完整路徑,可就地改名/刪除),清空搜尋恢復樹狀 |
| `CategoryFilterPicker.vue` | 交易篩選列專用,逐層鑽取麵包屑(比照 `CategoryPicker.vue`)+ 搜尋跨層級跳轉 + 「所有分類」清除按鈕 |

## 四、已知限制 / 後續可考慮

1. 樹狀節點僅顯示直屬子分類數量,不含底下交易筆數;要判斷「能否安心刪除」目前仍依賴後端刪除時的錯誤訊息
2. 搜尋結果上限 50 筆(`CategoryFilterPicker`)/ 30 筆(`CategoryPicker`),分類數量持續增加可視情況調整或加分頁
3. 篩選目前是「精確符合單一分類」,不含子分類;若要「篩選大類時連同子分類都列入」需額外設計遞迴查詢

## 五、沿革

| 日期 | 內容 | 詳情 |
|---|---|---|
| 2026-07-07 | 交易分類編輯 UX:CategoryPicker 新增搜尋功能 | `changelog-details/20260707-category-picker-search.md` |
| 2026-07-07 | 消費品項功能上線,連帶分類樹第三層遷移 + 分類改名 API 串接 | `changelog-details/20260707-tag-feature-launch.md` |
| 2026-07-08 | 分類管理頁 UX 改善:搜尋改名/刪除、移除多餘選取提示 | `changelog-details/20260708-category-management-search.md` |
| 2026-07-10 | 篩選列分類選擇改回逐層鑽取麵包屑(原本嘗試攤開全部,使用者反映太亂) | `changelog-details/20260710-transaction-tag-filter-advanced-search.md` |
