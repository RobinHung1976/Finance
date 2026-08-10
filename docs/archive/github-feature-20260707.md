# GitHub / Git 化部署流程

建立日期:2026-07-07

## 一、背景與目的

原本部署方式為 `rm -rf ledger-backend && unzip ledger-backend.zip`,兩個已知風險已實際發生過:
- Migration 檔案曾在某次 zip 打包時遺失(詳見 `migration-history-20260706.md`)
- `.env` 每次都要手動備份/還原,容易漏做

改用 Git 追蹤原始碼,部署改為 `git fetch` + `git reset --hard`,消除上述風險。

## 二、決策

| 項目 | 決定 |
|---|---|
| 存放位置 | GitHub 私有 repo:`RobinHung1976/Finance`(帳號大小寫已被 GitHub 正規化,原輸入 `robinhung1976`) |
| Repo 結構 | Monorepo(`ledger-backend/` + `ledger-frontend/` 同一個 repo) |
| 初始化方式 | 直接在 server 現有目錄 `git init`,保留現有檔案當 first commit |
| 驗證方式 | SSH Deploy Key(單一 server 對單一 repo,比 PAT 更好管理,不需 rotate) |

## 三、SSH Deploy Key 設定

```bash
# server 上產生專用 key
ssh-keygen -t ed25519 -C "finance-server-deploy" -f ~/.ssh/finance_deploy_key -N ""

# ~/.ssh/config 加入 host alias
cat > ~/.ssh/config << 'EOF'
Host github-finance
    HostName github.com
    User git
    IdentityFile ~/.ssh/finance_deploy_key
    IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config ~/.ssh/finance_deploy_key
```

- GitHub 端:repo → Settings → Deploy keys → Add deploy key,貼公鑰,**初次 push 需勾選 Allow write access**
- **待辦**:initial push 完成後,建議把這把 key 改回**唯讀**(取消 write access),降低 server 被入侵時的風險範圍

## 四、.gitignore 設計

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

**關鍵原則**:`alembic/versions/*.py` **絕對不能被排除**,這是上次事故的根源。

## 五、日常部署流程

```
本機改 code → git add/commit → git push origin main
                                        ↓(手動觸發,目前無自動化)
                              server: cd ~/apps && ./deploy.sh
                              (內部執行 git fetch + reset --hard origin/main)
```

- Git 本身不是同步工具,不會自動雙向同步
- Server 端不應直接修改程式碼(改了會被下次 `reset --hard` 蓋掉)
- 是否要接 GitHub Actions / webhook 做到「push 後自動部署」:目前決定**先手動跑,穩定後再考慮**

## 六、初始化過程踩坑紀錄

| 問題 | 原因 | 解法 |
|---|---|---|
| `git remote add` 報 `not a git repository` | `git init` 實際上沒有執行成功就往下執行了後續指令 | 重新確認 `.git` 是否存在,補跑 `git init` |
| `node_modules/` 被整包 commit | `.gitignore` 建立指令沒有真的寫入檔案,`git add .` 時規則不存在 | `git reset` 撤銷 staging,確認 `.gitignore` 內容存在後重新 `git add` |
| `git commit` 報 `Author identity unknown` | server 上從未設定過 git 身份 | `git config user.email` / `user.name` |
| `ssh -T github-finance` 報 `Could not resolve hostname` | `~/.ssh/config` 檔案根本不存在(先前的建立指令沒被執行到) | 重新用 `cat > ~/.ssh/config` 建立並確認 `cat` 有內容 |
| `git push` 被 `[rejected]`(fetch first) | GitHub 建 repo 時自動產生初始 commit(如 README),兩邊 history 不相關 | 確認 remote 只有無關緊要的自動內容後,`git push --force` 覆蓋 |
| Push 成功但提示 repo moved | GitHub 帳號/repo 路徑大小寫正規化(`robinhung1976` → `RobinHung1976`) | `git remote set-url origin git@github-finance:RobinHung1976/Finance.git` |

## 七、目前狀態

- ✅ Repo 已建立並可正常 push/pull
- ✅ `deploy.sh` 已改為 git-based(見 `finance-2nd-A1-A2-20260707.md` 內完整腳本)
- ⏳ Deploy key 尚未改回唯讀(待辦)
- ⏳ 自動化部署(push 後自動觸發)尚未建立,暫緩

## 八、後續建議

1. **Deploy key 改唯讀**:initial push 完成後立刻做,目前 write access 開著是不必要的風險
2. **本機開發環境也接上同一個 repo**:目前 repo 只存在於 server,本機改 code 後應該 push 到同一個 remote,而不是繼續用「產 zip 給 Claude → Claude 給 server」這種方式
3. **未來若要自動化部署**:可用 GitHub Actions + self-hosted runner,或簡單的 webhook 監聽 push 事件觸發 `deploy.sh`
