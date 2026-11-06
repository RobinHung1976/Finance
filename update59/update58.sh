#!/usr/bin/env bash
# update58.sh — 前端改版 E2-2:帳戶/分類/消費品項/匯入匯出 四頁改用金屬主題 class,移除 inline style
#   - 帳戶:表格(名稱/類型/餘額/操作)+ 合計列,餘額在列內調整;新增表單改欄位格線
#   - 分類:支出/收入改 LED 按鍵;分類樹列改金屬按鍵;搜尋結果改表格
#   - 消費品項:新增欄移到面板標題列;品項改金屬膠囊鍵(含使用次數);選取後下方顯示改名/刪除列
#   - 匯入匯出:預覽改統計卡片 + 表格(類型色塊、狀態標籤);匯入完成/取消後清空檔案欄位;載入帳戶失敗顯示訊息
# 執行位置:server 的 /root/apps(root)
set -euo pipefail

CURRENT=58
FE=ledger-frontend

# ---------- 前置驗證(不通過不寫入任何檔案) ----------
[ -d .git ] && [ -d "$FE/src" ] && [ -f deploy.sh ] \
  || { echo "❌ 請在 Finance repo 根目錄執行(需有 .git、$FE/src、deploy.sh)" >&2; exit 1; }
if ! git ls-files --error-unmatch docs/changelog-details/20261106-transactions-report-view.md >/dev/null 2>&1; then
  echo "❌ 尚未包含 update57.sh 的改動,請先確認 update57.sh 是否已成功套用" >&2; exit 1
fi
if grep -q "class=\"tag-key\"" "$FE/src/components/TagList.vue"; then
  echo "❌ 已套用過本次更新,不需重跑" >&2; exit 1
fi
if ! git diff --quiet HEAD -- "$FE" || ! git diff --cached --quiet -- "$FE"; then
  echo "❌ $FE 有未 commit 的修改,請先處理後再執行" >&2; exit 1
fi

# 要覆寫/刪除的既有檔案,內容必須與產生腳本時看到的版本完全一致
check_sha() {
  local f="$FE/$1" want="$2" got
  [ -f "$f" ] || { echo "❌ 找不到 $f" >&2; exit 1; }
  got=$(sha256sum "$f" | cut -d' ' -f1)
  [ "$got" = "$want" ] || { echo "❌ $f 內容與預期版本不符(可能已被修改),中止" >&2; exit 1; }
}
check_sha src/styles/theme.css 655e75a0a2a689fb8ef4145fc6aaa24a02f5daa619580c3c9271b2a259199470
check_sha src/components/AccountList.vue be4c3c333486c0f79b3580f4cd893ecdb5e117ee3c5ef62c9db7ac751d23077c
check_sha src/components/CategoryList.vue 235a488876862eb5c400c83aa06d01650cad4e43cfeb2e288f52f55cb74e5fa8
check_sha src/components/CategoryTreeNode.vue 7e599885db0320fe686dc03d613b3645aade46b6a1388a89d29572a37876437e
check_sha src/components/TagList.vue 1dc514ed369e6b9ff5f9156e140d6091ebd045ae837871619ee1ba2375796313
check_sha src/components/ExcelImportExport.vue 6cfe500f60dc437b29ce20f7c056c38e20c4e94a0f0e1c3ff9897c88eec51bbd
check_sha src/views/AccountsView.vue 0f812488c08c761a757ef89b01555caeac279dd65576406f0d2d17db5091acef
check_sha src/views/CategoriesView.vue dc70b47f2f3f90d5598391f6cd4f735dcf1a781d91339d905dd28ab8088f4ab1
check_sha src/views/TagsView.vue c45259f81a79d8823c37ddf050a89f3fb92cc323950a47e5da6c02c0d6a9859f
check_sha src/views/TransferView.vue 33f911410ea95b549357ced8aa99314bb9cd1d755458b405348ffd793d195d81
echo "✅ 前置驗證通過"

# ---------- 自動歸檔 ----------
mkdir -p "update${CURRENT}"
for f in update*.sh; do
  [ "$f" = "update${CURRENT}.sh" ] && continue
  [ -f "$f" ] || continue
  git mv "$f" "update${CURRENT}/$f" 2>/dev/null || mv "$f" "update${CURRENT}/$f"
done
git add -A "update${CURRENT}" 2>/dev/null || true
if ! git diff --cached --quiet; then
  git commit -m "chore: 歸檔已執行的 updateN.sh 腳本"
fi

# ---------- 寫入檔案(整份覆寫;新檔案即使殘留也一律覆寫) ----------
cat > "$FE/src/styles/theme.css" << '__F58_EOF__'
/* Finance Ledger — 金屬主題：淺色拉絲鋼內容區、深色拉絲側欄、金屬面板與按鍵；品牌色為墨綠金屬 */
:root {
  color-scheme: light;
  --font: "Segoe UI", "Noto Sans TC", "Noto Sans CJK TC", "Microsoft JhengHei", "PingFang TC", system-ui, sans-serif;
  --font-mono: "Cascadia Mono", Consolas, "JetBrains Mono", ui-monospace, "Microsoft JhengHei", monospace;

  /* 拉絲紋理（細直線） */
  --brush-light: repeating-linear-gradient(90deg, rgb(255 255 255 / 16%) 0 1px, rgb(0 0 0 / 2.5%) 1px 2px, transparent 2px 4px);

  /* 金屬面（由亮到暗） */
  --metal-plate: linear-gradient(180deg, #f7f8f9 0%, #e7e9ec 55%, #dcdfe3 100%);
  --metal-key: linear-gradient(180deg, #fbfbfc 0%, #e2e5e9 48%, #cfd3d8 52%, #e3e6e9 100%);
  --metal-key-hover: linear-gradient(180deg, #ffffff 0%, #eceef1 48%, #dadde2 52%, #eceef1 100%);
  --metal-key-down: linear-gradient(180deg, #cdd1d6 0%, #dcdfe3 100%);
  --metal-dark: linear-gradient(180deg, #70757d 0%, #50545b 48%, #42464c 52%, #5a5e65 100%);
  --metal-dark-hover: linear-gradient(180deg, #7e838b 0%, #5c6068 48%, #4d5157 52%, #666a71 100%);
  /* 卡片雙色立體面：上半亮、下半暗，中間明顯分界 */
  --card-2tone: linear-gradient(180deg, #ffffff 0%, #eef0f3 49%, #d2d6db 50%, #c3c8ce 100%);
  --card-2tone-hover: linear-gradient(180deg, #ffffff 0%, #f5f6f8 49%, #dcdfe3 50%, #cfd3d8 100%);
  --card-2tone-lit: linear-gradient(180deg, #ffffff 0%, #fbfcfd 49%, #e6eaee 50%, #dce1e7 100%);

  /* 品牌：墨綠金屬（基準色 #1f5f4f，同 PWA theme_color） */
  --brand: #1f5f4f;
  --brand-metal: linear-gradient(180deg, #5fae96 0%, #2b7a64 49%, #1f5f4f 50%, #286f5c 100%);
  --brand-metal-lit: linear-gradient(180deg, #8fd0bb 0%, #3f9078 48%, #26705b 52%, #3c8a73 100%);
  --brand-edge: #123d33;
  --brand-glow: rgb(80 190 150 / 55%);
  --lamp: #ffb547;   /* 品牌列指示燈（琥珀色，在綠底上可辨識） */

  --side-text: #e4e6ea;
  --side-muted: #c3c8ce;
  --side-line: rgb(255 255 255 / 10%);

  --line: #b8bec6;
  --line-soft: #ccd1d7;
  --field-line: #a6adb6;

  --text: #1d2228;
  --text-2: #30363e;
  --muted: #555d68;

  --accent: #1f5f4f;
  --accent-hover: #17493c;
  --focus: #2f8f73;

  --ok: #1f7a3a;
  --ok-soft: #e4f3e8;
  --ok-line: #9fd0ae;
  --warn: #8a4b00;
  --warn-soft: #fbf0d6;
  --warn-line: #dfbd6e;
  --bad: #b42318;
  --bad-soft: #f9e5e3;
  --bad-line: #e6aaa4;

  --radius: 10px;
  --radius-sm: 6px;
  --bevel: inset 0 1px 0 rgb(255 255 255 / 95%), inset 0 -1px 0 rgb(0 0 0 / 8%);
  --shadow: 0 1px 1px rgb(0 0 0 / 12%), 0 4px 14px rgb(30 35 45 / 14%);
  --h-btn: 34px;
  --h-btn-sm: 28px;
}

* { box-sizing: border-box; }
html, body, #app { height: 100%; margin: 0; }
html { background: #d5d9de; }
body {
  font: 14px/1.6 var(--font);
  color: var(--text);
  background:
    var(--brush-light),
    linear-gradient(115deg, rgb(255 255 255 / 35%) 0%, transparent 35%, rgb(255 255 255 / 22%) 62%, transparent 85%),
    linear-gradient(180deg, #e8eaed 0%, #d3d7dc 100%);
  background-attachment: fixed;
  -webkit-font-smoothing: antialiased;
}
a { color: var(--accent); text-decoration: none; }
a:hover { color: var(--accent-hover); text-decoration: underline; }
button { font-family: inherit; cursor: pointer; }
:focus-visible { outline: 2px solid var(--focus); outline-offset: 2px; }

/* ---------- 圖示 ---------- */
.i {
  width: 16px; height: 16px; flex: none; vertical-align: -3px;
  fill: none; stroke: currentColor; stroke-width: 1.75; stroke-linecap: round; stroke-linejoin: round;
}

/* ---------- 版面 ---------- */
.layout { display: grid; grid-template-columns: 236px 1fr; min-height: 100vh; }
.sidebar {
  color: var(--side-text);
  background:
    repeating-linear-gradient(90deg, rgb(255 255 255 / 3%) 0 1px, rgb(0 0 0 / 7%) 1px 2px, transparent 2px 3px),
    linear-gradient(100deg, rgb(255 255 255 / 6%) 0%, transparent 40%, rgb(255 255 255 / 4%) 70%, transparent 100%),
    linear-gradient(180deg, #45484e 0%, #2c2e33 100%);
  border-right: 1px solid #1c1e21;
  box-shadow: inset -1px 0 0 rgb(255 255 255 / 8%), 4px 0 16px rgb(0 0 0 / 22%);
  display: flex; flex-direction: column;
  position: sticky; top: 0; height: 100vh; overflow-y: auto;
}
.brand {
  padding: 18px 18px 14px; background: var(--brand-metal); border-bottom: 1px solid var(--brand-edge);
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 45%), 0 2px 6px rgb(0 0 0 / 40%);
}
.brand-row { display: flex; align-items: center; gap: 10px; }
.brand-mark { display: grid; place-items: center; width: 34px; height: 34px; color: #fff; filter: drop-shadow(0 1px 1px rgb(0 0 0 / 45%)); }
.brand-mark .i { width: 30px; height: 30px; stroke-width: 1.6; }
.brand-sep { width: 1px; height: 26px; background: rgb(255 255 255 / 40%); }
.brand-name { font-weight: 700; font-size: 15px; line-height: 1.25; color: #fff; text-shadow: 0 1px 1px rgb(0 0 0 / 35%); }
.brand-name small { display: block; font-weight: 400; font-size: 10.5px; color: #dff3ec; letter-spacing: .3px; }
.brand-product {
  margin-top: 12px; font-size: 10.5px; letter-spacing: 2.4px; color: #fff; font-weight: 700; text-shadow: 0 1px 1px rgb(0 0 0 / 35%);
  display: flex; align-items: center; gap: 7px;
}
.brand-product::before { content: ""; width: 7px; height: 7px; border-radius: 50%; background: var(--lamp); box-shadow: 0 0 6px var(--lamp); }

.nav { padding: 4px 12px 16px; }
.nav-group { margin-top: 18px; }
.nav-title { padding: 0 4px 7px; font-weight: 800; font-size: 13px; letter-spacing: 1px; color: #f1f3f5; text-shadow: 0 1px 0 #000; }
/* 選單項目：金屬按鍵；目前頁面為墨綠金屬、白字 */
.nav a {
  position: relative; display: flex; align-items: center; gap: 10px;
  height: 38px; padding: 0 12px; margin: 0 0 8px; border-radius: var(--radius-sm);
  border: 1px solid #1d1f23; background: var(--metal-key); color: #1d2228;
  font-size: 14.5px; font-weight: 800; text-shadow: 0 1px 0 #fff;
  box-shadow: inset 0 1px 0 #fff, 0 1px 3px rgb(0 0 0 / 50%);
}
.nav a:hover { background: var(--metal-key-hover); color: #000; text-decoration: none; }
.nav a:active { background: var(--metal-key-down); box-shadow: inset 0 1px 3px rgb(0 0 0 / 30%); }
.nav a.active {
  background: var(--brand-metal-lit); border-color: var(--brand-edge); color: #fff; text-shadow: 0 -1px 0 rgb(0 0 0 / 45%);
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 55%), 0 0 10px var(--brand-glow), 0 1px 3px rgb(0 0 0 / 50%);
}
.nav a .i { width: 17px; height: 17px; color: #3a4048; }
.nav a:hover .i { color: #000; }
.nav a.active .i { color: #fff; }

/* 側欄：目前帳本 */
.household-nav { padding: 12px 12px 14px; border-bottom: 1px solid var(--side-line); box-shadow: 0 1px 0 rgb(0 0 0 / 30%); }
.household-current {
  display: flex; align-items: center; gap: 8px; height: 36px; padding: 0 12px; border-radius: var(--radius-sm);
  background: rgb(0 0 0 / 25%); border: 1px solid rgb(0 0 0 / 45%); box-shadow: inset 0 1px 3px rgb(0 0 0 / 40%), 0 1px 0 rgb(255 255 255 / 8%);
  color: #fff; font-weight: 800; font-size: 14px;
}
.household-current span { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.household-current .i { color: #8fe0c4; }

.side-foot {
  margin-top: auto; padding: 14px 20px 16px; font-size: 12px; color: var(--side-muted);
  border-top: 1px solid var(--side-line); box-shadow: inset 0 1px 0 rgb(0 0 0 / 30%);
  display: flex; flex-direction: column; gap: 3px;
}
.side-foot .clock { display: flex; align-items: center; gap: 6px; font-size: 12.5px; color: #fff; white-space: nowrap; }
.side-foot .clock .tz { color: #c3c8ce; }
.side-foot .clock time { font-weight: 700; font-variant-numeric: tabular-nums; }

.main { min-width: 0; display: flex; flex-direction: column; }
.topbar {
  height: 60px; background: var(--brush-light), linear-gradient(180deg, #f3f4f6 0%, #dde0e4 100%);
  border-bottom: 1px solid #a9b0b8; box-shadow: inset 0 1px 0 #fff, 0 1px 3px rgb(0 0 0 / 12%);
  display: flex; align-items: center; padding: 0 26px; gap: 12px;
  position: sticky; top: 0; z-index: 5;
}
.topbar h1 { margin: 0; font-size: 17px; font-weight: 700; letter-spacing: .3px; text-shadow: 0 1px 0 #fff; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.topbar .who { margin-left: auto; font-size: 13px; color: var(--muted); white-space: nowrap; }
.topbar .who b { color: var(--text); }
.content { padding: 24px 26px 32px; display: flex; flex-direction: column; gap: 18px; }

/* ---------- 面板：金屬板 ---------- */
.panel {
  position: relative; background: var(--brush-light), var(--metal-plate);
  border: 1px solid var(--line); border-radius: var(--radius); box-shadow: var(--bevel), var(--shadow);
}
.panel-head {
  display: flex; align-items: center; gap: 10px; flex-wrap: wrap; min-height: 52px;
  padding: 10px 20px; border-bottom: 1px solid var(--line-soft);
  background: linear-gradient(180deg, rgb(255 255 255 / 55%), rgb(255 255 255 / 0%));
  box-shadow: 0 1px 0 rgb(255 255 255 / 80%);
  border-radius: var(--radius) var(--radius) 0 0;
}
.panel-head h2 { margin: 0; font-size: 15px; font-weight: 700; display: flex; align-items: center; gap: 9px; text-shadow: 0 1px 0 #fff; }
.panel-head h2 .i { color: var(--text-2); width: 18px; height: 18px; vertical-align: 0; }
.panel-head .spacer { flex: 1; }
.panel-body { padding: 20px; }
.hint { color: var(--muted); font-size: 12.5px; font-weight: 400; }
.empty { padding: 34px 18px; text-align: center; color: var(--muted); }
.row { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }

/* ---------- 標籤 ---------- */
.pill {
  display: inline-flex; align-items: center; gap: 5px; padding: 1px 10px; border-radius: 999px;
  font-size: 12px; line-height: 1.6; border: 1px solid var(--field-line); background: var(--metal-key); color: var(--text-2);
  box-shadow: inset 0 1px 0 #fff; white-space: nowrap;
}
.pill.ok { border-color: var(--ok-line); background: var(--ok-soft); color: var(--ok); box-shadow: none; }
.pill.warn { border-color: var(--warn-line); background: var(--warn-soft); color: var(--warn); box-shadow: none; }
.pill.bad { border-color: var(--bad-line); background: var(--bad-soft); color: var(--bad); box-shadow: none; }
.household-badge {
  display: inline-flex; align-items: center; gap: 6px; height: 26px; padding: 0 11px; border-radius: var(--radius-sm);
  background: var(--brand-metal); border: 1px solid var(--brand-edge); color: #fff; font-size: 13px; font-weight: 700;
  text-shadow: 0 -1px 0 rgb(0 0 0 / 35%); box-shadow: inset 0 1px 0 rgb(255 255 255 / 45%), 0 1px 2px rgb(0 0 0 / 25%); white-space: nowrap;
}
.household-badge .i { width: 14px; height: 14px; }

/* ---------- 表格 ---------- */
.table-wrap { overflow-x: auto; }
table.grid { width: 100%; border-collapse: collapse; }
.grid th {
  text-align: left; font-weight: 700; font-size: 12.5px; color: var(--text-2); padding: 10px 16px; white-space: nowrap;
  background: var(--metal-key); border-bottom: 1px solid var(--line); box-shadow: inset 0 1px 0 #fff; text-shadow: 0 1px 0 #fff;
}
.grid td { padding: 10px 16px; border-bottom: 1px solid var(--line-soft); vertical-align: top; }
.grid tr:last-child td { border-bottom: 0; }
.grid tbody tr:hover td { background: rgb(255 255 255 / 45%); }
.grid td.num, .grid th.num { text-align: right; font-variant-numeric: tabular-nums; }
.grid .nowrap { white-space: nowrap; }

/* ---------- 表單：內凹的金屬輸入框 ---------- */
input[type=text], input[type=password], input[type=email], input[type=number], input[type=date], input[type=search], select, textarea {
  font: inherit; font-size: 14px; color: var(--text); border: 1px solid var(--field-line);
  background: linear-gradient(180deg, #e6e9ec 0%, #f6f7f8 30%, #fbfbfc 100%);
  box-shadow: inset 0 1px 3px rgb(0 0 0 / 20%), 0 1px 0 rgb(255 255 255 / 80%);
  border-radius: var(--radius-sm); padding: 0 11px; min-height: var(--h-btn);
  transition: border-color .15s, box-shadow .15s;
}
input::placeholder, textarea::placeholder { color: #7d8590; }
input[type=date] { font-weight: 700; color: #0f141a; font-variant-numeric: tabular-nums; }
input[type=date]::-webkit-calendar-picker-indicator { opacity: .85; cursor: pointer; }
textarea { min-height: 64px; padding: 7px 11px; resize: vertical; }
input:focus, select:focus, textarea:focus {
  outline: none; border-color: var(--focus);
  box-shadow: inset 0 1px 3px rgb(0 0 0 / 18%), 0 0 0 3px rgb(47 143 115 / 22%);
}
input:disabled, select:disabled, textarea:disabled { background: #dfe2e6; color: var(--muted); }
input[type=checkbox], input[type=radio] { width: 15px; height: 15px; margin: 0; accent-color: var(--brand); }
input[type=file] { font: inherit; font-size: 13px; color: var(--text-2); }
input[type=file]::file-selector-button {
  font: inherit; font-size: 13px; font-weight: 600; height: var(--h-btn-sm); padding: 0 11px; margin-right: 10px; cursor: pointer;
  border: 1px solid #959ca6; border-radius: var(--radius-sm); background: var(--metal-key); color: #22272e; text-shadow: 0 1px 0 #fff;
  box-shadow: inset 0 1px 0 #fff, 0 1px 2px rgb(0 0 0 / 22%);
}
input[type=file]::file-selector-button:hover { background: var(--metal-key-hover); }

/* ---------- 按鈕：金屬按鍵 ---------- */
.btn {
  font: inherit; font-size: 13px; font-weight: 600; cursor: pointer;
  display: inline-flex; align-items: center; justify-content: center; gap: 6px;
  height: var(--h-btn); padding: 0 15px; border-radius: var(--radius-sm); border: 1px solid #959ca6;
  background: var(--metal-key); color: #22272e; text-decoration: none; white-space: nowrap; text-shadow: 0 1px 0 #fff;
  box-shadow: inset 0 1px 0 #fff, 0 1px 2px rgb(0 0 0 / 22%);
}
.btn:hover { background: var(--metal-key-hover); color: #111; text-decoration: none; }
.btn:active, .btn.on { background: var(--metal-key-down); box-shadow: inset 0 1px 3px rgb(0 0 0 / 25%); }
.btn.on { border-color: #6f7781; color: #000; }
.btn.primary {
  background: var(--metal-dark); border-color: #2c2f34; color: #fff; text-shadow: 0 -1px 0 rgb(0 0 0 / 50%);
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 28%), 0 1px 3px rgb(0 0 0 / 35%);
}
.btn.primary:hover { background: var(--metal-dark-hover); color: #fff; }
.btn.primary:active { background: linear-gradient(180deg, #44484e, #575b61); box-shadow: inset 0 2px 4px rgb(0 0 0 / 45%); }
.btn.danger { color: var(--bad); }
.btn.ghost { border-color: transparent; background: transparent; box-shadow: none; color: var(--muted); }
.btn.ghost:hover { border-color: #959ca6; background: var(--metal-key-hover); box-shadow: inset 0 1px 0 #fff, 0 1px 2px rgb(0 0 0 / 18%); color: var(--text); }
.btn.sm { height: var(--h-btn-sm); padding: 0 11px; font-size: 12.5px; }
.btn.sm .i { width: 14px; height: 14px; }
.btn:disabled, .btn:disabled:hover { opacity: .5; cursor: not-allowed; }

/* ---------- 選擇按鍵：金屬鍵 + 底部 LED 燈條（未選取為內凹灰條、選取後亮綠發光） ---------- */
.keypad { display: flex; flex-wrap: wrap; gap: 12px; padding: 3px 2px 6px; }
.key {
  position: relative; display: inline-flex; align-items: center; gap: 8px; height: 40px; padding: 0 16px 7px;
  border: 1px solid #8e96a0; border-radius: 8px; background: var(--card-2tone); color: #3a4048;
  font: inherit; font-weight: 700; font-size: 14px; text-shadow: 0 1px 0 #fff; cursor: pointer; user-select: none;
  box-shadow: inset 0 1px 0 #fff, 0 0 0 2px rgb(255 255 255 / 55%), 0 2px 4px rgb(0 0 0 / 22%);
  transition: box-shadow .15s, background .15s, color .15s, transform .08s;
}
.key:hover { background: var(--card-2tone-hover); }
.key:active { transform: translateY(1px); }
.key .i { width: 18px; height: 18px; stroke-width: 2; }
.key::after {
  content: ""; position: absolute; left: 12px; right: 12px; bottom: 4px; height: 4px; border-radius: 3px;
  background: #b4bac2; box-shadow: inset 0 1px 1px rgb(0 0 0 / 30%), 0 1px 0 rgb(255 255 255 / 70%);
  transition: background .15s, box-shadow .15s;
}
.key.active {
  background: var(--card-2tone-lit); color: #15191e; border-color: #6f7781;
  box-shadow: inset 0 1px 0 #fff, 0 0 0 2px #fff, 0 0 12px 3px rgb(255 255 255 / 95%), 0 2px 5px rgb(0 0 0 / 25%);
}
.key.active::after { background: #22c55e; box-shadow: 0 0 6px 1px rgb(34 197 94 / 90%), inset 0 1px 0 rgb(255 255 255 / 55%); }

/* ---------- 查詢表單：欄位格線（標籤在上） ---------- */
.form-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 16px 20px; }
.form-field { display: flex; flex-direction: column; gap: 7px; min-width: 0; }
.form-field.wide { grid-column: 1 / -1; }
.form-field.span2 { grid-column: span 2; }
.form-field > label, .form-field > .label { font-size: 13px; font-weight: 700; color: var(--text-2); text-shadow: 0 1px 0 rgb(255 255 255 / 70%); }
.form-field input, .form-field select { width: 100%; }
.form-field input[type=date] { font-size: 15px; min-height: 38px; }
.form-field .hint { font-weight: 400; }

/* ---------- 統計卡片（報表摘要） ---------- */
.stat-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(170px, 1fr)); gap: 12px; }
.stat {
  padding: 10px 14px 12px; border-radius: 8px; border: 1px solid #a9b0b8;
  background: var(--brush-light), linear-gradient(180deg, #ffffff 0%, #eef0f3 55%, #e2e5e9 100%);
  box-shadow: inset 0 1px 0 #fff, 0 1px 3px rgb(0 0 0 / 18%);
}
.stat-label { font-size: 12.5px; color: var(--muted); }
.stat-value { font-size: 22px; font-weight: 800; line-height: 1.3; font-variant-numeric: tabular-nums; white-space: nowrap; }
.stat-value.income { color: var(--ok); }
.stat-value.expense { color: var(--bad); }

/* ---------- 實心標籤（類型） ---------- */
.badge {
  display: inline-flex; align-items: center; gap: 4px; padding: 1px 10px; border-radius: var(--radius-sm);
  font-size: 12.5px; line-height: 1.6; font-weight: 700; color: #fff; white-space: nowrap;
  border: 1px solid rgb(0 0 0 / 18%); text-shadow: 0 1px 0 rgb(0 0 0 / 25%); box-shadow: inset 0 1px 0 rgb(255 255 255 / 25%);
}
.badge.income { background: linear-gradient(180deg, #2fae68 0%, #1f8a4c 100%); }
.badge.expense { background: linear-gradient(180deg, #d9532f 0%, #b8391a 100%); }
.chip {
  display: inline-block; padding: 0 8px; margin: 1px 4px 1px 0; border-radius: 999px; font-size: 12px; line-height: 1.7;
  background: #fef3c7; color: #8a4b00; border: 1px solid #f1d58a; white-space: nowrap;
}
.amount { font-weight: 800; font-variant-numeric: tabular-nums; white-space: nowrap; }
.amount.income { color: var(--ok); }
.amount.expense { color: var(--bad); }

/* ---------- 表格：工具列、排序表頭 ---------- */
.toolbar { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; padding: 12px 16px; border-bottom: 1px solid var(--line-soft); }
.toolbar .spacer { flex: 1; }
.toolbar input[type=search] { width: 260px; }
.grid th.sortable { cursor: pointer; user-select: none; color: var(--accent); }
.grid th.sortable:hover { color: var(--accent-hover); }
.grid tbody tr:nth-child(even) td { background: rgb(255 255 255 / 28%); }
.grid td.actions { white-space: nowrap; text-align: right; }
.grid td.actions .btn + .btn { margin-left: 6px; }

/* ---------- 對話框（原生 <dialog>） ---------- */
dialog.modal {
  width: min(640px, calc(100vw - 32px)); max-height: calc(100vh - 48px); padding: 0; overflow: auto;
  border: 1px solid var(--line); border-radius: var(--radius); color: var(--text);
  background: var(--brush-light), var(--metal-plate); box-shadow: var(--bevel), 0 24px 60px rgb(20 25 35 / 40%);
}
dialog.modal::backdrop { background: rgb(20 24 30 / 45%); backdrop-filter: blur(1px); }
dialog.modal .panel-head { position: sticky; top: 0; z-index: 1; background: linear-gradient(180deg, #fbfbfc, #eceef1); }
.modal-foot { display: flex; justify-content: flex-end; gap: 10px; padding: 14px 20px; border-top: 1px solid var(--line-soft); }

/* ---------- 訊息 ---------- */
.flash { border-radius: var(--radius); padding: 10px 16px; border: 1px solid var(--ok-line); background: var(--ok-soft); color: #14532d; box-shadow: var(--bevel); }
.flash.error { border-color: var(--bad-line); background: var(--bad-soft); color: #8e1c1c; }
.notice { border: 1px dashed var(--field-line); background: rgb(255 255 255 / 55%); border-radius: var(--radius); padding: 12px 16px; }
[hidden] { display: none !important; }

/* ---------- 窄螢幕：只做最基本的上下堆疊（完整手機版另案處理） ---------- */
@media (max-width: 860px) {
  .layout { grid-template-columns: 1fr; }
  .sidebar { position: static; height: auto; }
  .topbar { position: static; padding: 0 14px; }
  .content { padding: 14px; }
  .topbar .who { display: none; }
}
@media (prefers-reduced-motion: reduce) {
  .key, input, select, textarea { transition: none; }
}
__F58_EOF__

cat > "$FE/src/components/AccountList.vue" << '__F58_EOF__'
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import AppIcon from './AppIcon.vue'
import { fetchAccounts, createAccount, updateAccount, deleteAccount } from '@/api/ledgerApi'
import { ACCOUNT_TYPE_LABEL, formatCurrency } from '@/utils/ledgerLabels'
import type { AccountOut, AccountType } from '@/types/ledger'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const emit = defineEmits<{ changed: [] }>()

const accounts = ref<AccountOut[]>([])
const isLoading = ref(true)
const loadError = ref('')

const showForm = ref(false)
const name = ref('')
const type = ref<AccountType>('cash')
const balance = ref(0)
const isDefaultExpense = ref(false)
const formError = ref('')
const isSubmitting = ref(false)

const totalBalance = computed(() => accounts.value.reduce((sum, a) => sum + a.balance, 0))

function toggleForm() {
  showForm.value = !showForm.value
  formError.value = ''
}

// 編輯既有帳戶餘額
const editingId = ref<string | null>(null)
const editBalance = ref(0)
const editError = ref('')
const isSavingEdit = ref(false)

async function load() {
  isLoading.value = true
  try {
    accounts.value = await fetchAccounts()
  } catch {
    loadError.value = '載入帳戶失敗'
  } finally {
    isLoading.value = false
  }
}

onMounted(load)

async function handleCreate() {
  formError.value = ''
  if (!Number.isFinite(balance.value)) {
    formError.value = '請輸入起始餘額(可為 0 或負數)'
    return
  }
  if (!name.value.trim()) {
    formError.value = '請輸入帳戶名稱'
    return
  }
  isSubmitting.value = true
  try {
    await createAccount({
      name: name.value.trim(),
      type: type.value,
      balance: balance.value,
      is_default_expense: isDefaultExpense.value,
    })
    name.value = ''
    balance.value = 0
    isDefaultExpense.value = false
    showForm.value = false
    await load()
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    formError.value = axiosErr.response?.data?.detail ?? '新增失敗'
  } finally {
    isSubmitting.value = false
  }
}

async function handleDelete(id: string) {
  if (!confirm('確定刪除此帳戶？此操作無法復原。')) return
  try {
    await deleteAccount(id)
    await load()
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    alert(axiosErr.response?.data?.detail ?? '刪除失敗')
  }
}

function startEdit(account: AccountOut) {
  editingId.value = account.id
  editBalance.value = account.balance
  editError.value = ''
}

function cancelEdit() {
  editingId.value = null
  editError.value = ''
}

async function saveEdit(id: string) {
  editError.value = ''
  if (!Number.isFinite(editBalance.value)) {
    editError.value = '請輸入餘額'
    return
  }
  isSavingEdit.value = true
  try {
    await updateAccount(id, { balance: editBalance.value })
    editingId.value = null
    await load()
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    editError.value = axiosErr.response?.data?.detail ?? '更新失敗'
  } finally {
    isSavingEdit.value = false
  }
}

async function setDefaultExpense(id: string) {
  try {
    await updateAccount(id, { is_default_expense: true })
    await load()
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    alert(axiosErr.response?.data?.detail ?? '設定失敗')
  }
}
</script>

<template>
  <section class="panel">
    <div class="panel-head">
      <h2><AppIcon name="wallet" />帳戶</h2>
      <span v-if="!isLoading" class="pill">{{ accounts.length }} 個</span>
      <span class="spacer"></span>
      <button type="button" class="btn primary" :class="{ on: showForm }" @click="toggleForm">
        <AppIcon :name="showForm ? 'x' : 'plus'" />{{ showForm ? '取消新增' : '新增帳戶' }}
      </button>
    </div>

    <div v-if="loadError" class="panel-body">
      <div class="error-banner">{{ loadError }}</div>
    </div>

    <form v-if="showForm" class="panel-body add-form" @submit.prevent="handleCreate">
      <div v-if="formError" class="error-banner" role="alert">{{ formError }}</div>
      <div class="form-grid">
        <div class="form-field">
          <label for="acc-name">帳戶名稱</label>
          <input id="acc-name" v-model="name" type="text" required maxlength="100" />
        </div>
        <div class="form-field">
          <label for="acc-type">類型</label>
          <select id="acc-type" v-model="type">
            <option value="cash">現金</option>
            <option value="bank">銀行</option>
            <option value="credit_card">信用卡</option>
          </select>
        </div>
        <div class="form-field">
          <label for="acc-balance">起始餘額</label>
          <input id="acc-balance" v-model.number="balance" type="number" step="1" />
        </div>
        <div class="form-field">
          <span class="label">預設支出帳戶</span>
          <label class="check"><input v-model="isDefaultExpense" type="checkbox" />新增交易時預設選取此帳戶</label>
        </div>
      </div>
      <div class="row form-actions">
        <button class="btn primary" type="submit" :disabled="isSubmitting">
          {{ isSubmitting ? '新增中…' : '確認新增' }}
        </button>
        <button class="btn" type="button" @click="toggleForm">取消</button>
      </div>
    </form>

    <div v-if="accounts.length" class="table-wrap">
      <table class="grid">
        <thead>
          <tr>
            <th>帳戶名稱</th>
            <th>類型</th>
            <th class="num">餘額</th>
            <th class="num">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="account in accounts" :key="account.id">
            <td>
              <b>{{ account.name }}</b>
              <span v-if="account.is_default_expense" class="pill ok default-pill">預設支出帳戶</span>
            </td>
            <td class="nowrap">{{ ACCOUNT_TYPE_LABEL[account.type] }}</td>
            <td class="num">
              <form v-if="editingId === account.id" class="edit-balance" @submit.prevent="saveEdit(account.id)">
                <input v-model.number="editBalance" type="number" step="1" aria-label="新餘額" />
                <button class="btn primary sm" type="submit" :disabled="isSavingEdit">
                  {{ isSavingEdit ? '儲存中…' : '儲存' }}
                </button>
                <button class="btn sm" type="button" @click="cancelEdit">取消</button>
                <div v-if="editError" class="field-error">{{ editError }}</div>
              </form>
              <span v-else class="amount" :class="{ expense: account.balance < 0 }">{{ formatCurrency(account.balance) }}</span>
            </td>
            <td class="actions">
              <template v-if="editingId !== account.id">
                <button v-if="!account.is_default_expense" type="button" class="btn sm" @click="setDefaultExpense(account.id)">
                  設為預設
                </button>
                <button type="button" class="btn sm" @click="startEdit(account)"><AppIcon name="edit" />調整餘額</button>
                <button type="button" class="btn danger sm" @click="handleDelete(account.id)"><AppIcon name="trash" />刪除</button>
              </template>
            </td>
          </tr>
        </tbody>
        <tfoot>
          <tr>
            <td colspan="2"><b>合計</b></td>
            <td class="num">
              <span class="amount" :class="{ expense: totalBalance < 0 }">{{ formatCurrency(totalBalance) }}</span>
            </td>
            <td></td>
          </tr>
        </tfoot>
      </table>
    </div>
    <p v-else-if="!isLoading && !loadError" class="empty">尚未建立任何帳戶。</p>
  </section>
</template>

<style scoped>
.add-form { border-bottom: 1px solid var(--line-soft); }
.form-actions { margin-top: 16px; }
.check { display: inline-flex; align-items: center; gap: 8px; min-height: var(--h-btn); cursor: pointer; }
.check input[type=checkbox] { width: 15px; flex: none; }
.default-pill { margin-left: 8px; }
.edit-balance { display: inline-flex; align-items: center; gap: 6px; flex-wrap: wrap; justify-content: flex-end; }
.edit-balance input { width: 140px; text-align: right; }
.field-error { flex-basis: 100%; color: var(--bad); font-size: 12px; text-align: right; }
tfoot td { border-top: 1px solid var(--line); background: rgb(255 255 255 / 40%); }
</style>
__F58_EOF__

cat > "$FE/src/components/CategoryList.vue" << '__F58_EOF__'
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import CategoryPicker from './CategoryPicker.vue'
import CategoryTreeNode from './CategoryTreeNode.vue'
import AppIcon from './AppIcon.vue'
import { fetchCategories, updateCategory, deleteCategory } from '@/api/ledgerApi'
import type { CategoryOut, EntryType } from '@/types/ledger'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const emit = defineEmits<{ changed: [] }>()

const categories = ref<CategoryOut[]>([])
const isLoading = ref(true)
const loadError = ref('')

const activeType = ref<EntryType>('expense')
// CategoryPicker 需要 v-model,但此頁純粹用來瀏覽/建立結構,不需要真正「選定」某個分類
const browsingSelection = ref('')

const treeSearchQuery = ref('')
const isTreeSearching = computed(() => treeSearchQuery.value.trim().length > 0)

const editingId = ref<string | null>(null)
const editName = ref('')
const editError = ref('')

async function load() {
  isLoading.value = true
  try {
    categories.value = await fetchCategories()
  } catch {
    loadError.value = '載入分類失敗'
  } finally {
    isLoading.value = false
  }
}

onMounted(load)

function handleCategoryCreated(category: CategoryOut) {
  categories.value.push(category)
  emit('changed')
}

const rootCategories = computed(() =>
  categories.value.filter((c) => c.type === activeType.value && c.parent_id === null)
)

function ancestorChain(category: CategoryOut): CategoryOut[] {
  const chain: CategoryOut[] = []
  let node: CategoryOut | undefined = category
  while (node) {
    chain.unshift(node)
    node = node.parent_id ? categories.value.find((c) => c.id === node!.parent_id) : undefined
  }
  return chain
}
function fullPathLabel(category: CategoryOut): string {
  return ancestorChain(category).map((c) => c.name).join(' › ')
}

const typeCount = computed(() => categories.value.filter((c) => c.type === activeType.value).length)

const searchResults = computed(() => {
  const q = treeSearchQuery.value.trim().toLowerCase()
  if (!q) return []
  return categories.value
    .filter((c) => c.type === activeType.value && c.name.toLowerCase().includes(q))
    .map((c) => ({ category: c, label: fullPathLabel(c) }))
    .sort((a, b) => a.label.localeCompare(b.label))
    .slice(0, 50)
})

async function handleDelete(id: string) {
  if (!confirm('確定刪除此分類？')) return
  try {
    await deleteCategory(id)
    await load()
    editingId.value = null
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    alert(axiosErr.response?.data?.detail ?? '刪除失敗(可能仍有子分類或交易紀錄使用中)')
  }
}

async function handleRename(id: string, name: string): Promise<boolean> {
  try {
    const updated = await updateCategory(id, { name })
    const idx = categories.value.findIndex((c) => c.id === id)
    if (idx !== -1) categories.value[idx] = updated
    emit('changed')
    return true
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    alert(axiosErr.response?.data?.detail ?? '改名失敗')
    return false
  }
}

function startEdit(category: CategoryOut) {
  editingId.value = category.id
  editName.value = category.name
  editError.value = ''
}
function cancelEdit() {
  editingId.value = null
  editError.value = ''
}
async function saveSearchEdit(id: string) {
  editError.value = ''
  const trimmed = editName.value.trim()
  if (!trimmed) {
    editError.value = '請輸入分類名稱'
    return
  }
  const target = categories.value.find((c) => c.id === id)
  const isDuplicate = categories.value.some(
    (c) => c.id !== id && c.parent_id === target?.parent_id && c.name.trim().toLowerCase() === trimmed.toLowerCase()
  )
  if (isDuplicate) {
    editError.value = '此層級已有同名分類'
    return
  }
  const ok = await handleRename(id, trimmed)
  if (ok) editingId.value = null
}
</script>

<template>
  <section class="panel">
    <div class="panel-head">
      <h2><AppIcon name="folder" />建立分類</h2>
      <span class="spacer"></span>
      <div class="keypad" role="radiogroup" aria-label="收支類型">
        <button
          type="button"
          role="radio"
          class="key"
          :class="{ active: activeType === 'expense' }"
          :aria-checked="activeType === 'expense'"
          @click="activeType = 'expense'"
        >
          <AppIcon name="expense" class="ic-expense" />支出
        </button>
        <button
          type="button"
          role="radio"
          class="key"
          :class="{ active: activeType === 'income' }"
          :aria-checked="activeType === 'income'"
          @click="activeType = 'income'"
        >
          <AppIcon name="income" class="ic-income" />收入
        </button>
      </div>
    </div>
    <div class="panel-body">
      <div v-if="loadError" class="error-banner">{{ loadError }}</div>
      <p class="hint intro">逐層點選進入下一層,在要放的層級按「+ 新增分類」。</p>
      <CategoryPicker
        v-model="browsingSelection"
        :type="activeType"
        :categories="categories"
        :hide-selected-hint="true"
        @created="handleCategoryCreated"
      />
    </div>
  </section>

  <section class="panel">
    <div class="panel-head">
      <h2><AppIcon name="table" />全部分類</h2>
      <span class="pill">{{ activeType === 'expense' ? '支出' : '收入' }}・{{ typeCount }} 個</span>
    </div>
    <div class="toolbar">
      <input v-model="treeSearchQuery" type="search" placeholder="搜尋分類(不限層級,例如:晚餐)" aria-label="搜尋分類" />
    </div>

    <template v-if="isTreeSearching">
      <div v-if="searchResults.length" class="table-wrap">
        <table class="grid">
          <thead>
            <tr>
              <th>分類路徑</th>
              <th class="num">操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="r in searchResults" :key="r.category.id">
              <td>
                <form v-if="editingId === r.category.id" class="row rename" @submit.prevent="saveSearchEdit(r.category.id)">
                  <input v-model="editName" type="text" maxlength="100" aria-label="新名稱" />
                  <button class="btn primary sm" type="submit">儲存</button>
                  <button type="button" class="btn sm" @click="cancelEdit">取消</button>
                  <span v-if="editError" class="field-error">{{ editError }}</span>
                </form>
                <span v-else>{{ r.label }}</span>
              </td>
              <td class="actions">
                <template v-if="editingId !== r.category.id">
                  <button type="button" class="btn sm" @click="startEdit(r.category)"><AppIcon name="edit" />改名</button>
                  <button type="button" class="btn danger sm" @click="handleDelete(r.category.id)"><AppIcon name="trash" />刪除</button>
                </template>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <p v-else class="empty">找不到符合「{{ treeSearchQuery }}」的分類。</p>
    </template>

    <template v-else>
      <div v-if="rootCategories.length" class="tree">
        <CategoryTreeNode
          v-for="root in rootCategories"
          :key="root.id"
          :category="root"
          :categories="categories"
          :depth="0"
          @delete="handleDelete"
          @rename="handleRename"
        />
      </div>
      <p v-else-if="!isLoading" class="empty">此類型尚未建立任何分類。</p>
    </template>
  </section>
</template>

<style scoped>
.panel-head .keypad { padding: 0; }
.ic-expense { color: #b8391a; }
.ic-income { color: #1f8a4c; }
.intro { margin: 0 0 10px; }
.rename { flex-wrap: nowrap; }
.rename input { flex: 1; min-width: 160px; }
.field-error { color: var(--bad); font-size: 12px; white-space: nowrap; }
.tree { padding: 4px 0 8px; }
</style>
__F58_EOF__

cat > "$FE/src/components/CategoryTreeNode.vue" << '__F58_EOF__'
<script setup lang="ts">
import { computed, ref } from 'vue'
import type { CategoryOut } from '@/types/ledger'
import AppIcon from './AppIcon.vue'
defineOptions({ name: 'CategoryTreeNode' }) // 遞迴自我參照元件需要明確命名
const props = defineProps<{
  category: CategoryOut
  categories: CategoryOut[]
  depth: number
}>()
const emit = defineEmits<{ delete: [id: string]; rename: [id: string, name: string] }>()
const isExpanded = ref(false)
const children = computed(() => props.categories.filter((c) => c.parent_id === props.category.id))
const hasChildren = computed(() => children.value.length > 0)

const isEditing = ref(false)
const editName = ref('')
const editError = ref('')

function startEdit() {
  editName.value = props.category.name
  editError.value = ''
  isEditing.value = true
}
function cancelEdit() {
  isEditing.value = false
  editError.value = ''
}
function saveEdit() {
  const trimmed = editName.value.trim()
  if (!trimmed) {
    editError.value = '請輸入分類名稱'
    return
  }
  // 同層級(同一個 parent_id)重複名稱阻擋,邏輯與 CategoryPicker 新增時一致
  const isDuplicate = props.categories.some(
    (c) =>
      c.id !== props.category.id &&
      c.parent_id === props.category.parent_id &&
      c.name.trim().toLowerCase() === trimmed.toLowerCase()
  )
  if (isDuplicate) {
    editError.value = '此層級已有同名分類'
    return
  }
  emit('rename', props.category.id, trimmed)
  isEditing.value = false
}

function handleDelete(id: string) {
  emit('delete', id)
}
function handleRename(id: string, name: string) {
  emit('rename', id, name)
}
</script>
<template>
  <div>
    <div class="node-row" :class="{ root: depth === 0 }" :style="{ paddingLeft: 16 + depth * 22 + 'px' }">
      <button
        v-if="hasChildren"
        type="button"
        class="expand-btn"
        :aria-expanded="isExpanded"
        :aria-label="isExpanded ? '收合' : '展開'"
        @click="isExpanded = !isExpanded"
      >
        {{ isExpanded ? '▾' : '▸' }}
      </button>
      <span v-else class="expand-spacer"></span>

      <template v-if="!isEditing">
        <span class="node-name">{{ category.name }}</span>
        <span v-if="hasChildren" class="pill child-count">{{ children.length }}</span>
        <div class="node-actions">
          <button type="button" class="btn sm" @click="startEdit"><AppIcon name="edit" />改名</button>
          <button type="button" class="btn danger sm" @click="handleDelete(category.id)"><AppIcon name="trash" />刪除</button>
        </div>
      </template>
      <template v-else>
        <input v-model="editName" type="text" maxlength="100" class="edit-input" aria-label="新名稱" @keyup.enter="saveEdit" />
        <div class="node-actions">
          <button type="button" class="btn primary sm" @click="saveEdit">儲存</button>
          <button type="button" class="btn sm" @click="cancelEdit">取消</button>
        </div>
      </template>
    </div>
    <div v-if="isEditing && editError" class="node-error" :style="{ paddingLeft: 16 + depth * 22 + 28 + 'px' }">
      {{ editError }}
    </div>
    <div v-if="hasChildren && isExpanded">
      <CategoryTreeNode
        v-for="child in children"
        :key="child.id"
        :category="child"
        :categories="categories"
        :depth="depth + 1"
        @delete="handleDelete"
        @rename="handleRename"
      />
    </div>
  </div>
</template>
<style scoped>
.node-row {
  display: flex;
  align-items: center;
  gap: 8px;
  min-height: 46px;
  padding-right: 16px;
  border-bottom: 1px solid var(--line-soft);
}
.node-row:hover { background: rgb(255 255 255 / 45%); }
.node-row.root .node-name { font-weight: 700; }
.expand-btn {
  width: 22px;
  height: 22px;
  padding: 0;
  font-size: 12px;
  line-height: 1;
  color: var(--text-2);
  border: 1px solid #a9b0b8;
  border-radius: 4px;
  background: var(--metal-key);
  box-shadow: inset 0 1px 0 #fff;
}
.expand-btn:hover { background: var(--metal-key-hover); }
.expand-spacer { display: inline-block; width: 22px; }
.node-name { font-size: 14px; }
.child-count { font-size: 11px; padding: 0 7px; }
.node-actions { margin-left: auto; display: flex; gap: 6px; }
.edit-input { flex: 1; max-width: 320px; }
.node-error { padding: 4px 0 8px; color: var(--bad); font-size: 12px; }
</style>
__F58_EOF__

cat > "$FE/src/components/TagList.vue" << '__F58_EOF__'
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { fetchTags, createTag, updateTag, deleteTag } from '@/api/ledgerApi'
import AppIcon from './AppIcon.vue'
import type { TagOut } from '@/types/ledger'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const RECENT_LIMIT = 12

const emit = defineEmits<{ changed: [] }>()

const tags = ref<TagOut[]>([])
const isLoading = ref(true)
const loadError = ref('')
const newTagName = ref('')
const createError = ref('')
const isCreating = ref(false)
const searchQuery = ref('')

const activeTagId = ref<string | null>(null)
const editingId = ref<string | null>(null)
const editName = ref('')
const editError = ref('')
const isSavingEdit = ref(false)

const isSearching = computed(() => searchQuery.value.trim().length > 0)

const filteredTags = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return tags.value
  return tags.value.filter((t) => t.name.toLowerCase().includes(q))
})

const recentTags = computed(() => {
  return tags.value
    .filter((t) => t.last_used_date)
    .sort((a, b) => (b.last_used_date! < a.last_used_date! ? -1 : 1))
    .slice(0, RECENT_LIMIT)
})

const otherTags = computed(() => {
  const recentIds = new Set(recentTags.value.map((t) => t.id))
  return tags.value.filter((t) => !recentIds.has(t.id))
})

const activeTag = computed(() => tags.value.find((t) => t.id === activeTagId.value) ?? null)

async function load() {
  isLoading.value = true
  loadError.value = ''
  try {
    tags.value = await fetchTags()
  } catch {
    loadError.value = '載入消費品項失敗'
  } finally {
    isLoading.value = false
  }
}

onMounted(load)

function isDuplicateName(name: string, excludeId?: string): boolean {
  const lower = name.trim().toLowerCase()
  return tags.value.some((t) => t.id !== excludeId && t.name.trim().toLowerCase() === lower)
}

function toggleActive(id: string) {
  if (activeTagId.value === id) {
    activeTagId.value = null
    editingId.value = null
    return
  }
  activeTagId.value = id
  editingId.value = null
  editError.value = ''
}

async function handleCreate() {
  createError.value = ''
  const trimmedName = newTagName.value.trim()
  if (!trimmedName) {
    createError.value = '請輸入名稱'
    return
  }
  if (isDuplicateName(trimmedName)) {
    createError.value = '此消費品項名稱已存在,請直接使用現有品項'
    return
  }
  isCreating.value = true
  try {
    const created = await createTag({ name: trimmedName })
    tags.value.push(created)
    newTagName.value = ''
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    createError.value = axiosErr.response?.data?.detail ?? '新增失敗'
  } finally {
    isCreating.value = false
  }
}

function startEdit(tag: TagOut) {
  editingId.value = tag.id
  editName.value = tag.name
  editError.value = ''
}

function cancelEdit() {
  editingId.value = null
  editError.value = ''
}

async function saveEdit(id: string) {
  editError.value = ''
  const trimmedName = editName.value.trim()
  if (!trimmedName) {
    editError.value = '請輸入名稱'
    return
  }
  if (isDuplicateName(trimmedName, id)) {
    editError.value = '此消費品項名稱已存在,請直接使用現有品項'
    return
  }
  isSavingEdit.value = true
  try {
    const updated = await updateTag(id, { name: trimmedName })
    const idx = tags.value.findIndex((t) => t.id === id)
    if (idx !== -1) tags.value[idx] = updated
    editingId.value = null
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    editError.value = axiosErr.response?.data?.detail ?? '更新失敗'
  } finally {
    isSavingEdit.value = false
  }
}

async function handleDelete(tag: TagOut) {
  const message =
    tag.usage_count > 0
      ? `此消費品項已掛用於 ${tag.usage_count} 筆交易,刪除後這些交易將移除此標籤,交易本身不受影響。確定刪除？`
      : '確定刪除此消費品項？'
  if (!confirm(message)) return
  try {
    await deleteTag(tag.id)
    tags.value = tags.value.filter((t) => t.id !== tag.id)
    activeTagId.value = null
    editingId.value = null
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    alert(axiosErr.response?.data?.detail ?? '刪除失敗')
  }
}
</script>

<template>
  <section class="panel">
    <div class="panel-head">
      <h2><AppIcon name="tag" />消費品項</h2>
      <span v-if="!isLoading" class="pill">{{ tags.length }} 個</span>
      <span class="spacer"></span>
      <form class="row create" @submit.prevent="handleCreate">
        <input v-model="newTagName" type="text" maxlength="50" placeholder="新增消費品項(例如:三媽)" aria-label="新消費品項名稱" />
        <button class="btn primary" type="submit" :disabled="isCreating">
          <AppIcon name="plus" />{{ isCreating ? '新增中…' : '新增' }}
        </button>
      </form>
    </div>

    <div v-if="createError || loadError" class="panel-body msgs">
      <div v-if="createError" class="error-banner" role="alert">{{ createError }}</div>
      <div v-if="loadError" class="error-banner">{{ loadError }}</div>
    </div>

    <div class="toolbar">
      <input v-model="searchQuery" type="search" placeholder="搜尋消費品項" aria-label="搜尋消費品項" />
      <span class="hint">點選品項可改名或刪除;數字為使用次數</span>
    </div>

    <div class="panel-body">
      <p v-if="!isLoading && tags.length === 0" class="empty">尚未建立任何消費品項。</p>
      <p v-else-if="isSearching && filteredTags.length === 0" class="empty">找不到符合「{{ searchQuery }}」的消費品項。</p>

      <template v-if="!isSearching">
        <template v-if="recentTags.length">
          <div class="section-label">最近使用</div>
          <div class="tag-grid">
            <button
              v-for="t in recentTags"
              :key="t.id"
              type="button"
              class="tag-key"
              :class="{ active: activeTagId === t.id, unused: t.usage_count === 0 }"
              :aria-pressed="activeTagId === t.id"
              @click="toggleActive(t.id)"
            >
              {{ t.name }}<span class="tag-count">{{ t.usage_count }}</span>
            </button>
          </div>
        </template>
        <template v-if="otherTags.length">
          <div v-if="recentTags.length" class="section-label">全部品項</div>
          <div class="tag-grid">
            <button
              v-for="t in otherTags"
              :key="t.id"
              type="button"
              class="tag-key"
              :class="{ active: activeTagId === t.id, unused: t.usage_count === 0 }"
              :aria-pressed="activeTagId === t.id"
              @click="toggleActive(t.id)"
            >
              {{ t.name }}<span class="tag-count">{{ t.usage_count }}</span>
            </button>
          </div>
        </template>
      </template>

      <div v-else class="tag-grid">
        <button
          v-for="t in filteredTags"
          :key="t.id"
          type="button"
          class="tag-key"
          :class="{ active: activeTagId === t.id, unused: t.usage_count === 0 }"
          :aria-pressed="activeTagId === t.id"
          @click="toggleActive(t.id)"
        >
          {{ t.name }}<span class="tag-count">{{ t.usage_count }}</span>
        </button>
      </div>
    </div>

    <div v-if="activeTag" class="detail">
      <form v-if="editingId === activeTag.id" class="row rename" @submit.prevent="saveEdit(activeTag.id)">
        <input v-model="editName" type="text" maxlength="50" aria-label="新名稱" />
        <button class="btn primary sm" type="submit" :disabled="isSavingEdit">
          {{ isSavingEdit ? '儲存中…' : '儲存' }}
        </button>
        <button type="button" class="btn sm" @click="cancelEdit">取消</button>
        <span v-if="editError" class="field-error">{{ editError }}</span>
      </form>
      <template v-else>
        <b>{{ activeTag.name }}</b>
        <span class="hint">
          使用 {{ activeTag.usage_count }} 次<template v-if="activeTag.last_used_date">,最後使用於 {{ activeTag.last_used_date }}</template>
        </span>
        <span class="spacer"></span>
        <button type="button" class="btn sm" @click="startEdit(activeTag)"><AppIcon name="edit" />改名</button>
        <button type="button" class="btn danger sm" @click="handleDelete(activeTag)"><AppIcon name="trash" />刪除</button>
        <button type="button" class="btn ghost sm" @click="activeTagId = null"><AppIcon name="x" />關閉</button>
      </template>
    </div>
  </section>
</template>

<style scoped>
.create { flex-wrap: nowrap; }
.create input { width: 260px; }
.msgs { padding-bottom: 0; }
.section-label { margin: 0 0 8px; font-size: 12px; font-weight: 700; color: var(--muted); }
.tag-grid + .section-label { margin-top: 18px; }
.tag-grid { display: flex; flex-wrap: wrap; gap: 8px; }
.tag-key {
  display: inline-flex; align-items: center; gap: 7px; height: 32px; padding: 0 12px;
  font: inherit; font-size: 13.5px; font-weight: 700; color: #22272e; text-shadow: 0 1px 0 #fff;
  border: 1px solid #959ca6; border-radius: 999px; background: var(--metal-key); cursor: pointer;
  box-shadow: inset 0 1px 0 #fff, 0 1px 2px rgb(0 0 0 / 18%);
}
.tag-key:hover { background: var(--metal-key-hover); }
.tag-key.unused { color: #7d8590; font-weight: 600; }
.tag-key.active {
  color: #fff; text-shadow: 0 -1px 0 rgb(0 0 0 / 35%); border-color: var(--brand-edge); background: var(--brand-metal-lit);
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 45%), 0 0 8px var(--brand-glow);
}
.tag-count {
  min-width: 20px; padding: 0 6px; border-radius: 999px; font-size: 11px; line-height: 18px; text-align: center;
  background: rgb(0 0 0 / 8%); font-variant-numeric: tabular-nums;
}
.tag-key.active .tag-count { background: rgb(255 255 255 / 25%); }
.detail {
  display: flex; align-items: center; gap: 10px; flex-wrap: wrap; padding: 12px 20px;
  border-top: 1px solid var(--line-soft); background: rgb(255 255 255 / 45%); border-radius: 0 0 var(--radius) var(--radius);
}
.detail .spacer { flex: 1; }
.rename { flex: 1; flex-wrap: nowrap; }
.rename input { flex: 1; max-width: 320px; }
.field-error { color: var(--bad); font-size: 12px; white-space: nowrap; }
</style>
__F58_EOF__

cat > "$FE/src/components/ExcelImportExport.vue" << '__F58_EOF__'
<template>
  <section class="panel">
    <div class="panel-head">
      <h2><AppIcon name="download" />匯出 Excel</h2>
    </div>
    <div class="panel-body">
      <div class="row">
        <label for="export-year" class="lbl">年份</label>
        <select id="export-year" v-model.number="exportYear">
          <option v-for="y in availableYears" :key="y" :value="y">{{ y }}</option>
        </select>
        <button type="button" class="btn primary" :disabled="exporting" @click="handleExport">
          <AppIcon name="download" />{{ exporting ? '匯出中…' : '下載 Excel' }}
        </button>
        <span class="hint">依年份輸出各月分頁,格式對齊舊版記帳 Excel</span>
      </div>
    </div>
  </section>

  <section class="panel">
    <div class="panel-head">
      <h2><AppIcon name="transfer" />匯入 Excel</h2>
      <span class="hint">先預覽,確認後才寫入</span>
    </div>
    <div class="panel-body">
      <div v-if="accountsError" class="error-banner">{{ accountsError }}</div>
      <div class="form-grid">
        <div class="form-field">
          <label for="import-account">目標帳戶</label>
          <select id="import-account" v-model="selectedAccountId">
            <option v-for="acc in accounts" :key="acc.id" :value="acc.id">
              {{ acc.name }}{{ acc.is_default_expense ? '(預設)' : '' }} - {{ ACCOUNT_TYPE_LABEL[acc.type] }}
            </option>
          </select>
        </div>
        <div class="form-field span2">
          <label for="import-file">Excel 檔案 <span class="hint">(.xlsx)</span></label>
          <div class="row nowrap">
            <input id="import-file" ref="fileInput" type="file" accept=".xlsx" class="file" @change="handleFileSelect" />
            <button
              v-if="selectedFile && !preview"
              type="button"
              class="btn primary"
              :disabled="!selectedAccountId || loading"
              @click="handlePreview"
            >
              {{ loading ? '解析中…' : '預覽' }}
            </button>
          </div>
        </div>
      </div>

      <div v-if="commitResult" class="flash result">
        已匯入 <b>{{ commitResult.imported }}</b> 筆,跳過重複 {{ commitResult.skipped_duplicates }} 筆,
        跳過錯誤 {{ commitResult.skipped_errors }} 筆,新建分類 {{ commitResult.created_categories }} 個
      </div>
    </div>

    <template v-if="preview">
      <div class="panel-body preview-summary">
        <div class="stat-grid">
          <div class="stat"><div class="stat-label">總筆數</div><div class="stat-value">{{ preview.total_rows }}</div></div>
          <div class="stat"><div class="stat-label">有效</div><div class="stat-value">{{ preview.valid_rows }}</div></div>
          <div class="stat"><div class="stat-label">重複</div><div class="stat-value">{{ duplicateCount }}</div></div>
          <div class="stat">
            <div class="stat-label">錯誤(不會匯入)</div>
            <div class="stat-value" :class="{ expense: preview.errors.length > 0 }">{{ preview.errors.length }}</div>
          </div>
          <div class="stat"><div class="stat-label">將匯入</div><div class="stat-value income">{{ finalImportCount }}</div></div>
        </div>

        <details v-if="preview.new_categories.length" class="detail-box">
          <summary>將新建 {{ preview.new_categories.length }} 個分類</summary>
          <ul><li v-for="c in preview.new_categories" :key="c">{{ c }}</li></ul>
        </details>
        <details v-if="preview.errors.length" open class="detail-box errors">
          <summary>{{ preview.errors.length }} 筆錯誤(不會匯入)</summary>
          <ul><li v-for="(e, i) in preview.errors" :key="i">{{ e }}</li></ul>
        </details>
        <p v-if="duplicateCount" class="hint">重複的資料預設跳過;勾選左側方塊可強制匯入該筆。</p>
      </div>

      <div class="table-wrap">
        <table class="grid">
          <thead>
            <tr>
              <th class="chk">強制</th>
              <th>日期</th>
              <th>類型</th>
              <th>類別</th>
              <th>項目</th>
              <th class="num">金額</th>
              <th>狀態</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="r in preview.rows"
              :key="`${r.sheet}-${r.row}`"
              :class="{ skipped: r.is_duplicate && !isForced(r) }"
            >
              <td class="chk">
                <input
                  v-if="r.is_duplicate"
                  type="checkbox"
                  :checked="isForced(r)"
                  :aria-label="`強制匯入 ${r.date} ${r.category_top}`"
                  @change="toggleForce(r)"
                />
              </td>
              <td class="nowrap">{{ r.date }}</td>
              <td><span class="badge" :class="r.type">{{ ENTRY_TYPE_LABEL[r.type] }}</span></td>
              <td>{{ r.category_top }}</td>
              <td>{{ r.item ?? '-' }}</td>
              <td class="num"><span class="amount" :class="r.type">{{ formatCurrency(r.amount) }}</span></td>
              <td>
                <span v-if="r.is_duplicate && !isForced(r)" class="pill">重複跳過</span>
                <span v-else-if="r.is_duplicate && isForced(r)" class="pill warn">強制匯入</span>
                <span v-else-if="r.will_create_category" class="pill warn">新分類</span>
                <span v-else class="pill ok">匯入</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="modal-foot">
        <button type="button" class="btn" @click="resetImport">取消</button>
        <button type="button" class="btn primary" :disabled="committing || finalImportCount === 0" @click="handleCommit">
          {{ committing ? '匯入中…' : `確認匯入 ${finalImportCount} 筆` }}
        </button>
      </div>
    </template>
  </section>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import AppIcon from './AppIcon.vue'
import { formatCurrency, ENTRY_TYPE_LABEL } from '@/utils/ledgerLabels'
import { previewImport, commitImport, exportExcel } from '@/api/importExport'
import { fetchAccounts } from '@/api/ledgerApi'
import { ACCOUNT_TYPE_LABEL } from '@/utils/ledgerLabels'
import type { ImportPreviewResponse, ImportCommitResponse } from '@/types/importExport'
import type { AccountOut } from '@/types/ledger'

const accounts = ref<AccountOut[]>([])
const selectedAccountId = ref('')
const selectedFile = ref<File | null>(null)
const preview = ref<ImportPreviewResponse | null>(null)
const commitResult = ref<ImportCommitResponse | null>(null)
const loading = ref(false)
const committing = ref(false)
const exporting = ref(false)
const exportYear = ref(new Date().getFullYear())
const forcedRows = ref<Set<string>>(new Set())
const fileInput = ref<HTMLInputElement | null>(null)
const accountsError = ref('')

const availableYears = computed(() => {
  const cur = new Date().getFullYear()
  return Array.from({ length: 5 }, (_, i) => cur - i)
})
const duplicateCount = computed(() => preview.value?.rows.filter((r) => r.is_duplicate).length ?? 0)
const finalImportCount = computed(() => {
  if (!preview.value) return 0
  return preview.value.rows.filter((r) => !r.is_duplicate || isForced(r)).length
})

fetchAccounts()
  .then((list) => {
    accounts.value = list
    if (list.length && !selectedAccountId.value) {
      selectedAccountId.value = list.find((a) => a.is_default_expense)?.id ?? list[0].id
    }
  })
  .catch(() => {
    accountsError.value = '載入帳戶失敗,請重新整理頁面'
  })

// 清空檔案欄位,否則再次選同一個檔案不會觸發 change
function clearFileInput() {
  if (fileInput.value) fileInput.value.value = ''
}

function rowKey(r: { sheet: string; row: number }) {
  return `${r.sheet}:${r.row}`
}
function isForced(r: { sheet: string; row: number }) {
  return forcedRows.value.has(rowKey(r))
}
function toggleForce(r: { sheet: string; row: number }) {
  const key = rowKey(r)
  forcedRows.value.has(key) ? forcedRows.value.delete(key) : forcedRows.value.add(key)
}

function handleFileSelect(e: Event) {
  const target = e.target as HTMLInputElement
  selectedFile.value = target.files?.[0] ?? null
  preview.value = null
  commitResult.value = null
  forcedRows.value.clear()
}

async function handlePreview() {
  if (!selectedFile.value || !selectedAccountId.value) return
  loading.value = true
  try {
    preview.value = await previewImport(selectedFile.value, selectedAccountId.value)
  } catch (err) {
    alert('預覽失敗,請確認檔案格式是否正確')
    console.error(err)
  } finally {
    loading.value = false
  }
}

async function handleCommit() {
  if (!selectedFile.value || !selectedAccountId.value) return
  if (!confirm(`確定匯入 ${finalImportCount.value} 筆交易?`)) return
  committing.value = true
  try {
    commitResult.value = await commitImport(selectedFile.value, selectedAccountId.value, [...forcedRows.value])
    preview.value = null
    selectedFile.value = null
    forcedRows.value.clear()
    clearFileInput()
  } catch (err) {
    alert('匯入失敗')
    console.error(err)
  } finally {
    committing.value = false
  }
}

function resetImport() {
  preview.value = null
  selectedFile.value = null
  forcedRows.value.clear()
  clearFileInput()
}

async function handleExport() {
  exporting.value = true
  try {
    await exportExcel(exportYear.value)
  } catch (err) {
    alert('匯出失敗')
    console.error(err)
  } finally {
    exporting.value = false
  }
}
</script>

<style scoped>
.lbl { font-size: 13px; font-weight: 700; color: var(--text-2); }
.row.nowrap { flex-wrap: nowrap; }
.file { flex: 1; min-width: 0; min-height: var(--h-btn); padding-top: 5px; }
.result { margin-top: 16px; }
.preview-summary { border-top: 1px solid var(--line-soft); }
.detail-box { margin-top: 12px; padding: 8px 12px; border: 1px solid var(--line-soft); border-radius: var(--radius-sm); background: rgb(255 255 255 / 55%); }
.detail-box summary { cursor: pointer; font-weight: 700; }
.detail-box ul { margin: 6px 0 0; padding-left: 22px; }
.detail-box.errors { border-color: var(--bad-line); background: var(--bad-soft); color: #8e1c1c; }
.preview-summary .hint { margin: 12px 0 0; }
.chk { width: 56px; text-align: center; }
tr.skipped td { opacity: 0.5; }
</style>
__F58_EOF__

cat > "$FE/src/views/AccountsView.vue" << '__F58_EOF__'
<script setup lang="ts">
import AccountList from '@/components/AccountList.vue'
</script>

<template>
  <!-- AccountList 自帶面板 -->
  <AccountList />
</template>
__F58_EOF__

cat > "$FE/src/views/CategoriesView.vue" << '__F58_EOF__'
<script setup lang="ts">
import CategoryList from '@/components/CategoryList.vue'
</script>

<template>
  <!-- CategoryList 自帶面板 -->
  <CategoryList />
</template>
__F58_EOF__

cat > "$FE/src/views/TagsView.vue" << '__F58_EOF__'
<script setup lang="ts">
import TagList from '@/components/TagList.vue'
</script>

<template>
  <!-- TagList 自帶面板 -->
  <TagList />
</template>
__F58_EOF__

cat > "$FE/src/views/TransferView.vue" << '__F58_EOF__'
<script setup lang="ts">
import ExcelImportExport from '@/components/ExcelImportExport.vue'
</script>

<template>
  <!-- ExcelImportExport 自帶面板 -->
  <ExcelImportExport />
</template>
__F58_EOF__


# ---------- 驗證建置(失敗則還原前端改動,不 commit) ----------
echo "▶ npm install && npm run build(vue-tsc 型別檢查 + vite build)"
if ! ( cd "$FE" && npm install --no-audit --no-fund && npm run build ); then
  echo "❌ 建置失敗,還原本次前端改動" >&2
  git checkout HEAD -- "$FE/src"
  git clean -fdq -- "$FE/src"
  exit 1
fi

git add -A "$FE/src"
git commit -m "feat: 帳戶/分類/消費品項/匯入匯出頁改用金屬主題(表格、LED 按鍵、統計卡片),移除 inline style"

echo
git log --oneline -3
echo
git diff HEAD~1 --stat | tail -n 30
echo
echo "✅ 完成。確認無誤後:git push origin main && ./deploy.sh,瀏覽器 Ctrl+Shift+R"
