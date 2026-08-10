# 功能現況:帳戶(Accounts)

## 一、後端

`app/routers/accounts.py`:帳戶 CRUD,交易新增/編輯/匯入時同步連動更新 `Account.balance`。

## 二、餘額連動規則

- 手動新增交易(`create_transaction`)與 Excel 匯入(`process_import`)皆會依收支方向即時調整 `Account.balance`,計算方式一致:收入加、支出減
- 一次性回補腳本 `ledger-backend/scripts/recalc_account_balances.py`:用於排查/修復「餘額與交易加總對不上」的情況,計算方式為 `該帳戶所有交易收入加總 − 支出加總`(DB 層 `func.sum()` 彙總,`coalesce(...,0)` 處理無交易帳戶),支援 `--account-id`/`--household-id` 縮小範圍、dry-run 預設、`--execute` 才寫入

## 三、前端

`src/components/AccountList.vue`:帳戶管理頁。`src/components/AccountFilterPicker.vue`:交易篩選用帳戶單選器(搜尋框 + 攤開按鈕網格,取代原生 `<select>`)。

## 四、已知限制 / 後續可考慮

- 若日後其他流程再發生「忘記同步更新 balance」的 bug,可直接重用 `recalc_account_balances.py` 排查與回補
- 該腳本目前無稽核紀錄(未寫入 `audit_logs`),若需要追溯回補歷史需額外設計

## 五、沿革

| 日期 | 內容 | 詳情 |
|---|---|---|
| 2026-07-08 | Excel 匯入未同步更新帳戶餘額,修正後對之後匯入生效 | `changelog-details/20260708-excel-import-export-fix.md` |
| 2026-07-08 | 歷史帳戶餘額回補腳本,回補修正前已匯入的落差資料 | `changelog-details/20260708-account-balance-recalc.md` |
