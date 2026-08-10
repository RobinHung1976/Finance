專案架構
ledger-backend/                    # FastAPI
├── app/
│   ├── config.py                  # Settings(.env 讀取)
│   ├── database.py                # SQLAlchemy engine/session
│   ├── models.py                  # ORM: household/user/account/category/transaction/budget/tag/reset_token
│   ├── deps.py                    # get_current_user / require_admin
│   ├── security.py                # bcrypt hash、JWT 簽發/驗證、reset token
│   ├── email.py                   # Postfix relay 寄信
│   ├── schemas.py                 # auth 相關 pydantic schema
│   ├── schemas_ledger.py          # account/category/transaction schema
│   ├── main.py                    # FastAPI app + CORS + router 掛載
│   └── routers/
│       ├── auth.py                # register/login/forgot-password/reset-password
│       ├── households.py          # 家庭資訊、成員管理
│       ├── accounts.py            # 帳戶 CRUD + 餘額調整連動
│       ├── categories.py          # 分類 CRUD(鄰接表)
│       └── transactions.py        # 交易 CRUD + 帳戶餘額自動連動
├── alembic/                       # migration
└── requirements.txt

ledger-frontend/                   # Vue3 + TS + Vite
├── src/
│   ├── api/                       # client.ts(axios+JWT攔截)、auth.ts、ledger.ts
│   ├── stores/auth.ts             # Pinia:token/role/household_id
│   ├── router/index.ts           # 路由守衛
│   ├── types/                     # api.ts、ledger.ts
│   ├── utils/ledgerLabels.ts     # 中文標籤、幣別格式化
│   ├── components/
│   │   ├── CategoryPicker.vue     # 逐層鑽取選擇器(可複用)
│   │   ├── CategoryTreeNode.vue   # 遞迴摺疊樹節點
│   │   ├── CategoryList.vue       # 分類管理頁
│   │   ├── AccountList.vue        # 帳戶管理頁
│   │   └── TransactionList.vue    # 交易紀錄(卡片+日期分組)
│   └── views/                     # Login/Register/Dashboard/Members/ForgotPassword/ResetPassword

Service 現況
Service狀態說明PostgreSQLsystemd 常駐systemctl enable --now 
postgresqlledger-api（後端）✅ 已是 systemd 
service/etc/systemd/system/ledger-api.service，開機自啟、當機自動重啟(Restart=on-failure)
前端❌ 不是 service目前用 nohup npm run dev -- --host &，手動背景執行
Nginxsystemd 常駐已設定反代 127.0.0.1:8000，但目前前端沒有透過它 serve，是直接用 Vite dev server 的 5173 port
Postfixsystemd 常駐寄信用，功能已完成但入口暫停