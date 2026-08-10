# 功能現況:帳本(Household)管理

## 一、範圍

- 帳本名稱事後修改(原本只能在註冊時設定一次)
- 帳本名稱防呆:白名單驗證
- 封存/解封帳本(軟刪除,可還原,不動 DB 資料)
- 成員刪除
- 永久刪除已封存帳本的 CLI 工具(無網頁版超級管理員,見第五節決策)

## 二、後端

| 檔案 | 說明 |
|---|---|
| `app/validators.py` | `validate_household_name()`,白名單正則 `^[\u4e00-\u9fffA-Za-z0-9 _-]+$`,長度上限 50 字 |
| `app/models.py` | `Household.is_active: bool`(`default=True`) |
| `app/schemas.py` | `HouseholdRegister.household_name` 掛驗證器;`HouseholdOut` 含 `is_active`;`HouseholdUpdate` |
| `app/routers/households.py` | `PATCH /households/me`(改名)、`POST /households/me/archive`、`POST /households/me/unarchive`、`DELETE /households/me/members/{user_id}`,以上均限 `require_admin` |
| `ledger-backend/scripts/purge_household.py` | 永久刪除已封存帳本的一次性腳本(dry-run 預設、`--execute` 才執行) |

### 成員刪除三層防護(`delete_member`)

1. 不可刪除自己的帳號
2. 若目標為管理者,需確認家庭內至少保留一位管理者
3. `Transaction.user_id` 為 `ondelete="SET NULL"`,刪除成員不影響既有交易紀錄,僅 `user_id` 變 NULL

### 封存/解封規則

- 封存前置條件:除自己外沒有其他成員,才能封存
- 封存後:允許登入,但畫面替換成簡易「已封存」頁面,僅 admin 可見「解封帳本」按鈕

## 三、前端

| 檔案 | 說明 |
|---|---|
| `src/utils/validators.ts` | `validateHouseholdName()`,規則與後端同步 |
| `src/views/DashboardView.vue` | 標題顯示實際 household 名稱(`onMounted` 呼叫 `fetchMyHousehold()`),API 失敗 fallback 顯示「家庭理財」 |
| `src/views/MembersView.vue` | 標題旁「編輯」按鈕(僅 admin,inline 編輯);「封存此帳本」按鈕(僅 admin,二次確認);`is_active===false` 時整頁替換為「已封存」畫面;成員列表「刪除」按鈕(僅 admin,不可對自己顯示) |

## 四、CLI 工具:`purge_household.py` + `delete.sh`

| 機制 | 說明 |
|---|---|
| 前置檢查 | 只有 `is_active = False`(已封存)的帳本才能刪 |
| 預覽 | 預設 dry-run,列出成員/帳戶/分類/交易/預算/標籤/審計紀錄各筆數 |
| 二次確認 | `--execute` 時要求手動輸入完整帳本名稱 |
| 刪除順序 | 先刪 `transactions` 再刪 `categories`(避開 `ondelete="RESTRICT"` 限制,已用 SQLite 模擬環境實測驗證) |

`delete.sh`(放在 `~/apps/`,跟 `deploy.sh` 同層):列出已封存帳本 → 輸入名稱 → 二次確認 → 呼叫 `purge_household.py --execute` → 刪除後重新列出核對。同名已封存帳本超過一筆時,要求改用 `--household-id` 指定,避免誤刪。

## 五、決策記錄:為何不做網頁版超級管理員

刪除整個帳本屬高風險破壞性操作。目前規模是單一家用記帳系統,SSH 權限即等同管理員權限,改用 CLI 腳本(比照 `migrate_leaf_categories_to_tags.py` 的安全模式)成本遠低於新增角色欄位/獨立登入機制。

## 六、已知限制 / 後續可考慮

1. 封存/解封目前只在 `MembersView.vue` 生效,若要讓「已封存」狀態鎖住整個 App,需擴充到路由層或 `DashboardView.vue`
2. `purge_household.py` 目前無備份機制,若需要「先備份再刪」,可在刪除前加匯出 JSON/SQL dump 步驟
3. 目前僅能刪除 `member` 角色或「非最後一位」管理者,若未來需要轉讓管理者角色後才刪除,需另外設計轉讓流程

## 七、沿革

| 日期 | 內容 | 詳情 |
|---|---|---|
| 2026-07-07 | Dashboard 標題顯示錯誤 household 名稱修復 | `changelog-details/20260707-household-name-fix.md` |
| 2026-07-07 | 成員刪除功能 | `changelog-details/20260707-session-member-delete.md` |
| 2026-07-08 | 帳本改名 + 防呆 + 封存/解封 + CLI 刪除 | `changelog-details/20260708-household-management.md` |
