# 功能現況:登入與認證

## 一、後端

| 檔案 | 說明 |
|---|---|
| `app/routers/auth.py` | `register`(含建立 household)、`login`、`forgot-password`、`reset-password` |
| `app/security.py` | bcrypt hash、JWT 簽發/驗證、reset token |
| `app/deps.py` | `get_current_user`、`require_admin` |
| `app/config.py` | `access_token_expire_minutes = 43200`(30 天) |
| `app/email.py` | 忘記密碼信件(Postfix relay,**目前入口暫停**,見 `ops/ops-server-requirements.md`) |

## 二、設計重點

- **Session 效期採「延長 JWT 有效期」而非 refresh token**:單一裝置長期持有、無需頻繁換發的場景,延長 JWT 有效期是最小改動且足夠;refresh token 需額外 endpoint + DB 表,複雜度不對稱於需求
- 前端 `stores/auth.ts`(Pinia)只存 `token`/`role`/`household_id`,不存 household 名稱等頁面層資料,避免過度耦合(household 名稱由各頁自行 `fetchMyHousehold()` 取得)

## 三、前端

- `src/router/index.ts`:路由守衛
- `src/views/Login/Register/ForgotPassword/ResetPassword.vue`

## 四、已知限制 / 後續可考慮

- 若之後上 HTTPS,可評估是否改為 refresh token 機制,兼顧安全性與長效登入體驗
- 忘記密碼信件功能:程式碼已完成,但 Postfix 入口目前暫停(見 `ops/ops-server-requirements.md` service 現況)

## 五、沿革

| 日期 | 內容 | 詳情 |
|---|---|---|
| 2026-07-07 | 登入效期由 1 天延長為 30 天 | `changelog-details/20260707-session-member-delete.md` |
