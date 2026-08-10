# 第二期任務清單

建立日期:2026-07-07

## 一、依賴關係與排序邏輯

- **A(統計 API)**:無新表,純查詢,投報率最高,做完儀表板立刻有東西可看
- **B(預算)**:B3 依賴 A1 的月彙總邏輯
- **C(CSV)**:獨立模組,不跟 A/B 耦合
- **D(報表匯出)**:依賴 A 的圖表元件穩定後才能做
- **建議順序**:A → B → C → D,Tag(E)視情況插入

## 二、A. 統計 API + 儀表板

| # | 項目 | 後端 | 前端 | 依賴 | 狀態 |
|---|---|---|---|---|---|
| A1 | 月收支趨勢(近 6-12 月) | group by month | Chart.js 折線圖 | 無 | ✅ 已完成(見 `finance-2nd-A1-A2-20260707.md`) |
| A2 | 結餘計算 | sum(income)-sum(expense) | 顯示卡片 | 無 | ✅ 已完成 |
| A3 | 分類統計(圓餅/甜甜圈) | Recursive CTE 撈樹 + amount 彙總 | Chart.js 圓餅圖 | 需確認 `categories.py` 是否已有 CTE | ✅ 已完成(見`finance-3rd-A3-20260707.md`) |
| A4 | 分類趨勢比較 | 同 A3 + 時間序列 | 折線圖 | A3 | ⏳ 待開始 |
| A5 | 同期比較(MoM/YoY) | 兩期查詢 + 百分比計算 | 數字+顏色標示 | A1 | ⏳ 待開始 |
| A6 | 成員別統計 | group by user_id | 長條圖/圓餅圖 | 無 | ⏳ 待開始 |
| A7 | 帳戶別統計 | group by account_id | 長條圖 | 無 | ⏳ 待開始 |
| A8 | 月底預估 | 前半月花費速度 × 天數比例 | 數字顯示 | A1 | ⏳ 待開始 |
| A9 | 最大單筆排行 Top5 | ORDER BY amount DESC LIMIT 5 | 清單 | 無 | ⏳ 待開始 |
| A10 | 自訂區間統計 | 重用 transactions 的 start/end filter | 日期選擇器 | 無 | ⏳ 待開始 |

## 三、B. 預算功能(新 CRUD 面)

| # | 項目 | 說明 | 狀態 |
|---|---|---|---|
| B1 | Budget schema + router(CRUD) | `Budget` model 已存在於 `models.py`,補 API | ⏳ 待開始 |
| B2 | 前端「設定預算」頁面 | 選分類 + 月份 + 金額 | ⏳ 待開始 |
| B3 | 預算達成率(進度條,超支變色) | 依賴 B1 + A1 的月彙總邏輯 | ⏳ 待開始 |

## 四、C. CSV 匯入/匯出(獨立模組)

| # | 項目 | 說明 | 狀態 |
|---|---|---|---|
| C1 | CSV 匯出 | transactions → CSV,依現有 filter | ⏳ 待開始 |
| C2 | CSV 匯入(格式驗證) | 欄位對應、型別檢查、account/category 存在性驗證 | ⏳ 待開始 |
| C3 | 重複資料偵測 | 依 date+amount+account+note 判斷疑似重複,匯入前提示 | ⏳ 待開始 |

## 五、D. 報表匯出(收尾,依賴 A)

| # | 項目 | 說明 | 狀態 |
|---|---|---|---|
| D1 | 統計頁面加「匯出」按鈕 | 前端截圖(html2canvas)或後端產 PDF | ⏳ 待開始 |
| D2 | PDF 版面 | 需選 library(如 reportlab / weasyprint) | ⏳ 待開始 |

## 六、E. 選配 / 未定案

- **Tag 功能**:`Tag`、`TransactionTag` model 已存在於 `models.py`,但 schema/router 尚未建立 — 是否併入第二期或延後,待確認
- **重複交易(固定週期)**:md 標註第三期,先不排入本期

## 七、下一步

繼續 A3(分類統計圓餅圖),需先確認 `categories.py` 現有的分類查詢邏輯,決定是否新增遞迴 CTE。
