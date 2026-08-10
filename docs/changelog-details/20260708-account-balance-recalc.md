# 歷史資料回補:帳戶餘額重新計算腳本

建立日期:2026-07-08

## 一、背景

`bug-fix-20260708-excel-import-export.md` 記錄的 bug 1 —— Excel 匯入功能上線後一段時間,`process_import()` 沒有同步更新 `Account.balance`,導致匯入的交易在交易紀錄看得到,但帳戶餘額沒有對應增減。程式碼已修正,但修正**僅影響之後的匯入**,修正前已匯入、餘額未正確反映的歷史資料需要另外回補。

本次排查確認:當時測試用的錯誤匯入資料(某筆測試帳本)已透過 `purge_household.py` 整個刪除,不需回補;但另有一批**正式匯入**的歷史交易,匯入時間點還在 bug 修正之前,帳戶餘額確實有落差,需要回補。

## 二、新增檔案

- `ledger-backend/scripts/recalc_account_balances.py`:一次性帳戶餘額回補腳本,比照既有 `migrate_leaf_categories_to_tags.py` / `purge_household.py` 的安全模式(dry-run 預設、`--execute` 才執行、單一 transaction)

## 三、設計決策

### 計算方式

```
正確餘額 = 該帳戶所有交易「收入」金額加總 − 「支出」金額加總
```

與 `bug-fix-20260708-excel-import-export.md`「後續可考慮事項」第 1 點所寫的重算方式一致。

### 安全機制

| 機制 | 說明 |
|---|---|
| 預覽 | 預設 dry-run,列出每個帳戶「目前餘額 vs 重新計算後的正確餘額」及差異,不寫入任何異動 |
| 只動有差異的 | 只更新「有差異」的帳戶,沒有差異的帳戶完全不會被寫入,異動範圍最小化,方便事後追查 |
| 範圍限定 | 可用 `--account-id` 或 `--household-id` 縮小檢查範圍,不帶參數則檢查全部帳戶 |
| 二次確認 | `--execute` 時要求輸入 `yes` 才會真正寫入 |
| 交易安全 | 全程單一 DB transaction,任何步驟失敗自動 rollback |
| 邊界案例 | 完全沒有交易的帳戶,加總用 `coalesce(sum(...), 0)` 處理,不會因為 `NULL` 而噴錯或誤判 |

### 為何不用 ORM 逐筆迭代

用 DB 層 `func.sum()` + `filter` 直接在資料庫端加總,不把整年份交易全部拉回 Python 迭代,作法與 `finance-2nd-A1-A2-20260707.md` 的月彙總統計 API 一致。

## 四、驗證過程

- 用 SQLite 建立含 `Account`/`Transaction` 的模擬環境,驗證計算邏輯:
  - 一般案例:3 筆交易(收入 1000、支出 300、支出 200)→ 正確算出 `500`
  - 邊界案例:完全沒有交易的帳戶 → 正確算出 `0`,不會因 `NULL` 加總而出錯
- 實際在正式環境跑過 dry-run,人工核對「不符」的帳戶跟預期(昨天那次匯入影響到的帳戶)一致,確認無誤後執行 `--execute` 完成回補

## 五、用法

```bash
cd ledger-backend
source venv/bin/activate

# 1. 先檢查(不寫入任何異動)
python scripts/recalc_account_balances.py                          # 全部帳戶
python scripts/recalc_account_balances.py --household-id <uuid>     # 只檢查某帳本
python scripts/recalc_account_balances.py --account-id <uuid>       # 只檢查單一帳戶

# 2. 確認 dry-run 輸出的「不符」帳戶符合預期後,才回補
python scripts/recalc_account_balances.py --execute
```

## 六、目前狀態

- ✅ 腳本已建立並用 SQLite 模擬環境驗證計算邏輯(含邊界案例)
- ✅ 已在正式環境執行 dry-run,確認「不符」帳戶與預期一致
- ✅ 已執行 `--execute` 完成歷史帳戶餘額回補
- ✅ 當時造成問題的測試資料(測試帳本)已透過 `purge_household.py` 刪除,不需重複處理

## 七、後續可考慮事項

1. 這是一次性回補腳本,理論上之後不需要再跑;若日後又發現匯入/其他流程有類似「忘記同步更新 balance」的 bug,可以直接重用此腳本排查與回補,不用重新設計計算邏輯
2. 目前腳本只回補 `Account.balance`,沒有额外記錄「這次回補動了哪些帳戶、改了多少」的歷史軌跡;若之後需要稽核回補紀錄,可以考慮寫入 `audit_logs`(`resource_type="account"`, `action="update"`)
