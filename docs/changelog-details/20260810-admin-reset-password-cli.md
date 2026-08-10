# 管理員手動重設密碼 CLI

## 背景

忘記密碼信件功能(`/auth/forgot-password`)程式碼已完成,但 Postfix 寄信入口目前暫停(見 `PROJECT-OVERVIEW.md` 已知待處理事項),使用者測試忘記密碼流程時收不到信,暫時無法透過正規流程重設密碼。管理員也沒有任何管道查看或協助重設使用者密碼——密碼欄位是 bcrypt 單向雜湊(`security.py` / `passlib.CryptContext`),原始密碼從產生當下就無法被還原,這是預期的安全設計,不是缺陷。

## 決策

在 Postfix 入口恢復之前,提供管理員一支獨立 CLI 腳本(`ledger-backend/reset_password.py`),讓管理員能直接於 server 端手動為指定使用者產生新密碼、寫入 DB,作為臨時替代方案。

關鍵決策點:

- **查詢鍵用 `username` 而非 `email`**:`models.py` 的 `email` 欄位註解「可共用,非唯一」(`UniqueConstraint` 只綁 `username`),用 email 查詢可能誤中同 email 的其他 household 使用者,有改錯人密碼的風險。
- **密碼雜湊沿用既有 `hash_password()`**:與 `auth.py` 的 `register`/`reset-password` 用同一套 `passlib` bcrypt 邏輯,確保雜湊格式與既有驗證邏輯(`verify_password()`)相容。
- **稽核紀錄直接寫入 `AuditLog` model,不呼叫 `app.audit.log_action()`**:`log_action()` 是設計給有 `current_user`(登入中管理員)的 API 情境使用,其內部如何組出 `household_id`/`actor_name` 未經確認;CLI 場景沒有登入中的使用者物件可傳,直接指定欄位語意更明確,`user_id=None`(操作者是 CLI/管理員本人,不歸給被改密碼的使用者)、`actor_name="admin-cli"` 標明來源,方便日後在 `/households/me/audit-logs` 查詢時分辨。

## 修改內容

新增檔案:`ledger-backend/reset_password.py`

```bash
python reset_password.py <username> <新密碼>
```

- 新密碼長度需 ≥ 8 碼,否則直接擋下不執行
- 查無該 `username` 時明確報錯,不靜默失敗
- 成功後同步寫入一筆 `AuditLog`(`action="update"`, `resource_type="user"`, `actor_name="admin-cli"`)
- 例外狀況一律 `rollback()`,不會留下半殘留的變更

透過 `update48.sh` 部署(Git-based 流程,`ops-deployment.md`),純新增檔案未改動任何既有程式邏輯。

## 目前狀態

- ✅ 已部署、測試成功(server 端可正常用 username 重設密碼並登入)
- ⚠️ 屬臨時替代方案,待 Postfix 入口恢復、`/auth/forgot-password` 正規流程可用後,此 CLI 仍可保留作為管理員後備手段
- 未串接 `log_action()` 統一稽核邏輯,若日後確認其內部實作與此腳本假設相容,可考慮改用該函式以維持一致性
