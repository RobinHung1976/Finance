# 功能現況:Excel 匯入/匯出

## 一、範圍

- 匯入:讀取舊版手動記帳 Excel(`N月`分頁明細),轉入系統 `transactions`/`categories`
- 匯出:依年份輸出各月分頁,格式對齊舊版 Excel(日期/類別/項目/金額)

## 二、後端

| 檔案 | 說明 |
|---|---|
| `app/schemas_import_export.py` | `ImportRowPreview`、`ImportPreviewResponse`、`ImportCommitResponse` |
| `app/services/excel_transfer.py` | `parse_month_sheets`(自動偵測標題列與欄位位置,掃描每張工作表前 10 列找「日期/類別/項目/金額」四個標題文字所在列,取代原本寫死工作表命名規則與欄位範圍)、`process_import`、`build_export_workbook` |
| `app/routers/transactions_transfer.py` | `POST /transactions/import/preview`、`POST /transactions/import/commit`(同一套解析邏輯,靠 `dry_run` 參數區分)、`GET /transactions/export/excel?year=` |

### 設計決策

| 項目 | 決定 |
|---|---|
| 分類對應 | 「項目」建成分類樹第二層子分類,比對範圍不限層級、household 全樹比對同名節點,重用既有分類 |
| 收支型別 | `type = income if 類別 == "收入" else expense` |
| 日期格式 | 同時支援 Excel 序列值與 `YYYYMMDD` 8 位數整數格式(依合理範圍 `19000101`~`99991231` 判斷) |
| 重複匯入防呆 | 比對既有 `(date, amount, category_id, account_id, type)` 組合,重複預設跳過;使用者可在預覽表格勾選特定重複列強制寫入 |
| 帳戶餘額連動 | `process_import` 迴圈累計本次匯入收支淨額(`balance_delta`),寫入完成後一次性更新 `Account.balance` |

## 三、前端

| 檔案 | 說明 |
|---|---|
| `src/components/ExcelImportExport.vue` | 帳戶選擇、檔案上傳、預覽表格(重複/新分類標記、勾選強制匯入)、匯出年份選擇 |
| `src/api/importExport.ts` | `previewImport`/`commitImport` 呼叫時顯式帶 `headers: { 'Content-Type': undefined }`,清除 `apiClient` 全域固定的 `application/json`,讓 axios 依 `FormData` 自動產生正確 boundary |

匯出下載檔名:`{年份}-{帳本名稱}.xlsx`,採 RFC 5987 格式(`Content-Disposition` 同時提供 ASCII 備援與 UTF-8 編碼檔名);前端解析 `response.headers['content-disposition']` 取得實際檔名(優先 `filename*=UTF-8''...`,取不到才退回 `filename="..."`)。

## 四、已知限制 / 後續可考慮

1. **`apiClient`(`client.ts`)全域固定 `Content-Type: application/json`** 是容易誤踩的坑,未來若有其他上傳檔案功能(如收據圖片),須記得比照清除該 header
2. 匯入標題列自動偵測限定「日期/類別/項目/金額」四字完全相符,若欄位名稱有同義詞需求(如「時間」),需擴充比對邏輯
3. dedupe 僅比對 `(date, amount, category_id, account_id, type)`,無法防止跨帳戶/跨分類調整後的重複
4. 帳本名稱目前可自由輸入,若含 `/`、`\`、`:` 等檔名不允許字元,可能導致匯出檔名在部分系統出現問題,建議從帳本名稱建立/修改源頭限制特殊字元
5. **歷史帳戶餘額落差**已透過一次性腳本回補完成(見 `feature-accounts.md`),此修正僅影響回補當下,非持續性機制

## 五、沿革

| 日期 | 內容 | 詳情 |
|---|---|---|
| 2026-07-07 | 匯入/匯出功能初版上線 | `changelog-details/20260707-excel-import-export-launch.md` |
| 2026-07-08 | 修復帳戶餘額未同步、格式過於死板、中文檔名 500、下載檔名前端寫死 | `changelog-details/20260708-excel-import-export-fix.md` |
