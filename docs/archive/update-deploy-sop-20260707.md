# update.sh / deploy.sh 標準作業流程

建立日期:2026-07-07

## 一、背景

逐檔貼路徑覆蓋容易漏檔、貼錯位置。改用 `updateN.sh`(本機執行,覆寫檔案 + `git commit`)取代逐檔手動修改,`push`/`deploy` 保留手動確認,不做自動化串接。

## 二、命名規則

| 項目 | 規則 |
|---|---|
| 檔名 | `updateN.sh`,N 遞增(`update1.sh`, `update2.sh`, ...) |
| 存放位置 | repo 根目錄,與 `deploy.sh` 平級 |
| 內容 | 每個異動檔案的完整覆寫版本(`cat > path << 'EOF'`),或用 `python3` heredoc 做精確字串替換(`sed` 對特殊字元易誤判) |
| commit message | `feat:` / `fix:` 前綴 + 本次異動摘要 |

## 三、腳本骨架

```bash
#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
FRONTEND=ledger-frontend
[ -d "$BACKEND" ] && [ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

# ---------- 完整覆寫檔案 ----------
cat > "$BACKEND/app/routers/xxx.py" << 'EOF'
...
EOF

# ---------- 精確字串替換(優於 sed,不符則直接中止) ----------
python3 << 'PYEOF'
path = "ledger-frontend/src/xxx.vue"
with open(path) as f:
    content = f.read()

old = "..."
new = "..."
if old not in content:
    raise SystemExit("❌ 內容不符,請人工檢查")
content = content.replace(old, new)

with open(path, "w") as f:
    f.write(content)
print("✅ xxx.vue 已修正")
PYEOF

echo "✅ 檔案已寫入完成"
git add -A
git commit -m "fix: 本次異動摘要"
echo "✅ 已 commit,請執行 'git push origin main',再到 server 跑 ./deploy.sh"
```

## 四、執行步驟(每次異動固定流程)

```bash
# 1. 本機 repo 根目錄
chmod +x updateN.sh && ./updateN.sh

# 2. 確認 diff
git diff HEAD~1 --stat

# 3. push(腳本內故意不含此步,避免誤觸發部署)
git push origin main

# 4. server 端部署(注意:若已在 server shell 內,不需再 ssh 進自己)
cd /root/apps && ./deploy.sh

# 5. 瀏覽器強制重整清快取
# Ctrl+Shift+R
```

## 五、本次(A3)實際套用紀錄

| 腳本 | 內容摘要 |
|---|---|
| `update3.sh` | `category_id` UUID→str 修正 + chart 高度對齊 + 分類下鑽功能初版 |
| `update4.sh` | 圖表渲染時序(`nextTick`)+ leaf 模式 SQL 語意修正 |
| `update5.sh` | `requestAnimationFrame` 雙重等待 + 移除 rollup 切換改固定捲層 + 麵包屑改按鈕式 |
| `update6.sh` | 統計頁日期區間選擇(預設今年)+ grid 改 3fr:2fr |
| `update7.sh` | grid 併排改為 tab 切換(月收支趨勢 / 支出分類統計) |

**update5.sh 完整執行序列**(示範):
```bash
chmod +x update5.sh && ./update5.sh
git push origin main
cd /root/apps && ./deploy.sh
```

## 六、常見錯誤與排查

| 現象 | 原因 | 對策 |
|---|---|---|
| `chmod: cannot access 'updateN.sh'` | 腳本內容直接貼進終端機執行,未存成檔案 | 用 `create_file`/`cat > updateN.sh <<'EOF'` 先存檔再 `chmod +x` |
| `ssh finance-server` 要求密碼且失敗 | 已在該台 server shell 內,不需再 ssh 進自己 | 確認 prompt 是否已是 `root@finance-server`,是則直接 `cd /root/apps && ./deploy.sh` |
| 500 / 版面異常修正後又復發 | 先前是直接在 server 上 `sed` 改檔案,未進版控,被 `deploy.sh` 的 `git reset --hard` 蓋掉 | 一律走本機 repo 改 → commit → push → server deploy,禁止在 server 上手動改程式檔案 |
| `python3` heredoc 印出 `❌ ... 不符` | 目標檔案實際內容與腳本假設的舊字串不一致(可能先前手動改過) | 貼目前檔案內容,重新產生對應 updateN.sh |

## 七、SOP 總結

1. 所有程式異動一律走「本機 repo 改 → `updateN.sh` 覆寫 + commit → `git push` → server `./deploy.sh`」
2. 禁止在 server 上直接手動改任何程式檔案(`sed`/vim 皆算),下次 deploy 會被 `git reset --hard` 蓋掉
3. `updateN.sh` 用 `python3` 精確字串比對取代 `sed`,內容不符時直接中止,避免靜默寫入錯誤結果
4. `push` 與 `deploy.sh` 執行步驟刻意保留手動確認,不做自動化串接
