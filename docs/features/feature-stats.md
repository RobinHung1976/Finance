# 功能現況:統計報表(Stats)

## 一、已完成項目

| 項目 | 說明 |
|---|---|
| A1 月收支趨勢 | `GET /stats/monthly-trend?months=12`;DB 層 `date_trunc('month',...)` + `group by` 彙總,缺資料月份補 0 避免斷點;前端 `MonthlyTrendChart.vue`(Chart.js 折線圖) |
| A2 結餘計算 | 內含在 A1 同一支 API 回應(`total_balance`),未另開 endpoint |
| A3 分類統計 | Recursive CTE 撈樹 + 金額彙總(`category_id` 需顯式 `str()` 轉換);前端圓餅/甜甜圈圖,固定高度 `320px`(避免 flex 無界延伸)。下鑽某分類(`parent_id` 不為 `None`)時,若該分類本身有直接掛帳(未再歸類到任何子分類)的交易,額外補一項 `is_self=true` 的「`<分類名稱>(直接歸類,未再細分)`」項目(固定灰色 `#9CA3AF`、`has_children=false`),確保下鑽畫面加總 = 頂層總額,不會出現子分類加總對不起來的落差 |
| 消費品項排行 | `GET /stats/tag-breakdown`;`Tag → TransactionTag → Transaction` join + `func.sum`/`func.count` 依金額排序,`limit` 預設 15、上限 50;前端 `TagBreakdownChart.vue`,長條圖(非圓餅圖,因消費品項多對多、加總可能超過支出總額),明確標註「總和不等於支出總額」 |

三個統計子分頁(月收支趨勢/支出分類統計/消費品項排行)在「統計」tab 下以子分頁切換,共用同一組 `DateRangePicker`。

## 二、消費品項排行的設計取捨

金額計算**不**依掛載品項數量分攤(掛 2 個品項不會各算一半),因為使用者對「某品項花了多少」的直覺是該筆交易全額。此設計刻意記錄,避免日後誤認為 bug。

## 三、技術重點(共通做法)

彙總類 API 一律在 DB 層用 `group by`/`func.sum`/`func.count` 完成,不把交易全部拉回 Python 迭代(`stats.py`、`tags.py` 的 `usage_count`、`recalc_account_balances.py` 皆遵循同一模式)。

## 四、尚未開始的項目(第二期任務清單延續)

| # | 項目 | 依賴 |
|---|---|---|
| A4 | 分類趨勢比較(折線圖) | A3 |
| A5 | 同期比較(MoM/YoY) | A1 |
| A6 | 成員別統計 | 無 |
| A7 | 帳戶別統計 | 無 |
| A8 | 月底預估(前半月花費速度 × 天數比例) | A1 |
| A9 | 最大單筆排行 Top5 | 無 |
| A10 | 自訂區間統計(重用既有 filter) | 無 |
| B | 預算功能(`Budget` model 已存在,尚缺 API/前端頁面/達成率進度條) | B3 依賴 A1 |
| C | CSV 匯入/匯出(獨立模組,不與統計耦合) | 無 |
| D | 報表匯出(截圖或 PDF) | 依賴統計圖表穩定 |

## 五、已知限制 / 後續可考慮

- 目前無「某分類底下有哪些常見消費品項」的交叉統計,需另外設計 API

## 六、沿革

| 日期 | 內容 | 詳情 |
|---|---|---|
| 2026-07-07 | A1+A2 月收支趨勢圖 + 結餘計算上線,連帶完成部署架構轉正式環境(見 `ops/ops-infra-public-access.md`) | `changelog-details/20260707-monthly-trend-balance.md` |
| 2026-07-07 | A3 分類統計相關 bug 修復(UUID 型別、flex 無界延伸) | `changelog-details/20260707-bug-fix-batch.md` |
| 2026-07-08 | 消費品項排行統計上線(含部署中斷 bug:`TransactionType`/`date` import) | `changelog-details/20260708-tag-breakdown-stats.md` |
| 2026-07-13 | A3 分類統計下鑽補「本分類直接交易」項目,修正頂層/下鑽 CTE 起點不一致導致金額對不起來的問題 | `changelog-details/20260713-category-breakdown-self-amount.md` |
