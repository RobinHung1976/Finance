# Bug 修復紀錄:Excel 匯入/匯出功能

建立日期:2026-07-08

## 一、背景

Excel 匯入/匯出功能上線後,陸續發現帳戶餘額未更新、匯入格式過於死板、下載檔名編碼錯誤等問題,本次逐一排查修復。

## 二、修復項目

### 1. Excel 匯入的交易未反映到帳戶餘額

| 項目 | 內容 |
|---|---|
| 現象 | 用 Excel 匯入功能匯入的交易,在交易紀錄裡看得到,但帳戶餘額沒有對應增減,導致帳戶餘額與交易加總對不起來 |
| 原因 | `process_import`(`excel_transfer.py`)建立交易時只有 `db.add(Transaction(...))`,沒有像手動新增交易的 `create_transaction`(`transactions.py`)一樣同步更新 `Account.balance` |
| 修正 | `process_import` 迴圈中累計本次匯入的收支淨額(`balance_delta`,收入加、支出減),寫入交易完成後一次性更新 `Account.balance`,避免逐筆查詢 DB |
| 已知限制 | 此修正僅影響**之後**的匯入,先前已匯入但未正確計入餘額的歷史資料**未回補**,待後續視需要再處理(重算：該帳戶所有交易收入加總 − 支出加總) |

### 2. 匯入功能過於死板,只支援固定工作表命名與欄位排列

| 項目 | 內容 |
|---|---|
| 現象 | 上傳非原本記帳表格式的測試檔(`test.xlsx`,工作表名稱為「工作表1」、欄位排列為 A:D 而非原本的 C:F),完全無法解析,預覽結果是 0 筆資料且無錯誤提示 |
| 原因 | `parse_month_sheets` 用 `MONTH_SHEET_RE`(`^\d{1,2}月$`)篩選工作表名稱、並寫死欄位為 C:F、標題列固定在第 2 列,只要不符合就直接跳過整張表 |
| 修正 | 改為自動偵測:掃描每張工作表前 10 列,找出同時包含「日期/類別/項目/金額」四個標題文字的那一列,以此動態決定標題列位置與各欄位對應的欄位號;找不到完整標題的工作表(如原本的「總表」「類別」下拉選單來源)天生就會被跳過,不再需要靠工作表命名規則排除 |

### 3. 日期欄位為 YYYYMMDD 整數格式,誤判成 Excel 序列值導致匯入失敗

| 項目 | 內容 |
|---|---|
| 現象 | `test.xlsx` 的日期欄位打成純數字 `20260708`(而非 Excel 真正的日期型別),預覽時顯示「預覽失敗,請確認檔案格式是否正確」 |
| 原因 | `_excel_serial_to_date` 把所有非 `datetime`/`date` 型別的數值都當成 Excel 序列值(距離 1899-12-30 的天數)處理,`20260708` 天換算下來遠超西元 9999 年,`datetime` 直接拋出 `OverflowError: date value out of range`;此例外未被 `_validate_row` 的 `except (TypeError, ValueError)` 攔截,往上炸穿到 router 的 `except Exception`,只回傳籠統錯誤訊息 |
| 修正 | 新增判斷:數值若落在合理的 8 位數 YYYYMMDD 範圍(`19000101`~`99991231`)且能成功解析為合法日期,優先當 YYYYMMDD 格式處理;否則才當 Excel 序列值。同時把 `OverflowError` 一併納入 `_validate_row` 的例外攔截範圍,避免同類問題再次整個炸穿 |

### 4. 匯出下載:中文檔名導致 500 Internal Server Error

| 項目 | 內容 |
|---|---|
| 現象 | 點擊「下載 Excel」後端回傳 500,瀏覽器 Response 顯示純文字 `Internal Server Error`(非 JSON,代表是未攔截的例外) |
| 錯誤訊息 | `UnicodeEncodeError: 'latin-1' codec can't encode characters in position 27-29: ordinal not in range(256)` |
| 原因 | `Content-Disposition` header 直接塞入中文檔名(`2026-記帳表.xlsx`),但 HTTP header 只能用 `latin-1` 編碼,中文字無法編碼,`StreamingResponse` 建構時直接拋例外 |
| 修正 | 改用 RFC 5987 格式,同時提供 ASCII 備援檔名(`filename=`)與 UTF-8 編碼檔名(`filename*=UTF-8''...`),不支援新格式的舊瀏覽器會自動退回 ASCII 檔名 |

### 5. 下載檔名應改為「年份-帳本名稱」,但前端寫死取代了後端正確值

| 項目 | 內容 |
|---|---|
| 需求 | 下載檔名希望顯示帳本名稱(如「洪不讓理財本」),而非固定文字「記帳表」 |
| 後端調整 | `export_excel` 加查 `Household.name`,檔名組成 `f"{year}-{household_name}.xlsx"`,以 RFC 5987 編碼寫入 `Content-Disposition` |
| 排查過程 | 後端用 `curl -D -` 確認 `Content-Disposition` header 內容完全正確(UTF-8 編碼後可正確解出「2026-洪不讓理財本.xlsx」),但瀏覽器下載結果仍是舊檔名,顯示問題不在後端 |
| 真正原因 | 前端 `exportExcel()` 的 `a.download` 屬性**寫死**為 `` `${year}-記帳表.xlsx` ``,完全沒有讀取後端回傳的 `Content-Disposition` header,後端資料再正確也不會反映到下載檔名 |
| 修正 | 前端改用完整 `response`(而非只解構 `data`),解析 `response.headers['content-disposition']`:優先比對 `filename*=UTF-8''...` 並 `decodeURIComponent`,取不到才退回比對 `filename="..."` 的 ASCII 版本,最後才 fallback 寫死字串 |

## 三、目前狀態

- ✅ Excel 匯入交易正確反映到帳戶餘額(僅影響之後的匯入,歷史資料落差待後續處理)
- ✅ 匯入功能改為自動偵測標題列與欄位位置,不再限定工作表命名或固定欄位排列
- ✅ 支援 YYYYMMDD 整數日期格式,同時保留原本 Excel 日期型別的相容性
- ✅ 匯出下載中文檔名問題已修復,不再 500
- ✅ 下載檔名正確顯示「年份-帳本名稱」(例如「2026-洪不讓理財本.xlsx」)

## 四、後續可考慮事項

1. **歷史帳戶餘額落差**:目前決定先不處理,待有需要時可寫一次性腳本,依「該帳戶所有交易收入加總 − 支出加總」重新計算並覆蓋 `Account.balance`
2. **帳本名稱特殊字元防呆**:目前帳本名稱可自由輸入,若包含 `/`、`\`、`:` 等檔名不允許的字元,可能導致匯出檔名在部分作業系統/瀏覽器出現問題,建議在建立/修改帳本名稱時就從源頭限制特殊字元,而非事後在匯出檔名處補防呆
3. 匯入標題列自動偵測目前限定「日期/類別/項目/金額」四個中文字完全相符,若未來有欄位名稱同義詞(如「日期」打成「時間」)的彈性需求,需再擴充比對邏輯
