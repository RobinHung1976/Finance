# A10 自訂區間統計釐清 + tag-breakdown 選填修正

## 一、背景

討論 A 系列統計下一步開發項目時,重新核對 `feature-stats.md` 的「尚未開始」清單。逐一比對 `stats.py`、`DateRangePicker.vue`、`DashboardView.vue` 實際程式碼後發現:A10「自訂區間統計」其實已經做完,文件沒有同步更新。核對過程中同時發現兩個文件/程式碼落差:

1. `feature-stats.md` 的 A1 說明寫著 `GET /stats/monthly-trend?months=12`,但 `stats.py` 實際參數是 `start_date`/`end_date`,沒有 `months` 這個參數——單純文件寫錯,程式碼本身沒問題。
2. `tag-breakdown` 的 `start_date`/`end_date` 是**必填**(無 `None`、無 default),跟 `monthly-trend`/`category-breakdown` 兩支「選填 + 預設今年區間」的行為不一致。目前前端 `DashboardView.vue` 三個統計子分頁共用同一組 `DateRangePicker`,一定會帶值,不會踩到這個洞,但屬於 API 設計不對稱,日後其他呼叫端(手機 App、直接呼叫 API)沒帶參數會被 422 擋下,行為跟另外兩支不一致。

## 二、決策

- A10:不需要新開發,直接更正文件,把 A10 從「尚未開始」移到「已完成」,並修正 A1 的錯誤參數說明。
- `tag-breakdown` 選填化:選擇修正而非維持現狀,理由是三支統計 API 本質上都是「同一組統計頁面共用區間」的概念,沒有理由其中一支特殊化,保持一致對之後接手的人比較好理解。

## 三、修改內容

### 文件(僅更新現況,無程式碼變動)

- `features/feature-stats.md`:
  - A1 說明修正為實際的 `start_date`/`end_date` 參數
  - A10 從「尚未開始的項目」移至「已完成項目」,補上實際行為說明(三分頁共用 `DateRangePicker`,自由起訖日)
  - 消費品項排行說明補充 `tag-breakdown` 選填化的修正

### 程式碼(`update49.sh`)

- `app/routers/stats.py`:`get_tag_breakdown()` 的 `start_date`/`end_date` 由必填改為 `date | None`,預設呼叫既有 `_resolve_range()`(跟 `monthly_trend`/`category_breakdown` 共用同一個 helper),取代原本手寫的 `if end_date < start_date` 檢查
- 精確字串比對修改(改動範圍小),前置驗證確認 `is_self` 邏輯已存在(即 `update46/47.sh` 已套用)才執行
- 未修改 `models.py`,無需 Alembic migration
- 未修改前端,`DashboardView.vue` 呼叫方式不受影響

## 四、目前狀態

- ✅ `feature-stats.md` 文件已更新,A10 正確反映為已完成項目
- ✅ `tag-breakdown` 與另外兩支統計 API 行為一致,沒帶 `start_date`/`end_date` 時預設今年區間,不再 422
- ✅ 前端行為不受影響(本來就一定會帶值)
