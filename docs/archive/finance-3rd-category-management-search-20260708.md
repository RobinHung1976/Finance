# 功能修改:分類管理頁 UX 改善 —— 搜尋改名/刪除、移除多餘選取提示

建立日期:2026-07-08

## 一、背景與需求

`分類` 頁面(`CategoryList.vue`)使用起來不好找、不好改:

1. 上半部瀏覽/新增分類區塊實際上是複用 `CategoryPicker.vue`,但該頁面用不到「選定分類」這個功能,卻仍會顯示「已選擇：/尚未選擇分類」提示,造成使用者混淆(誤以為在選擇什麼)
2. 下半部「全部分類」是收合式樹狀結構,改名/刪除只能在樹狀節點上操作,分類層級一多,要找到目標分類得一層層展開,沒有搜尋能力

## 二、問題定位與決策

| 問題 | 根因 | 解法 |
|---|---|---|
| 上半部出現無意義的「已選擇/尚未選擇」提示 | `CategoryList.vue` 的 `browsingSelection` 沒有被任何邏輯消費,純粹複用 `CategoryPicker` 做「瀏覽 + 新增分類」,但該提示是 `CategoryPicker` 內建、預設一定顯示 | `CategoryPicker.vue` 新增 `hideSelectedHint` prop(預設 `false`,不影響交易表單等其他既有用法),`CategoryList.vue` 傳入 `true` 隱藏該提示 |
| 改名/刪除只能在樹狀結構操作,收合狀態下不好找 | `CategoryTreeNode.vue` 預設全部收合,且沒有搜尋機制 | 不修改 `CategoryTreeNode.vue` 本身,改在 `CategoryList.vue` 的「全部分類」區塊上方新增搜尋框:有輸入文字時,改成顯示**扁平清單**(完整路徑 + 就地改名/刪除);清空搜尋框則恢復原本樹狀瀏覽 |

**決策考量**:不改動 `CategoryTreeNode.vue`(遞迴展開邏輯)與 `CategoryFilterPicker.vue`(交易篩選用),避免影響既有功能範圍,改動集中在管理頁本身。

## 三、修改內容

### 修改檔案

| 檔案 | 異動內容 |
|---|---|
| `src/components/CategoryPicker.vue` | 新增 `hideSelectedHint?: boolean` prop,`true` 時隱藏「已選擇：/尚未選擇分類」提示區塊 |
| `src/components/CategoryList.vue` | 1. 呼叫 `CategoryPicker` 時傳入 `:hide-selected-hint="true"`<br>2.「全部分類」上方新增搜尋框<br>3. 搜尋時顯示扁平清單(完整路徑,邏輯與 `CategoryPicker`/`CategoryFilterPicker` 既有的 `ancestorChain`/`fullPathLabel` 做法一致),清單項目可直接改名/刪除<br>4. 清空搜尋框恢復原本樹狀瀏覽,`CategoryTreeNode` 邏輯不受影響 |

### 技術重點

- 搜尋比對邏輯(不限層級、完整路徑顯示)沿用既有 `CategoryPicker.vue`/`CategoryFilterPicker.vue` 的 pattern,未重新發明
- `handleRename` 改為回傳 `boolean`,搜尋結果的就地改名表單依回傳值決定是否關閉編輯狀態(成功才關閉,失敗維持開啟讓使用者修正)
- `hideSelectedHint` 預設 `false`,交易表單等其他呼叫 `CategoryPicker` 的地方不受影響

## 四、目前狀態

- ✅ 管理頁上半部瀏覽/新增分類區塊不再顯示無意義的選取提示
- ✅「全部分類」新增搜尋框,可直接搜尋跨層級分類並就地改名/刪除
- ✅ 清空搜尋框後樹狀瀏覽功能正常,未受影響
- ✅ 交易表單等其他使用 `CategoryPicker` 的地方,選取提示功能正常未受影響
- ✅ 已測試驗證通過

## 五、後續可考慮事項

1. 目前「全部分類」樹狀節點僅顯示**直屬子分類數量**(`children.length`),不含該分類底下的交易筆數,若要判斷「這個分類能不能安心刪除」,目前仍需依賴後端刪除時的錯誤訊息(「此分類已有交易紀錄使用中」)。若之後想在畫面上直接看到每個分類的交易筆數,需要後端 `list_categories` 額外用 `JOIN`/`GROUP BY` 彙總(作法可比照 `tags.py` 的 `usage_count` 做法),屬於較大工程,先不列入本次範圍
2. 搜尋結果目前上限 50 筆(與 `CategoryFilterPicker.vue` 一致),若分類數量持續大幅增加,可視情況調整或加分頁
