# 功能新增:帳本改名 + 名稱防呆 + 封存/解封 + CLI 永久刪除

建立日期:2026-07-08

## 一、範圍

- 帳本名稱事後修改(原本只能在註冊時設定一次)
- 帳本名稱防呆:白名單驗證(僅允許中文、英文、數字、空白、底線、連字號)
- 封存/解封帳本(軟刪除,可還原,不動 DB 資料)
- 永久刪除已封存帳本的 CLI 工具(不做網頁版超級管理員,理由見第六節決策記錄)

## 二、後端變更

### 新增檔案
- `app/validators.py`:`validate_household_name()`,白名單正則 `^[\u4e00-\u9fffA-Za-z0-9 _-]+$`,長度上限 50 字
- `ledger-backend/scripts/purge_household.py`:永久刪除已封存帳本的一次性腳本(dry-run 預設、`--execute` 才真的執行)

### 修改檔案

| 檔案 | 異動內容 |
|---|---|
| `app/models.py` | `Household` 新增 `is_active: Mapped[bool]`(`default=True`, `server_default="true"`) |
| `app/schemas.py` | `HouseholdRegister.household_name` 掛上 `validate_household_name` 驗證器;`HouseholdOut` 新增 `is_active`;新增 `HouseholdUpdate` schema |
| `app/routers/households.py` | 新增 `PATCH /households/me`(改名)、`POST /households/me/archive`(封存)、`POST /households/me/unarchive`(解封),皆限 `require_admin` |
| `alembic/versions/dc63aa5d7ba7_add_household_is_active.py` | `households` 表新增 `is_active` 欄位(`server_default='true'`),已人工檢查僅此單一異動 |

### 技術重點

- **驗證器綁定方式**:`_validate_household_name = field_validator("household_name")(validate_household_name)`,實測(pydantic runtime 測試,非僅語法檢查)確認此寫法在 pydantic v2 下正確生效
- **封存前置條件**:`archive_household` 檢查「除自己外沒有其他成員」(不分 admin/member),否則拒絕並提示「帳本內還有其他成員,只有最後一位成員時才能封存」
- **封存後行為**:允許登入,但畫面替換成簡易「已封存」頁面,僅 admin 可見「解封帳本」按鈕,一般成員唯讀

## 三、前端變更

### 新增檔案
- `src/utils/validators.ts`:`validateHouseholdName()`,規則與後端 `app/validators.py` 同步

### 修改檔案

| 檔案 | 異動內容 |
|---|---|
| `src/types/api.ts` | `HouseholdOut` 新增 `is_active: boolean` |
| `src/api/auth.ts` | 新增 `updateHousehold()`、`archiveHousehold()`、`unarchiveHousehold()` |
| `src/views/MembersView.vue` | 標題旁新增「編輯」按鈕(僅 admin,inline 編輯 + 儲存/取消);新增「封存此帳本」按鈕(僅 admin,`confirm()` 二次確認);`is_active === false` 時整頁替換為簡易「已封存」畫面 |

## 四、CLI 工具:`purge_household.py` + `delete.sh`

### 設計決策

刪除整個帳本屬於高風險破壞性操作(牽連刪除該帳本底下所有成員/帳戶/分類/交易/預算/標籤/審計紀錄)。討論後決定**不建立網頁版超級管理員角色**,理由:

- 目前規模是單一家用記帳系統,SSH 權限即等同管理員權限,這條權限邊界最清楚
- 建立網頁版超級管理員需要新增角色欄位、`User.household_id` 改 nullable 或另開獨立表、獨立登入機制,對目前規模不成比例
- 改用 CLI 腳本,比照既有 `migrate_leaf_categories_to_tags.py` 的安全模式(dry-run 預設、`--execute` 才執行、單一 transaction)

### `purge_household.py` 安全機制

| 機制 | 說明 |
|---|---|
| 前置檢查 | 只有 `is_active = False`(已封存)的帳本才能刪 |
| 預覽 | 預設 dry-run,列出成員/帳戶/分類/交易/預算/標籤/審計紀錄各筆數,不寫入任何異動 |
| 二次確認 | `--execute` 時要求手動輸入完整帳本名稱,不符即取消 |
| 交易安全 | 全程單一 DB transaction,任何步驟失敗自動 rollback |
| **刪除順序** | 先刪 `transactions` 再刪 `categories`,避開 `Transaction.category_id`(`ondelete="RESTRICT"`)的限制 |

**刪除順序已用 SQLite 建立含真實 FK 限制(`RESTRICT`/`CASCADE`)的模擬環境實測驗證**:先刪 `categories` 會被 `RESTRICT` 擋下(`IntegrityError`),先刪 `transactions` 則完全成功。

### `delete.sh`:一鍵包裝腳本

放在 `~/apps/`(跟 `deploy.sh` 同一層),流程:

```
1. psql 列出 is_active = false 的帳本
2. 輸入要刪除的帳本名稱
3. 二次輸入帳本名稱確認
4. 呼叫 purge_household.py --execute(用 pipe 帶入已確認過的名稱,避免內部再問第三次)
5. 刪除後重新列出所有帳本狀態,供核對
```

同名且已封存的帳本超過一筆時,腳本會列出所有候選 `id` 並中止,要求改用 `purge_household.py --household-id <id>` 手動指定,避免用名稱誤刪錯一筆。

已用假的 `psql`/`python` 模擬三種情境測試通過:名稱不存在、二次確認名稱打錯、完整成功流程。

## 五、Bug 修復紀錄(這次踩坑)

### 1. `update29.sh`(即 `update9.sh`)靜默失敗,改動從未進版控

| 項目 | 內容 |
|---|---|
| 現象 | 改名按鈕網頁上完全看不到,`~@!` 這類符號在註冊時也沒被擋下 |
| 原因 | 該次執行在某個字串比對步驟中止(`set -euo pipefail`),`git commit` 從未跑到;之後又被下一次 `deploy.sh` 的 `git reset --hard` 蓋掉痕跡,跟 `bug-fix-20260707.md` 記錄的坑同一種模式 |
| 排查方式 | 請使用者上傳目前 server 上檔案的實際內容,發現與最原始版本逐字相同,證實改動從未真正生效 |
| 教訓 | 執行 `updateN.sh` 後務必立刻 `git log --oneline` / `git show --stat HEAD` 確認 commit 真的成功,再進行 push/deploy,不能只看終端機有沒有印出錯誤字樣就假設成功 |

### 2. `update31.sh` 首次執行時字串比對失敗

| 項目 | 內容 |
|---|---|
| 現象 | `❌ MembersView.vue <template> 開頭區塊內容不符` |
| 原因 | 重寫比對字串時漏看了原檔案中 `</h2>` 與 `<button>` 之間的一行 HTML 註解(`<!-- 僅管理者可見:... -->`) |
| 排查方式 | 請使用者提供 `cat -A` 輸出(排除換行符號差異的可能性),逐行比對後定位到漏看的註解行 |
| 修正 | 補回註解行後,用使用者實際貼的內容重建測試環境,完整跑過一次確認成功 |
| 附帶修正 | 同時發現 `utils/validators.ts` 寫入前少了 `mkdir -p`,若該目錄不存在會直接失敗(與 `deploy.sh` 曾經缺 `mkdir -p "$WEB_ROOT"` 同類型錯誤),已在腳本中補上 |

### 3. `psql` 誤用 SQLAlchemy 專用連線字串格式

| 項目 | 內容 |
|---|---|
| 現象 | `psql "postgresql+psycopg2://..."` 報 `role "root" does not exist` |
| 原因 | `+psycopg2` 是 SQLAlchemy 用來指定驅動的語法,`psql` 原生工具看不懂這段,導致整串連線字串解析失敗,退回用預設值(目前 OS 帳號)連線 |
| 修正 | `psql` 一律用 `postgresql://...`,拿掉 `+psycopg2`;`delete.sh` 內已自動用 `sed 's/+psycopg2//'` 處理,不需手動改 |

## 六、目前狀態

- ✅ 帳本改名功能已上線並測試通過(admin 專屬,`PATCH /households/me`)
- ✅ 帳本名稱白名單驗證已生效(前後端同步規則,pydantic runtime 已實測)
- ✅ 封存/解封功能已上線並測試通過(封存前置條件、已封存畫面、admin 解封皆驗證正常)
- ✅ `purge_household.py` 已在正式環境實測:對 `test test` 測試帳本執行 dry-run + `--execute`,刪除結果與預覽數字完全一致
- ✅ `delete.sh` 包裝腳本已建立,涵蓋列出/輸入/二次確認/刪除後核對的完整流程

## 七、後續可考慮事項

1. 目前封存/解封只在 `MembersView.vue` 生效,若要讓「已封存」狀態鎖住整個 App(而不只是成員管理頁),需要擴充到路由層或 `DashboardView.vue`
2. `purge_household.py` 目前是徹底刪除,沒有備份機制;若之後想要「先備份再刪」,可以在刪除前加一段把該帳本資料匯出成 JSON/SQL dump 的步驟
3. 待處理:歷史帳戶餘額落差回補(`bug-fix-20260708-excel-import-export.md` 提及,Excel 匯入曾經沒有同步更新帳戶餘額,已修的是「之後」的匯入,「之前」匯入的歷史資料還沒回補)
