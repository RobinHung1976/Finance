# Server 環境需求

## 一、系統架構

```
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
│       ├── households.py          # 家庭資訊、成員管理、改名/封存/解封
│       ├── accounts.py            # 帳戶 CRUD + 餘額調整連動
│       ├── categories.py          # 分類 CRUD(鄰接表)
│       ├── transactions.py        # 交易 CRUD + 帳戶餘額自動連動 + 進階篩選
│       ├── transactions_transfer.py  # Excel 匯入/匯出
│       ├── tags.py                # 消費品項 CRUD
│       └── stats.py               # 統計 API
├── alembic/                       # migration
└── requirements.txt

ledger-frontend/                   # Vue3 + TS + Vite
├── src/
│   ├── api/                       # client.ts(axios+JWT攔截)、auth.ts、ledgerApi.ts、importExport.ts
│   ├── stores/auth.ts             # Pinia:token/role/household_id
│   ├── router/index.ts            # 路由守衛
│   ├── types/                     # api.ts、ledger.ts、importExport.ts
│   ├── utils/                     # ledgerLabels.ts(中文標籤、幣別格式化)、validators.ts
│   ├── components/                # CategoryPicker/CategoryTreeNode/CategoryList/CategoryFilterPicker/
│   │                               # AccountList/AccountFilterPicker/TransactionList/TagPicker/TagList/
│   │                               # TagFilterPicker/MonthlyTrendChart/CategoryBreakdownChart/
│   │                               # TagBreakdownChart/ExcelImportExport
│   └── views/                     # Login/Register/Dashboard/Members/ForgotPassword/ResetPassword
```

## 二、Service 現況

| Service | 狀態 | 說明 |
|---|---|---|
| PostgreSQL | systemd 常駐 | `systemctl enable --now postgresql` |
| `ledger-api`(後端) | systemd,已 enabled | `WorkingDirectory=/root/apps/ledger-backend`,開機自啟、當機自動重啟(`Restart=on-failure`) |
| 前端 | 非獨立 process | `vite build` 產出靜態檔,由 Nginx 直接 serve(不再用 `nohup npm run dev`) |
| Nginx | systemd 常駐 | 單一入口(靜態檔 + API reverse proxy),監聽對外 port `17756`,細節見 `ops/ops-infra-public-access.md` |
| Cloudflare Tunnel | 暫停使用 | 原規劃方案,改用 FortiGate 對外 |
| Postfix | systemd 常駐,入口暫停 | 忘記密碼信件功能已完成,入口暫停 |

## 三、Python 環境

虛擬環境:`ledger-backend/venv/`

```bash
cd ledger-backend
source venv/bin/activate
pip install -r requirements.txt
```

主要套件:`fastapi`、`sqlalchemy`、`alembic`、`python-dateutil`、`openpyxl`、`bcrypt`、`python-jose`(或對應 JWT 套件)。

## 四、完整目錄路徑對照表

| 用途 | 路徑 |
|---|---|
| 部署根目錄 | `/root/apps` |
| 後端目錄 | `/root/apps/ledger-backend/` |
| 前端目錄 | `/root/apps/ledger-frontend/` |
| 前端靜態檔輸出 | `/var/www/ledger-frontend` |
| Nginx 設定 | `/etc/nginx/sites-available/ledger` |
| systemd service | `/etc/systemd/system/ledger-api.service` |

## 五、部署方式

見 `ops/ops-deployment.md`(Git-based:`updateN.sh` + `deploy.sh`)。
