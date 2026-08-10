# GitHub 連線與部署流程

Repo:`Finance`(GitHub 帳號 `RobinHung1976`,大小寫已被 GitHub 正規化,注意 remote URL 需一致避免每次 push 出現轉址提示)。Monorepo 結構(`ledger-backend/` + `ledger-frontend/` 同一個 repo)。

## 一、Server 連上 GitHub(SSH Deploy Key)

### 1. 產生專用金鑰(不與個人 SSH key 混用)

```bash
ssh-keygen -t ed25519 -C "finance-server-deploy" -f ~/.ssh/finance_deploy_key -N ""
```

### 2. SSH 別名

```bash
cat > ~/.ssh/config << 'EOF'
Host github-finance
    HostName github.com
    User git
    IdentityFile ~/.ssh/finance_deploy_key
    IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config ~/.ssh/finance_deploy_key
```

### 3. GitHub 端設定

Repo → Settings → Deploy keys → Add deploy key,貼上公鑰。本專案在 server 上直接 `git commit` + `git push`,**勾選 Allow write access**。

> **待辦**:initial push 完成後建議把 key 改回唯讀,降低 server 被入侵時的風險範圍。

### 4. 測試連線

```bash
ssh -T github-finance
# 預期:Hi RobinHung1976! You've successfully authenticated...
```

## 二、`.gitignore` 設計

```gitignore
# Python
ledger-backend/venv/
ledger-backend/__pycache__/
ledger-backend/**/__pycache__/
*.pyc

# Node
ledger-frontend/node_modules/
ledger-frontend/dist/

# 機密設定,不進版控
ledger-backend/.env
ledger-frontend/.env
ledger-frontend/.env.production

# 部署產物,不進版控
*.zip

# OS
.DS_Store
```

**關鍵原則**:`alembic/versions/*.py` **絕對不能被排除**——migration 檔案曾在舊版 zip 打包流程中遺失,是改用 Git 化部署的根本原因。

## 三、日常部署流程

```
本機改 code → git add/commit → git push origin main
                                        ↓(手動觸發,目前無自動化)
                              server: cd ~/apps && ./deploy.sh
                              (內部執行 git fetch + reset --hard origin/main)
```

- Server 端**不應直接修改程式碼**(改了會被下次 `deploy.sh` 的 `git reset --hard` 蓋掉,已多次踩坑驗證,見 `changelog-details/20260707-bug-fix-batch.md`)
- 是否接 GitHub Actions/webhook 做自動化部署:目前決定先手動跑,穩定後再考慮

## 四、`updateN.sh`/`deploy.sh` 撰寫慣例

見 `ops/ops-deployment.md`。

## 五、目前狀態

- ✅ Repo 已建立並可正常 push/pull,`deploy.sh` 已改為 git-based
- ⏳ Deploy key 尚未改回唯讀(待辦)
- ⏳ 自動化部署(push 後自動觸發)尚未建立,暫緩

## 六、已知問題排查(初始化過程曾踩過的坑)

| 問題 | 原因 | 解法 |
|---|---|---|
| `git remote add` 報 `not a git repository` | `git init` 未真正執行成功即往下跑 | 確認 `.git` 是否存在,補跑 `git init` |
| `node_modules/` 被整包 commit | `.gitignore` 建立指令未真正寫入檔案 | `git reset` 撤銷 staging,確認 `.gitignore` 內容後重新 `git add` |
| `git commit` 報 `Author identity unknown` | server 上從未設定 git 身份 | `git config user.email`/`user.name` |
| `ssh -T github-finance` 報 `Could not resolve hostname` | `~/.ssh/config` 不存在 | 重新用 `cat > ~/.ssh/config` 建立並確認內容 |
| `git push` 被 `[rejected]` | GitHub 建 repo 時自動產生初始 commit,兩邊 history 不相關 | 確認 remote 只有無關緊要內容後 `git push --force` |
| Push 成功但提示 repo moved | GitHub 帳號/repo 路徑大小寫正規化 | `git remote set-url origin git@github-finance:RobinHung1976/Finance.git` |
