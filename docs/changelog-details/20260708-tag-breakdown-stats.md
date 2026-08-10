# 功能新增:統計圖表加入消費品項排行

建立日期:2026-07-08

## 一、背景與需求

`finance-3rd-tag-feature-category-search-20260707.md` 上線消費品項(Tag)功能後,統計圖表(`CategoryBreakdownChart`)只有分類的圓餅圖,沒有消費品項的統計。使用者反映想看「三媽總共花多少」這類依消費品項排行的資訊。

## 二、討論與決策

### 為何不做圓餅圖

分類與消費品項是不同性質的資料結構:

| 項目 | 分類 | 消費品項(Tag) |
|---|---|---|
| 關係 | 每筆交易恰好屬於一個分類 | 一筆交易可掛 0~多個品項(多對多) |
| 加總後總和 | 等於支出總額 | 可能超過支出總額(重複計算),也可能有大量「未標記」交易 |
| 適合的圖表 | 圓餅圖(佔比語意成立) | 不適合圓餅圖 |

若直接比照分類統計做圓餅圖,會出現「一筆 500 元交易掛兩個品項,兩個品項統計各自加 500」的重複計算問題,佔比加總超過 100% 沒有意義,且「未標記」的交易無法自然歸位。

**決策:改用「消費品項排行長條圖」**,不強求佔比加總 100%,語意上更誠實,類似部落格標籤雲、電商熱門商品排行的呈現方式。金額計算故意**不**依掛載品項數量分攤(例如掛 2 個品項就各算一半),因為使用者對「三媽花了多少」的直覺就是該筆交易全額,不是打折後的數字;此設計刻意記錄於文件,避免日後誤認為 bug。

## 三、後端變更

### 修改檔案
- `app/schemas_ledger.py`:新增 `TagBreakdownItem`、`TagBreakdownOut`
- `app/routers/stats.py`:新增 `GET /stats/tag-breakdown`

### 技術重點
- 用 `Tag` → `TransactionTag` → `Transaction` 的 `join` + `func.sum`/`func.count` 在 DB 層一次彙總,依 `household_id`/`type`/日期區間篩選,依金額由大到小排序,`limit` 預設 15、上限 50(`Query(15, ge=1, le=50)` 防呆)
- 做法與既有 `tags.py` 的 `usage_count` 彙總、`stats.py` 月彙總邏輯一致,不把交易全部拉回 Python 迭代
- `end_date < start_date` 回傳 `400`,防呆邏輯與其他統計 API 一致

## 四、前端變更

### 新增檔案
- `src/components/TagBreakdownChart.vue`:消費品項排行長條圖,收支類型切換(支出/收入),固定高度 `320px` + 內部捲動(避免重演 `bug-fix-20260707.md` 記錄的 flex 無界延伸問題),明確顯示提示文字「總和不等於支出總額」

### 修改檔案
- `src/types/ledger.ts`:新增 `TagBreakdownItem`、`TagBreakdownOut` 型別
- `src/api/ledger.ts`:新增 `fetchTagBreakdown`
- `src/views/DashboardView.vue`:統計分頁新增「消費品項排行」子分頁,與既有「月收支趨勢」「支出分類統計」並列,共用同一組日期區間(`DateRangePicker`)

## 五、Bug 修復紀錄(本次上線過程實際踩坑)

### 1. `stats.py`/`schemas_ledger.py` 誤用不存在的 `TransactionType`

| 項目 | 內容 |
|---|---|
| 現象 | 部署後 `ledger-api` 持續 `activating (auto-restart)`,無法啟動 |
| 錯誤訊息 | `NameError: name 'TransactionType' is not defined. Did you mean: 'TransactionOut'?` |
| 原因 | 新增程式碼時誤用了想像中的型別名稱,但專案實際的收支型別 enum 叫 `EntryType`(定義於 `app/models.py`);且此錯誤同時存在於 `stats.py` 的函式參數與 `schemas_ledger.py` 的 `TagBreakdownOut` 兩處,第一次修正只改了 `stats.py`,遺漏了 `schemas_ledger.py`,導致二次踩坑 |
| 修正 | 兩處皆改為 `EntryType`,並用 `grep -rn "TransactionType" ledger-backend/app/` 全專案掃描確認無殘留 |

### 2. `schemas_ledger.py` 缺少 `date` import

| 項目 | 內容 |
|---|---|
| 現象 | 修正 `EntryType` 後,`ledger-api` 仍無法啟動 |
| 錯誤訊息 | `NameError: name 'date' is not defined` |
| 原因 | `schemas_ledger.py` 原本用 `from datetime import date as date_type, datetime` 的別名寫法(可能是避免與其他變數名稱衝突的既有慣例),新增 `TagBreakdownOut.start_date`/`end_date` 欄位時直接用裸的 `date`,未留意此慣例,也未確認該名稱是否已被 import |
| 修正 | 補上 `date`(與既有 `date_type` 並存,不衝突):`from datetime import date as date_type, datetime, date` |
| 附帶教訓 | 該檔案沿用 `date_type` 別名風格,日後在此檔案新增日期型別欄位,應優先比照使用 `date_type` 保持一致,惟本次為求盡速恢復服務,先以正確運行為優先,未回頭統一命名 |

### 3. `api/ledger.ts` 缺少 `TagBreakdownOut` import,以及修正時產生語法錯誤

| 項目 | 內容 |
|---|---|
| 現象 1 | `npm run build` 報 `TS2304: Cannot find name 'TagBreakdownOut'` |
| 原因 1 | 附加 `fetchTagBreakdown` 函式時使用了 `TagBreakdownOut` 型別,但未同步在檔案開頭補上對應的 import |
| 現象 2 | 修正現象 1 時,用字串比對把 `TagBreakdownOut` 附加進既有 import 區塊,但只用 `rstrip()` 去除空白、未處理原本行尾已存在的逗號,產生 `EntryType,, TagBreakdownOut` 的重複逗號語法錯誤 |
| 錯誤訊息 | `TS1003: Identifier expected` |
| 修正 | 改用「拆解全部名稱 → 過濾空字串(含重複逗號造成的空項)→ 去重 → 重新組合」的方式重寫 import 行,避免逗號拼接的邊界情況 |

## 六、目前狀態

- ✅ 後端 `/stats/tag-breakdown` 已上線並通過健康檢查
- ✅ 前端「消費品項排行」子分頁已顯示,與既有「月收支趨勢」「支出分類統計」並列於統計頁籤下
- ✅ `systemctl status ledger-api` 恢復 `active (running)`,`journalctl` 無殘留 `NameError`
- ✅ 瀏覽器實測:長條圖正常渲染,收支類型切換正常
- ✅ 回歸測試:月收支趨勢、支出分類統計兩個既有分頁不受影響

## 七、後續可考慮事項

1. 目前僅支援「消費品項排行」,若使用者想反查「某分類底下有哪些常見消費品項」的交叉統計,需另外設計 API,屬於較大工程,先不列入本次範圍
2. `TagBreakdownItem` 的金額計算未依掛載品項數量分攤,若未來有「精確拆分每個品項實際負擔金額」的需求(例如記帳分帳情境),需要重新設計計算邏輯與呈現方式,屬於語意上的取捨,不是本次的 bug
3. `schemas_ledger.py` 目前 `date`/`date_type` 兩個名稱並存,並非理想狀態,可安排在未來低風險時機統一命名,非急迫事項
