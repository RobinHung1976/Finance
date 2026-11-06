#!/usr/bin/env bash
# update63.sh — 分類/品項選取顯示一致化
#   - CategoryPicker/CategoryFilterPicker:點沒有子分類的分類只選取、停在原層(按鍵直接亮綠),有子分類才進入下一層;麵包屑中被選取的層級也亮綠
#   - CategoryPicker:「已選擇」改為綠色標籤顯示完整路徑;最上層選取尚無細項的大類時,可選「加在某某底下」建立第一個細項(維持兩層結構)
#   - TagPicker:新增「已選擇」綠色標籤列(點一下取消),搜尋篩掉時也看得到;消費品項管理頁不顯示
# 執行位置:server 的 /root/apps(root)
set -euo pipefail

CURRENT=63
FE=ledger-frontend

# ---------- 前置驗證(不通過不寫入任何檔案) ----------
[ -d .git ] && [ -d "$FE/src" ] && [ -f deploy.sh ] \
  || { echo "❌ 請在 Finance repo 根目錄執行(需有 .git、$FE/src、deploy.sh)" >&2; exit 1; }
if ! grep -q "add-key" "$FE/src/components/TagPicker.vue"; then
  echo "❌ 尚未包含 update61.sh 的改動,請先確認 update61.sh 是否已成功套用" >&2; exit 1
fi
if grep -q "selectedLeafHere" "$FE/src/components/CategoryPicker.vue"; then
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
check_sha src/styles/theme.css cc44467a6cdcda7cd215d622df6184bde0bf90ef3cf15e63fc3d9db492732fef
check_sha src/components/CategoryPicker.vue 06b024df4dc2526b45b87ec7e7fd61c90b5eea2b54cd8f945befb3dd79f7e9da
check_sha src/components/CategoryFilterPicker.vue 2f9786343c73d013822b069d69072064498419cd20c15153e3c7e9a694957a31
check_sha src/components/TagPicker.vue 1082048638ac47827a841fd594acc4612a0213251880b2db903a53b073600570
check_sha src/components/TagList.vue 83532fd702e97b257df1384e4aad5bbdb7d3103e1c5f67128f98b01f17c5f896
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
cat > "$FE/src/styles/theme.css" << '__F63_EOF__'
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
  --c-income: #1f8a4c;   /* 收入圖示/圖表色 */
  --c-expense: #b8391a;  /* 支出圖示/圖表色 */

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

/* ---------- 選擇器（CategoryPicker / TagPicker / 三個篩選器共用） ---------- */
.category-picker, .tag-picker, .filter-picker-box {
  padding: 10px 12px 12px; border: 1px solid var(--line); border-radius: 8px;
  background: rgb(255 255 255 / 50%); box-shadow: inset 0 1px 2px rgb(0 0 0 / 8%);
}
:is(.category-picker, .tag-picker, .filter-picker-box) .search-input { width: 100%; min-height: 32px; font-size: 13px; margin-bottom: 8px; }
:is(.category-picker, .tag-picker, .filter-picker-box) .breadcrumb { display: flex; flex-wrap: wrap; align-items: center; gap: 2px; margin-bottom: 8px; }
:is(.category-picker, .tag-picker, .filter-picker-box) .crumb {
  padding: 1px 6px; font: inherit; font-size: 12.5px; color: var(--muted); background: none; border: 0; border-radius: 4px; cursor: pointer;
}
:is(.category-picker, .tag-picker, .filter-picker-box) .crumb:hover { color: var(--text); background: rgb(0 0 0 / 5%); }
:is(.category-picker, .tag-picker, .filter-picker-box) .crumb.active { color: var(--accent); font-weight: 700; }
:is(.category-picker, .tag-picker, .filter-picker-box) .crumb.selected {
  color: #fff; text-shadow: 0 -1px 0 rgb(0 0 0 / 35%); background: var(--brand-metal-lit); border: 1px solid var(--brand-edge);
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 45%), 0 0 6px var(--brand-glow);
}
:is(.category-picker, .tag-picker, .filter-picker-box) .crumb-sep { color: var(--field-line); font-size: 12px; }
:is(.category-picker, .tag-picker, .filter-picker-box) :is(.option-grid, .tag-grid) { display: flex; flex-wrap: wrap; gap: 6px; }
.filter-picker-box .option-grid { max-height: 240px; overflow-y: auto; padding: 1px; }
:is(.category-picker, .tag-picker, .filter-picker-box) .tag-section-label { margin: 10px 0 5px; font-size: 12px; font-weight: 700; color: var(--muted); }
:is(.category-picker, .tag-picker, .filter-picker-box) :is(.option-btn, .tag-btn, .search-result-btn) {
  display: inline-flex; align-items: center; gap: 4px; min-height: 30px; padding: 0 12px;
  font: inherit; font-size: 13px; font-weight: 600; color: #22272e; text-shadow: 0 1px 0 #fff; cursor: pointer;
  border: 1px solid #a9b0b8; border-radius: var(--radius-sm); background: var(--metal-key);
  box-shadow: inset 0 1px 0 #fff, 0 1px 2px rgb(0 0 0 / 15%);
}
:is(.category-picker, .tag-picker, .filter-picker-box) :is(.option-btn, .tag-btn, .search-result-btn):hover { background: var(--metal-key-hover); }
:is(.tag-picker .tag-btn, .filter-picker-box.tags .option-btn) { border-radius: 999px; }
:is(.category-picker, .tag-picker, .filter-picker-box) :is(.option-btn, .tag-btn, .search-result-btn).selected {
  color: #fff; text-shadow: 0 -1px 0 rgb(0 0 0 / 35%); border-color: var(--brand-edge); background: var(--brand-metal-lit);
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 45%), 0 0 6px var(--brand-glow);
}
:is(.category-picker, .tag-picker, .filter-picker-box) .search-results { display: flex; flex-direction: column; gap: 4px; max-height: 240px; overflow-y: auto; padding: 1px; }
:is(.category-picker, .tag-picker, .filter-picker-box) .search-result-btn { justify-content: flex-start; text-align: left; }
:is(.category-picker, .tag-picker, .filter-picker-box) .chevron { color: var(--muted); font-size: 12px; }
:is(.category-picker, .tag-picker, .filter-picker-box) .selected .chevron { color: rgb(255 255 255 / 80%); }
:is(.category-picker, .tag-picker) .create-row {
  display: flex; align-items: center; gap: 10px; flex-wrap: wrap; margin-top: 12px; padding-top: 12px; border-top: 1px dashed var(--line);
}
/* 新增按鍵:與支出/收入同款的立體按鍵,開啟新增欄位時亮綠燈 */
:is(.category-picker, .tag-picker) .key.add-key { height: 36px; padding: 0 14px 6px; font-size: 13.5px; color: var(--accent); }
:is(.category-picker, .tag-picker) .key.add-key::after { left: 10px; right: 10px; bottom: 3px; height: 3px; }
:is(.category-picker, .tag-picker) .key.add-key .i { width: 16px; height: 16px; stroke-width: 2.6; color: var(--c-income); }
:is(.category-picker, .tag-picker) .create-form { display: flex; align-items: center; gap: 8px; flex: 1; min-width: 260px; }
:is(.category-picker, .tag-picker) .create-form input { flex: 1; min-width: 0; }
:is(.category-picker, .tag-picker) .create-target { display: inline-flex; gap: 6px; flex-wrap: wrap; }
.tag-picker .selected-tag {
  margin: 0 0 0 4px; padding: 0 10px; border-radius: 999px; font: inherit; font-size: 12.5px; font-weight: 700; line-height: 1.8; cursor: pointer;
  color: #fff; text-shadow: 0 -1px 0 rgb(0 0 0 / 35%); background: var(--brand-metal-lit); border: 1px solid var(--brand-edge);
}
.tag-picker .selected-tag:hover { filter: brightness(1.08); }
.category-picker .selected-path {
  display: inline-block; margin-left: 4px; padding: 0 10px; border-radius: 999px; font-weight: 700; color: #fff; line-height: 1.8;
  text-shadow: 0 -1px 0 rgb(0 0 0 / 35%); background: var(--brand-metal-lit); border: 1px solid var(--brand-edge);
}
:is(.category-picker, .tag-picker) .create-where { font-size: 12.5px; color: var(--muted); white-space: nowrap; }
:is(.category-picker, .tag-picker) .error-banner { margin: 8px 0 0; }
:is(.category-picker, .tag-picker, .filter-picker-box) :is(.selected-hint, .no-result) { margin: 8px 0 0; font-size: 12.5px; color: var(--muted); }
.category-picker .selected-hint.missing { color: var(--bad); }

/* ---------- 錯誤訊息 ---------- */
.error-banner {
  margin-bottom: 16px; padding: 10px 12px; font-size: 13px;
  color: #8e1c1c; background: var(--bad-soft); border: 1px solid var(--bad-line); border-radius: var(--radius-sm);
}

/* ---------- 登入 / 註冊等單張卡片頁 ---------- */
.auth-page { min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 24px; }
.auth-card {
  width: 100%; max-width: 400px; overflow: hidden; border: 1px solid var(--line); border-radius: var(--radius);
  background: var(--brush-light), var(--metal-plate); box-shadow: var(--bevel), 0 18px 50px rgb(30 35 45 / 28%);
}
.auth-body { padding: 22px 28px 26px; }
.auth-body h1 { margin: 0 0 4px; font-size: 20px; text-shadow: 0 1px 0 #fff; }
.auth-body .subtitle { margin: 0 0 20px; font-size: 13.5px; color: var(--muted); }
.auth-body h1 + :not(.subtitle) { margin-top: 16px; }
.stack-form { display: flex; flex-direction: column; gap: 16px; }
.btn.block { width: 100%; height: 38px; font-size: 14px; }
.auth-switch { margin: 18px 0 0; text-align: center; font-size: 13px; color: var(--muted); }
.auth-switch a { font-weight: 700; }

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
__F63_EOF__

cat > "$FE/src/components/CategoryPicker.vue" << '__F63_EOF__'
<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import AppIcon from './AppIcon.vue'
import { createCategory } from '@/api/ledgerApi'
import type { CategoryOut, EntryType } from '@/types/ledger'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const props = defineProps<{
  categories: CategoryOut[]
  type: EntryType
  modelValue: string
  hideSelectedHint?: boolean
}>()

const emit = defineEmits<{
  'update:modelValue': [value: string]
  created: [category: CategoryOut]
}>()

const path = ref<CategoryOut[]>([])

watch(
  () => props.type,
  () => {
    path.value = []
    searchQuery.value = ''
  }
)

const currentParentId = computed<string | null>(() => {
  const last = path.value[path.value.length - 1]
  return last ? last.id : null
})

const currentLevelCategories = computed(() =>
  props.categories.filter((c) => c.type === props.type && c.parent_id === currentParentId.value)
)

function hasChildren(categoryId: string): boolean {
  return props.categories.some((c) => c.parent_id === categoryId)
}

function ancestorChain(category: CategoryOut): CategoryOut[] {
  const chain: CategoryOut[] = []
  let node: CategoryOut | undefined = category
  while (node) {
    chain.unshift(node)
    node = node.parent_id ? props.categories.find((c) => c.id === node!.parent_id) : undefined
  }
  return chain
}

function fullPathLabel(category: CategoryOut): string {
  return ancestorChain(category).map((c) => c.name).join(' › ')
}

// 有子分類才進入下一層;沒有子分類只選取、停在原層,選取狀態直接顯示在按鍵上
function selectCategory(category: CategoryOut) {
  emit('update:modelValue', category.id)
  if (hasChildren(category.id)) path.value.push(category)
}

function jumpToBreadcrumb(index: number) {
  if (index < 0) {
    path.value = []
    return
  }
  path.value = path.value.slice(0, index + 1)
  emit('update:modelValue', path.value[index].id)
}

const searchQuery = ref('')

const searchResults = computed(() => {
  const q = searchQuery.value.trim()
  if (!q) return []
  const lower = q.toLowerCase()
  return props.categories
    .filter((c) => c.type === props.type && c.name.toLowerCase().includes(lower))
    .map((c) => ({ category: c, label: fullPathLabel(c) }))
    .slice(0, 30)
})

function selectFromSearch(category: CategoryOut) {
  emit('update:modelValue', category.id)
  const chain = ancestorChain(category)
  path.value = chain.slice(0, -1)
  searchQuery.value = ''
}

const showCreateForm = ref(false)
const currentLevelLabel = computed(() => (path.value.length ? path.value[path.value.length - 1].name : '最上層'))

// 最上層中被選取、且還沒有子分類的大類:新增時可選擇加在它底下(建立第一個細項)
// 只限最上層:分類樹維持兩層(大類 > 細項),第三層請改用消費品項
const selectedLeafHere = computed(() =>
  path.value.length === 0
    ? (currentLevelCategories.value.find((c) => c.id === props.modelValue && !hasChildren(c.id)) ?? null)
    : null
)
const createUnderSelected = ref(false)
const createParent = computed<CategoryOut | null>(() =>
  createUnderSelected.value && selectedLeafHere.value ? selectedLeafHere.value : path.value[path.value.length - 1] ?? null
)
const createTargetLabel = computed(() => createParent.value?.name ?? '最上層')

// 開啟新增欄位時,若正在搜尋且沒有完全同名的分類,直接帶入搜尋字
function toggleCreateForm() {
  showCreateForm.value = !showCreateForm.value
  createError.value = ''
  createUnderSelected.value = false
  const q = searchQuery.value.trim()
  if (showCreateForm.value && q && !newCategoryName.value) newCategoryName.value = q
}
const newCategoryName = ref('')
const createError = ref('')
const isCreating = ref(false)

async function handleCreate() {
  createError.value = ''
  const trimmedName = newCategoryName.value.trim()
  if (!trimmedName) {
    createError.value = '請輸入分類名稱'
    return
  }
  const parent = createParent.value
  const parentId = parent?.id ?? null
  const isDuplicate = props.categories.some(
    (c) => c.type === props.type && c.parent_id === parentId && c.name.trim().toLowerCase() === trimmedName.toLowerCase()
  )
  if (isDuplicate) {
    createError.value = '此層級已有同名分類,請直接選擇現有分類'
    return
  }
  isCreating.value = true
  try {
    const created = await createCategory({
      name: trimmedName,
      type: props.type,
      parent_id: parentId,
    })
    emit('created', created)
    emit('update:modelValue', created.id)
    // 新分類沒有子分類,不進入;若是加在選取的分類底下,則進入該分類讓新分類顯示在按鍵列
    if (parent && path.value[path.value.length - 1]?.id !== parent.id) path.value.push(parent)
    createUnderSelected.value = false
    newCategoryName.value = ''
    showCreateForm.value = false
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    createError.value = axiosErr.response?.data?.detail ?? '新增失敗'
  } finally {
    isCreating.value = false
  }
}

const selectedCategoryPath = computed(() => {
  const selected = props.categories.find((c) => c.id === props.modelValue)
  return selected ? fullPathLabel(selected) : ''
})
</script>

<template>
  <div class="category-picker">
    <input
      v-model="searchQuery"
      type="search"
      class="search-input"
      placeholder="搜尋分類(不限層級,例如：晚餐)"
    />

    <template v-if="searchQuery.trim()">
      <div v-if="searchResults.length" class="search-results">
        <button
          v-for="r in searchResults"
          :key="r.category.id"
          type="button"
          class="search-result-btn"
          :class="{ selected: r.category.id === modelValue }"
          @click="selectFromSearch(r.category)"
        >
          {{ r.label }}
        </button>
      </div>
      <p v-else class="selected-hint">沒有符合「{{ searchQuery }}」的分類</p>
    </template>

    <template v-else>
      <div class="breadcrumb">
        <button type="button" class="crumb" :class="{ active: path.length === 0 }" @click="jumpToBreadcrumb(-1)">
          全部
        </button>
        <template v-for="(node, idx) in path" :key="node.id">
          <span class="crumb-sep">›</span>
          <button
            type="button"
            class="crumb"
            :class="{ active: idx === path.length - 1, selected: node.id === modelValue }"
            @click="jumpToBreadcrumb(idx)"
          >
            {{ node.name }}
          </button>
        </template>
      </div>

      <div class="option-grid">
        <button
          v-for="c in currentLevelCategories"
          :key="c.id"
          type="button"
          class="option-btn"
          :class="{ selected: c.id === modelValue }"
          @click="selectCategory(c)"
        >
          {{ c.name }}
          <span v-if="hasChildren(c.id)" class="chevron">›</span>
        </button>

      </div>
    </template>

    <div class="create-row">
      <button
        type="button"
        class="key add-key"
        :class="{ active: showCreateForm }"
        :aria-expanded="showCreateForm"
        @click="toggleCreateForm"
      >
        <AppIcon name="plus" />新增分類
      </button>
      <span v-if="selectedLeafHere" class="create-target" role="group" aria-label="新增位置">
        <button type="button" class="btn sm" :class="{ on: !createUnderSelected }" :aria-pressed="!createUnderSelected" @click="createUnderSelected = false">
          加在「{{ currentLevelLabel }}」
        </button>
        <button type="button" class="btn sm" :class="{ on: createUnderSelected }" :aria-pressed="createUnderSelected" @click="createUnderSelected = true">
          加在「{{ selectedLeafHere.name }}」底下
        </button>
      </span>
      <span v-else-if="!showCreateForm" class="create-where">加在「{{ currentLevelLabel }}」</span>
      <form v-if="showCreateForm" class="create-form" @submit.prevent="handleCreate">
        <input
          v-model="newCategoryName"
          type="text"
          maxlength="100"
          :placeholder="`在「${createTargetLabel}」新增分類`"
          aria-label="新分類名稱"
          required
        />
        <button class="btn primary sm" type="submit" :disabled="isCreating">
          {{ isCreating ? '新增中…' : '確認新增' }}
        </button>
      </form>
    </div>
    <div v-if="createError" class="error-banner">{{ createError }}</div>

    <template v-if="!hideSelectedHint">
      <p v-if="modelValue" class="selected-hint">已選擇 <span class="selected-path">{{ selectedCategoryPath }}</span></p>
      <p v-else class="selected-hint missing">尚未選擇分類</p>
    </template>
  </div>
</template>
__F63_EOF__

cat > "$FE/src/components/CategoryFilterPicker.vue" << '__F63_EOF__'
<script setup lang="ts">
import { computed, ref } from 'vue'
import type { CategoryOut } from '@/types/ledger'

const props = defineProps<{
  categories: CategoryOut[]
  modelValue: string
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

const path = ref<CategoryOut[]>([])
const searchQuery = ref('')

const currentParentId = computed<string | null>(() => {
  const last = path.value[path.value.length - 1]
  return last ? last.id : null
})

const currentLevelCategories = computed(() =>
  props.categories.filter((c) => c.parent_id === currentParentId.value)
)

function hasChildren(categoryId: string): boolean {
  return props.categories.some((c) => c.parent_id === categoryId)
}

function ancestorChain(category: CategoryOut): CategoryOut[] {
  const chain: CategoryOut[] = []
  let node: CategoryOut | undefined = category
  while (node) {
    chain.unshift(node)
    node = node.parent_id ? props.categories.find((c) => c.id === node!.parent_id) : undefined
  }
  return chain
}
function fullPathLabel(category: CategoryOut): string {
  return ancestorChain(category).map((c) => c.name).join(' › ')
}

// 有子分類才進入下一層;沒有子分類只選取、停在原層
function selectCategory(category: CategoryOut) {
  emit('update:modelValue', category.id)
  if (hasChildren(category.id)) path.value.push(category)
}

function jumpToBreadcrumb(index: number) {
  if (index < 0) {
    path.value = []
    return
  }
  path.value = path.value.slice(0, index + 1)
  emit('update:modelValue', path.value[index].id)
}

function clearSelection() {
  emit('update:modelValue', '')
  path.value = []
}

const searchResults = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return []
  return props.categories
    .map((c) => ({ category: c, label: fullPathLabel(c) }))
    .filter((r) => r.category.name.toLowerCase().includes(q))
    .sort((a, b) => a.label.localeCompare(b.label))
    .slice(0, 30)
})

function selectFromSearch(category: CategoryOut) {
  emit('update:modelValue', category.id)
  path.value = ancestorChain(category).slice(0, -1)
  searchQuery.value = ''
}
</script>

<template>
  <div class="filter-picker-box">
    <input v-model="searchQuery" type="search" class="search-input" placeholder="搜尋分類(不限層級)…" />

    <template v-if="searchQuery.trim()">
      <div v-if="searchResults.length" class="search-results">
        <button
          v-for="r in searchResults"
          :key="r.category.id"
          type="button"
          class="search-result-btn"
          :class="{ selected: r.category.id === modelValue }"
          @click="selectFromSearch(r.category)"
        >
          {{ r.label }}
        </button>
      </div>
      <p v-else class="no-result">沒有符合「{{ searchQuery }}」的分類</p>
    </template>

    <template v-else>
      <div class="breadcrumb">
        <button type="button" class="crumb" :class="{ active: path.length === 0 }" @click="jumpToBreadcrumb(-1)">
          全部
        </button>
        <template v-for="(node, idx) in path" :key="node.id">
          <span class="crumb-sep">›</span>
          <button
            type="button"
            class="crumb"
            :class="{ active: idx === path.length - 1, selected: node.id === modelValue }"
            @click="jumpToBreadcrumb(idx)"
          >
            {{ node.name }}
          </button>
        </template>
      </div>

      <div class="option-grid">
        <button type="button" class="option-btn" :class="{ selected: !modelValue }" @click="clearSelection">
          所有分類
        </button>
        <button
          v-for="c in currentLevelCategories"
          :key="c.id"
          type="button"
          class="option-btn"
          :class="{ selected: c.id === modelValue }"
          @click="selectCategory(c)"
        >
          {{ c.name }}
          <span v-if="hasChildren(c.id)" class="chevron">›</span>
        </button>
      </div>
    </template>
  </div>
</template>
__F63_EOF__

cat > "$FE/src/components/TagPicker.vue" << '__F63_EOF__'
<script setup lang="ts">
import AppIcon from './AppIcon.vue'
import { ref, computed } from 'vue'
import { createTag } from '@/api/ledgerApi'
import type { TagOut } from '@/types/ledger'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const RECENT_LIMIT = 8

const props = defineProps<{
  modelValue: string[]
  tags: TagOut[]
  hideSelectedHint?: boolean
}>()
const emit = defineEmits<{
  'update:modelValue': [value: string[]]
  created: [tag: TagOut]
}>()

const searchQuery = ref('')
const showCreateForm = ref(false)
const newTagName = ref('')
const createError = ref('')
const isCreating = ref(false)

// 開啟新增欄位時,若正在搜尋則直接帶入搜尋字
function toggleCreateForm() {
  showCreateForm.value = !showCreateForm.value
  createError.value = ''
  const q = searchQuery.value.trim()
  if (showCreateForm.value && q && !newTagName.value) newTagName.value = q
}

const isSearching = computed(() => searchQuery.value.trim().length > 0)

const filteredTags = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return props.tags
  return props.tags.filter((t) => t.name.toLowerCase().includes(q))
})

// 最近使用:依 last_used_date 由新到舊排序,取前 N 個(無交易紀錄的品項不列入)
const recentTags = computed(() => {
  return props.tags
    .filter((t) => t.last_used_date)
    .sort((a, b) => (b.last_used_date! < a.last_used_date! ? -1 : 1))
    .slice(0, RECENT_LIMIT)
})

const otherTags = computed(() => {
  const recentIds = new Set(recentTags.value.map((t) => t.id))
  return props.tags.filter((t) => !recentIds.has(t.id))
})

// 已選取的品項(依選取順序),顯示在下方,搜尋篩掉時也看得到
const selectedTags = computed(() =>
  props.modelValue.map((id) => props.tags.find((t) => t.id === id)).filter((t): t is TagOut => !!t)
)

function isSelected(id: string) {
  return props.modelValue.includes(id)
}

function toggleTag(id: string) {
  const next = isSelected(id) ? props.modelValue.filter((v) => v !== id) : [...props.modelValue, id]
  emit('update:modelValue', next)
}

async function handleCreate() {
  createError.value = ''
  const trimmedName = newTagName.value.trim()
  if (!trimmedName) {
    createError.value = '請輸入消費品項名稱'
    return
  }
  const isDuplicate = props.tags.some((t) => t.name.trim().toLowerCase() === trimmedName.toLowerCase())
  if (isDuplicate) {
    createError.value = '此消費品項名稱已存在,請直接選擇現有品項'
    return
  }
  isCreating.value = true
  try {
    const created = await createTag({ name: trimmedName })
    emit('created', created)
    emit('update:modelValue', [...props.modelValue, created.id])
    newTagName.value = ''
    showCreateForm.value = false
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    createError.value = axiosErr.response?.data?.detail ?? '新增失敗'
  } finally {
    isCreating.value = false
  }
}
</script>

<template>
  <div class="tag-picker">
    <input v-model="searchQuery" type="search" class="search-input" placeholder="搜尋消費品項…" />

    <template v-if="!isSearching">
      <div v-if="recentTags.length" class="tag-section-label">最近使用</div>
      <div v-if="recentTags.length" class="tag-grid">
        <button
          v-for="t in recentTags"
          :key="t.id"
          type="button"
          class="tag-btn"
          :class="{ selected: isSelected(t.id) }"
          @click="toggleTag(t.id)"
        >
          {{ t.name }}
        </button>
      </div>

      <div v-if="recentTags.length && otherTags.length" class="tag-section-label">全部品項</div>
      <div class="tag-grid">
        <button
          v-for="t in otherTags"
          :key="t.id"
          type="button"
          class="tag-btn"
          :class="{ selected: isSelected(t.id) }"
          @click="toggleTag(t.id)"
        >
          {{ t.name }}
        </button>
      </div>
    </template>

    <template v-else>
      <div class="tag-grid">
        <span v-if="filteredTags.length === 0" class="no-result">沒有符合「{{ searchQuery }}」的品項</span>
        <button
          v-for="t in filteredTags"
          :key="t.id"
          type="button"
          class="tag-btn"
          :class="{ selected: isSelected(t.id) }"
          @click="toggleTag(t.id)"
        >
          {{ t.name }}
        </button>
      </div>
    </template>

    <div class="create-row">
      <button
        type="button"
        class="key add-key"
        :class="{ active: showCreateForm }"
        :aria-expanded="showCreateForm"
        @click="toggleCreateForm"
      >
        <AppIcon name="plus" />新增品項
      </button>
      <form v-if="showCreateForm" class="create-form" @submit.prevent="handleCreate">
        <input v-model="newTagName" type="text" maxlength="50" placeholder="品項名稱(例如:三媽)" aria-label="新品項名稱" required />
        <button class="btn primary sm" type="submit" :disabled="isCreating">
          {{ isCreating ? '新增中…' : '確認新增' }}
        </button>
      </form>
    </div>
    <div v-if="createError" class="error-banner">{{ createError }}</div>
    <p v-if="!hideSelectedHint && selectedTags.length" class="selected-hint">
      已選擇
      <button
        v-for="t in selectedTags"
        :key="t.id"
        type="button"
        class="selected-tag"
        :title="`取消選擇「${t.name}」`"
        @click="toggleTag(t.id)"
      >
        {{ t.name }} ×
      </button>
    </p>
  </div>
</template>
__F63_EOF__

cat > "$FE/src/components/TagList.vue" << '__F63_EOF__'
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import type { AxiosError } from 'axios'
import AppIcon from './AppIcon.vue'
import TagPicker from './TagPicker.vue'
import { fetchTags, updateTag, deleteTag } from '@/api/ledgerApi'
import type { TagOut } from '@/types/ledger'
import type { ApiError } from '@/types/api'

// 版面比照分類頁:上方「建立消費品項」用 TagPicker 瀏覽/新增,下方「全部消費品項」列表改名/刪除

const emit = defineEmits<{ changed: [] }>()

const tags = ref<TagOut[]>([])
const isLoading = ref(true)
const loadError = ref('')

// TagPicker 需要 v-model,但此頁純粹用來瀏覽/建立,不需要真正「選定」品項
const browsingSelection = ref<string[]>([])

const listSearchQuery = ref('')
const isListSearching = computed(() => listSearchQuery.value.trim().length > 0)

const editingId = ref<string | null>(null)
const editName = ref('')
const editError = ref('')
const isSavingEdit = ref(false)

// 後端已依使用次數多→少、名稱排序
const listedTags = computed(() => {
  const q = listSearchQuery.value.trim().toLowerCase()
  return q ? tags.value.filter((t) => t.name.toLowerCase().includes(q)) : tags.value
})

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

function handleTagCreated(tag: TagOut) {
  tags.value.push(tag)
  emit('changed')
}

function isDuplicateName(name: string, excludeId: string): boolean {
  const lower = name.trim().toLowerCase()
  return tags.value.some((t) => t.id !== excludeId && t.name.trim().toLowerCase() === lower)
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
    browsingSelection.value = browsingSelection.value.filter((id) => id !== tag.id)
    if (editingId.value === tag.id) editingId.value = null
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
      <h2><AppIcon name="tag" />建立消費品項</h2>
    </div>
    <div class="panel-body">
      <div v-if="loadError" class="error-banner">{{ loadError }}</div>
      <p class="hint intro">先搜尋或瀏覽既有品項,沒有的話按「新增品項」。</p>
      <TagPicker v-model="browsingSelection" :tags="tags" :hide-selected-hint="true" @created="handleTagCreated" />
    </div>
  </section>

  <section class="panel">
    <div class="panel-head">
      <h2><AppIcon name="table" />全部消費品項</h2>
      <span class="pill">{{ tags.length }} 個</span>
    </div>
    <div class="toolbar">
      <input v-model="listSearchQuery" type="search" placeholder="搜尋消費品項" aria-label="搜尋消費品項" />
    </div>

    <div v-if="listedTags.length" class="table-wrap">
      <table class="grid">
        <thead>
          <tr>
            <th>品項</th>
            <th class="num">使用次數</th>
            <th>最後使用</th>
            <th class="num">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="t in listedTags" :key="t.id" :class="{ unused: t.usage_count === 0 }">
            <td>
              <form v-if="editingId === t.id" class="row rename" @submit.prevent="saveEdit(t.id)">
                <input v-model="editName" type="text" maxlength="50" aria-label="新名稱" />
                <button class="btn primary sm" type="submit" :disabled="isSavingEdit">
                  {{ isSavingEdit ? '儲存中…' : '儲存' }}
                </button>
                <button type="button" class="btn sm" @click="cancelEdit">取消</button>
                <span v-if="editError" class="field-error">{{ editError }}</span>
              </form>
              <b v-else>{{ t.name }}</b>
            </td>
            <td class="num">{{ t.usage_count }}</td>
            <td class="nowrap">{{ t.last_used_date ?? '—' }}</td>
            <td class="actions">
              <template v-if="editingId !== t.id">
                <button type="button" class="btn sm" @click="startEdit(t)"><AppIcon name="edit" />改名</button>
                <button type="button" class="btn danger sm" @click="handleDelete(t)"><AppIcon name="trash" />刪除</button>
              </template>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p v-else-if="isListSearching" class="empty">找不到符合「{{ listSearchQuery }}」的消費品項。</p>
    <p v-else-if="!isLoading" class="empty">尚未建立任何消費品項。</p>
  </section>
</template>

<style scoped>
.intro { margin: 0 0 10px; }
.rename { flex-wrap: nowrap; }
.rename input { flex: 1; min-width: 160px; max-width: 320px; }
.field-error { color: var(--bad); font-size: 12px; white-space: nowrap; }
tr.unused td:not(.actions) { color: var(--muted); }
</style>
__F63_EOF__


# ---------- 驗證建置(失敗則還原前端改動,不 commit) ----------
echo "▶ npm install && npm run build(vue-tsc 型別檢查 + vite build)"
if ! ( cd "$FE" && npm install --no-audit --no-fund && npm run build ); then
  echo "❌ 建置失敗,還原本次前端改動" >&2
  git checkout HEAD -- "$FE/src"
  git clean -fdq -- "$FE/src"
  exit 1
fi

git add -A "$FE/src"
git commit -m "feat: 分類/品項選取顯示一致化(無子分類不進入下一層、已選擇綠色標籤、可在大類底下新增第一個細項)"

echo
git log --oneline -3
echo
git diff HEAD~1 --stat | tail -n 30
echo
echo "✅ 完成。確認無誤後:git push origin main && ./deploy.sh,瀏覽器 Ctrl+Shift+R"
