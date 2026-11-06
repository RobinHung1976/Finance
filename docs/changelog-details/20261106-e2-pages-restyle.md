# 2026-11-06 帳戶/分類/消費品項/匯入匯出頁改用金屬主題(前端改版 E2-2)

## 背景

E2 第一頁(交易紀錄,`20261106-transactions-report-view.md`)完成後,其餘四頁內部仍是舊樣式:白色卡片、純文字按鈕(`.btn-text`)、inline style 與寫死色碼。本次一次改完,行為與 API 呼叫不變。

## 修改內容(`update58.sh`)

| 頁面 | 元件 | 改動 |
|---|---|---|
| 帳戶 | `AccountList.vue` | 改為表格(名稱 + 預設支出帳戶標籤/類型/餘額/操作)+ 合計列,負餘額紅色;「調整餘額」在餘額欄就地編輯;新增表單改 `.form-grid` 欄位格線;起始餘額、調整餘額為空時前端擋下(原本未檢查) |
| 分類 | `CategoryList.vue`、`CategoryTreeNode.vue` | 支出/收入改 LED 按鍵(放在「建立分類」面板標題列);分類樹每列改金屬按鍵(改名/刪除),子分類數量改小標籤;搜尋結果改表格(完整路徑,可就地改名/刪除) |
| 消費品項 | `TagList.vue` | 新增欄移到面板標題列;品項改金屬膠囊鍵(含使用次數,未使用者淡色),選取後為品牌綠;下方明細列顯示使用次數/最後使用日與改名/刪除/關閉 |
| 匯入匯出 | `ExcelImportExport.vue` | 拆成「匯出 Excel」「匯入 Excel」兩個面板;預覽改統計卡片(總筆數/有效/重複/錯誤/將匯入)+ 表格(類型色塊、狀態標籤 匯入/新分類/重複跳過/強制匯入) |
| 共用 | `styles/theme.css` | 新增 `input[type=file]` 金屬按鍵樣式 |
| 路由頁 | `AccountsView`/`CategoriesView`/`TagsView`/`TransferView.vue` | 不再外包 `.panel`,改由元件自帶面板 |

## Bug 修正(匯入頁)

1. **重選同一個檔案沒反應**
   - 現象:匯入完成或按「取消」後,再選同一個 `.xlsx` 不會出現「預覽」按鈕
   - 原因:只清掉 `selectedFile`,`<input type="file">` 的 value 還在,選同一檔案不觸發 `change`
   - 修正:匯入成功與取消時呼叫 `clearFileInput()` 清空欄位
2. **載入帳戶失敗沒有提示**
   - 現象:`fetchAccounts()` 失敗時目標帳戶下拉為空,畫面無任何訊息(且產生 unhandled promise rejection)
   - 修正:加 `.catch()`,顯示「載入帳戶失敗,請重新整理頁面」

## 驗證

- 開發環境以 Playwright + 假資料實測:帳戶新增(含空餘額錯誤訊息)/調整餘額(負數)/設為預設、分類展開/改名/搜尋、消費品項重名阻擋、匯入預覽/強制匯入/確認匯入後檔案欄位清空,API payload 與改版前一致
- `update58.sh`:sha256 比對 10 個既有檔案,腳本內建置通過才 commit;部署後 `ledger-api` active、`/` 與 `/health` 皆 200
- 使用者實測(2026-11-06):四頁操作與交易紀錄、統計頁,全部正常

## 目前狀態

E2 五頁全部完成。仍使用舊樣式/相容層的:`CategoryPicker.vue`、`TagPicker.vue`(含交易對話框內)、篩選器三元件、`TagBreakdownChart.vue`、`TopTransactionsList.vue`、登入/註冊/忘記密碼/重設密碼頁、`MembersView.vue` 的 `.field`。這些改完才能移除 `style.css`,與 E3 圖表配色一起處理。
