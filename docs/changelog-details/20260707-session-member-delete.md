# 功能修改:登入效期延長 + 成員刪除功能

建立日期:2026-07-07

## 一、範圍

- 需求 1:登入後延長 session,避免同一台裝置頻繁重新登入
- 需求 2:成員管理頁新增刪除成員功能

## 二、後端變更

### 修改檔案

| 檔案 | 異動內容 |
|---|---|
| `app/config.py` | `access_token_expire_minutes` 預設值 `1440`(1天)→ `43200`(30天) |
| `app/routers/households.py` | 新增 `DELETE /households/me/members/{user_id}` |

### 技術重點

- **Session 延長採「延長 JWT 效期」而非 refresh token**:單一裝置長期持有、無需頻繁換發的場景,延長 JWT 有效期是最小改動且足夠;refresh token 需額外 endpoint + DB 表,複雜度不對稱於需求
- **刪除成員三層防護**(`delete_member`):
  1. 不可刪除自己的帳號
  2. 若目標為管理者,需確認家庭內至少保留一位管理者
  3. `Transaction.user_id` 為 `ondelete="SET NULL"`,刪除成員不影響既有交易紀錄,僅 `user_id` 變為 NULL

## 三、前端變更

### 修改檔案

| 檔案 | 異動內容 |
|---|---|
| `src/api/auth.ts` | 新增 `deleteMember(userId)` |
| `src/views/MembersView.vue` | 成員列表加入「刪除」按鈕(僅 admin 可見,且不可對自己顯示) |

### UI 邏輯

- 刪除前 `confirm()` 二次確認,避免誤觸
- 前端 `v-if` 僅為 UX 層級限制(隱藏按鈕),實際權限邊界仍由後端 `require_admin` 及三層防護把關,避免繞過前端直打 API

## 四、狀態

- ✅ 登入效期已延長至 30 天,驗證：長時間未操作仍維持登入狀態
- ✅ 成員刪除功能已上線並測試通過(刪除一般成員、UI 按鈕僅 admin 可見)
- ✅ `deploy.sh` 部署驗證正常

## 五、後續可考慮事項

- 若之後上 HTTPS,可評估是否改為 refresh token 機制,兼顧安全性與長效登入體驗
- 目前僅能刪除 `member` 角色或「非最後一位」管理者,若未來需要轉移管理者角色後才刪除,需另外設計轉讓流程
