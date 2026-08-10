# 功能修改:消費品項(Tag)UX 改善 —— 搜尋、使用統計、最近使用、Chip 版面

建立日期:2026-07-08

## 一、背景與需求

`finance-3rd-tag-feature-category-search-20260707.md` 上線後,消費品項數量持續增加,衍生兩個新痛點:

1. **消費品項管理頁**:品項逐行往下排列(`row-card`),數量一多要一直往下捲,難以掃視、也難以判斷哪些是常用/該清理的品項
2. **交易紀錄新增/編輯的消費品項下拉選單**(`TagPicker.vue`):使用一段時間後容易忘記以前用過的確切命名,光靠搜尋(需要先知道關鍵字)無法解決「不確定名字」的情境

## 二、討論與決策

### 排序依據:交易日期 vs 實際建立時間

「最近使用」判斷依據有兩個選項:

| 選項 | 說明 | 是否需要 Migration |
|---|---|---|
| A. 交易日期(`Transaction.date`) | 依「這筆交易發生的日期」判斷 | ❌ 不需要 |
| B. 實際建立時間 | 依「使用者實際按下新增的時間」判斷,不受補登舊帳影響 | ✅ 需要,`transactions` 表目前無 `created_at` 欄位 |

**決策:採用 A(交易日期)**。目前記帳習慣多為當天記當天,兩者差異僅在大量回溯補登舊帳時才明顯,暫不需要為此新增欄位與 migration。若未來補登需求變多,可再評估加欄位改用 B。

### 是否加入排序切換(常用/A-Z/最少使用優先)

討論後**決定不做**。目前的「最近使用 + 全部品項」兩區分法,加上既有搜尋框,已足夠應付目前規模;額外排序切換的邊際效益不高,先不列入本次範圍。

## 三、後端變更

### 修改檔案

| 檔案 | 異動內容 |
|---|---|
| `app/schemas_tag.py` | `TagOut` 新增 `usage_count: int = 0`、`last_used_date: str \| None = None` |
| `app/routers/tags.py` | `list_tags` 改用 `outerjoin`(`Tag` → `TransactionTag` → `Transaction`)+ `func.count`/`func.max(date)` 一次彙總,依 `usage_count desc, name asc` 排序;`create_tag`/`update_tag` 回傳同步補上 `usage_count`/`last_used_date`(新增 `_tag_stats` helper 計算) |

### 技術重點

- 筆數與最後使用日期皆在 DB 層一次彙總(`GROUP BY`),不把交易全部拉回 Python 迭代,作法與既有 `stats.py`/`recalc_account_balances.py` 一致
- `last_used_date` 為 `None` 代表該品項尚未掛用在任何交易上

## 四、前端變更

### 修改檔案

| 檔案 | 異動內容 |
|---|---|
| `src/types/ledger.ts` | `TagOut` 補上 `usage_count: number`、`last_used_date: string \| null` |
| `src/components/TagList.vue`(消費品項管理頁) | 1. 新增搜尋框<br>2. 品項改為 **chip 網格**(取代逐行 `row-card`)<br>3. 分「最近使用」(依 `last_used_date` 排序,取前 12)/「全部品項」兩區,搜尋時收斂為單一清單<br>4. 點擊 chip 開啟**單一詳情面板**(顯示使用次數、最後使用日期、改名/刪除/關閉),不用每個 chip 各自展開<br>5. 刪除確認文字依 `usage_count` 是否為 0 顯示不同訊息 |
| `src/components/TagPicker.vue`(交易表單消費品項選擇器) | 同樣分「最近使用」(取前 8)/「全部品項」兩區,搜尋時收斂為單一清單,邏輯與管理頁一致 |

## 五、目前狀態

- ✅ 消費品項管理頁:搜尋、使用筆數顯示、依筆數排序、chip 網格版面、最近使用分區、詳情面板皆已上線並測試通過
- ✅ 交易紀錄消費品項下拉選單:最近使用分區已上線並測試通過
- ✅ 刪除確認文字依使用筆數區分,已驗證
- ⏳ 排序切換(常用/A-Z/最少使用優先):討論後決定不做

## 六、後續可考慮事項

1. 目前「最近使用」判斷依據為交易日期,若未來補登舊帳的情況變多、影響到「最近使用」的準確度,可評估改為在 `transactions` 加 `created_at` 欄位(需 migration)
2. 本次僅解決「找得到」的問題(方向二);`finance-3rd-tag-feature-category-search-20260707.md` 討論階段還提過另外兩個方向,若未來仍有需要可再評估:
   - **新增時相似名稱提醒**(模糊比對,避免建立語意重複的品項,例如「50嵐」vs「50嵐飲料」)
   - **合併重複品項功能**(把已經不小心建立的多個同義品項,合併成一個並搬移交易關聯)
