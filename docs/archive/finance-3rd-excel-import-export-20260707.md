# 功能新增:Excel 匯入/匯出

建立日期:2026-07-07

## 一、範圍

- 匯入:讀取舊版手動記帳 Excel(`N月`分頁明細),轉入系統 `transactions`/`categories`
- 匯出:依年份輸出各月分頁,格式對齊舊版 Excel(日期/類別/項目/金額)

## 二、Excel 來源格式分析

檔案結構:`1月`~`12月`(逐月明細)+ `總表`(公式彙總,匯入時略過)+ `類別`(下拉選單來源,匯入時略過)。

| 欄位(C:F) | 說明 |
|---|---|
| 日期 | Excel serial datetime |
| 類別 | 固定 7 大類:飲食/交通/娛樂/醫療/卡費/雜項/收入 |
| 項目 | 自由文字(晚餐、蝦皮、兆豐...),無強制分類樹,僅下拉自動完成建議 |
| 金額 | 正數,收支靠「類別=收入」隱含判斷 |

## 三、設計決策

| 項目 | 決定 |
|---|---|
| 分類對應 | 「項目」一律建成分類樹第二層子分類(含卡費 > 富邦/兆豐/永豐/玉山) |
| 分類比對範圍 | 不限層級,household 全樹比對同名節點,找到就重用,避免與既有手動分類(如飲食→早餐→日牧)衝突重複建立 |
| 收支型別 | `type = income if 類別 == "收入" else expense` |
| household/帳戶 | 前端下拉指定目標 `account_id`,全部交易掛同一帳戶,不自動判斷 |
| 重複匯入防呆 | 匯入前比對既有 `(date, amount, category_id, account_id, type)` 組合,重複則預設跳過 |
| 強制匯入覆蓋 | 使用者可在預覽表格勾選特定重複列,強制寫入(合理的同日同金額同分類多筆情境) |
| Preview/Commit | 同一套解析邏輯,靠 `dry_run` 參數區分,避免伺服器暫存檔案 |

## 四、後端變更

### 新增檔案
- `app/schemas_import_export.py`:`ImportRowPreview`、`ImportPreviewResponse`、`ImportCommitResponse`
- `app/services/excel_transfer.py`:
  - `parse_month_sheets`:只解析 `N月` 分頁,`_to_clean_str` 統一轉字串防呆
  - `process_import`:分類比對/建立、日期轉換、dedupe、強制匯入
  - `build_export_workbook`:依年份輸出各月分頁
- `app/routers/transactions_transfer.py`:
  - `POST /transactions/import/preview`
  - `POST /transactions/import/commit`
  - `GET /transactions/export/excel?year=`

### 修改檔案
- `app/main.py`:掛載 `transactions_transfer.router`
- `requirements.txt`:新增 `openpyxl`

## 五、前端變更

### 新增檔案
- `src/types/importExport.ts`
- `src/api/importExport.ts`:`previewImport`、`commitImport`、`exportExcel`
- `src/components/ExcelImportExport.vue`:帳戶選擇、檔案上傳、預覽表格(重複/新分類標記、勾選強制匯入)、匯出年份選擇

### 修改檔案
- `src/views/DashboardView.vue`:新增「匯入/匯出」tab

## 六、Bug 修復紀錄

### 1. `AttributeError: 'int' object has no attribute 'strip'`

| 項目 | 內容 |
|---|---|
| 現象 | 上傳實際 Excel 後預覽 500 失敗 |
| 原因 | 「項目」欄位存在數字型別儲存格(如 `369`,對應「類別」分頁 K37 下拉選項誤植為數字),`.strip()` 不支援 `int` |
| 修正 | 新增 `_to_clean_str()`,統一 `str(value).strip()` 再處理 `None`/空字串 |
| 附帶修正 | router 加 `try/except`,解析失敗回傳 `400 檔案解析失敗:{e}` 而非未攔截的 500 |

### 2. FormData 上傳一直 422(`file`/`account_id` 為 `null`)

| 項目 | 內容 |
|---|---|
| 現象 | 前端顯示「預覽失敗」,`systemctl status` 看到 `422 Unprocessable Entity`,response `detail` 顯示 `file`/`account_id` 皆為 `missing` |
| 根因 | `apiClient`(`src/api/client.ts`)用 `axios.create` **固定**設定 `headers: { 'Content-Type': 'application/json' }`,屬強制值而非預設值,送出 `FormData` 時不會被 axios 自動覆寫成 `multipart/form-data; boundary=...`,導致後端完全收不到 body 欄位 |
| 修正 | `previewImport`/`commitImport` 呼叫時顯式帶 `headers: { 'Content-Type': undefined }`,清除 instance 層級固定值,讓 axios 依 `FormData` 型別自動產生正確 boundary |
| 排查過程教訓 | 兩階段誤判:先誤以為是手動設定 header 蓋掉 boundary(update13,未解決根因,因為問題出在 axios instance 層級而非呼叫端);後續用 `systemctl status` 看到 422 + curl 重現 + 貼 Response body,才鎖定 `client.ts` 全域設定為真正根因 |

## 七、目前狀態

- ✅ 匯入預覽/送出功能正常,型別防呆與例外攔截已到位
- ✅ 重複偵測 + 使用者手動勾選強制匯入已驗證
- ✅ 匯入日期採用 Excel 原始日期(非匯入當下日期),已於 preview 階段可核對
- ✅ 匯出功能已上線(依年份輸出各月分頁)
- ✅ 實際檔案(`2025-記帳表.xlsx`)測試通過

## 八、後續可考慮事項

1. **`client.ts` 全域 `Content-Type: application/json`** 是一個容易誤踩的坑,若之後有其他上傳檔案的功能(如收據圖片),要記得比照清除該 header
2. 雜項類別項目數量多(30+ 筆歷史一次性項目),匯入後子分類會明顯增加,可評估是否需要「僅常見項目才建分類,其餘進 note」的篩選規則
3. dedupe 目前僅比對 `(date, amount, category_id, account_id, type)`,無法防止跨帳戶或跨分類調整後的重複,若未來有此需求需另外設計
