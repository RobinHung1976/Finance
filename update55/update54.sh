#!/usr/bin/env bash
# update54.sh — 前端改版第一階段：金屬主題 + 側欄版面(AppLayout) + Dashboard 分頁改子路由
#   - 新增 styles/theme.css(金屬主題,品牌色墨綠 #1f5f4f)、AppLayout(側欄/頂部列)、AppIcon、BrandBlock
#   - Dashboard 六個分頁改為 /stats /transactions /accounts /categories /tags /transfer 子路由
#   - 成員管理、操作紀錄移入共用版面;登入/註冊/忘記密碼/重設密碼加上品牌列
#   - style.css 改為相容層:舊 class(.btn-primary/.field/.error-banner/.auth-*)沿用,外觀改為金屬主題
#   - 修正:統計頁「今天」用 toISOString()(UTC)計算,台北 00:00–07:59 會變成前一天
# 執行位置:server 的 /root/apps(root)
set -euo pipefail

CURRENT=54
FE=ledger-frontend

# ---------- 前置驗證(不通過不寫入任何檔案) ----------
[ -d .git ] && [ -d "$FE/src" ] && [ -f deploy.sh ] \
  || { echo "❌ 請在 Finance repo 根目錄執行(需有 .git、$FE/src、deploy.sh)" >&2; exit 1; }
[ -d update53 ] || { echo "❌ 找不到 update53/,請確認 update53.sh 已套用" >&2; exit 1; }
if [ -f "$FE/src/layouts/AppLayout.vue" ] && git ls-files --error-unmatch "$FE/src/layouts/AppLayout.vue" >/dev/null 2>&1; then
  echo "❌ 已套用過本次更新(AppLayout.vue 已在版控中),不需重跑" >&2; exit 1
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
check_sha src/main.ts af782f87b00579ee3d29d8bae752f722174cf6d9f2f18f7d7c22dcb32182dc31
check_sha src/style.css 02e67ca9b74a1f03cc0c7c22a7ce82026878efb79b22d6ad38d1812ca2358b13
check_sha src/router/index.ts 4481596060b873e4de1fb248f8e4e8736fe97b4f8018465cc5dc74717f39e4c7
check_sha src/components/DateRangePicker.vue 251c1cf36b07603ce493f27ac70a366b46a46caaf29a0e390ad2a0526f0db378
check_sha src/views/MembersView.vue d98e6fb3c71708e89ccb55f1fdd9995125856da9a36eec186bfe9d3c5943f445
check_sha src/views/AuditLogView.vue 3b6ab1e88bbc975c5f0718dc8424d7eee0e12b92ce90b5c657689210c04007a2
check_sha src/views/LoginView.vue c4e784774d8bd5c087cc7751dbd219a15c333188d398caf83fad12a83bd52745
check_sha src/views/RegisterHouseholdView.vue b52bf7d061d7b508557ee270a604be7e32f675727247ee5e4eb114d3a4e64ab0
check_sha src/views/ForgotPasswordView.vue 0315abaaff7a7db1c6260c215a3a07c013e95c3566f755e3d2f5a0af67b8515c
check_sha src/views/ResetPasswordView.vue ee8fd7a71f529e265feb9ac11fa1333d328a12195eb9ec88e21b0bbf80c12db8
check_sha src/views/DashboardView.vue 03dd6599692761bdbadfaf7db94a2f40cd2c3877787e8a5e984dfb2c43933007
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
mkdir -p "$FE/src/styles" "$FE/src/layouts" "$FE/src/utils" "$FE/src/stores"

cat > "$FE/src/styles/theme.css" << '__F54_EOF__'
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
__F54_EOF__

cat > "$FE/src/components/AppIcon.vue" << '__F54_EOF__'
<script setup lang="ts">
// 線條圖示（24x24、stroke 繪製，裝飾用，螢幕閱讀器略過）
export type IconName =
  | 'book' | 'chart' | 'receipt' | 'wallet' | 'folder' | 'tag' | 'transfer'
  | 'users' | 'history' | 'logout' | 'clock' | 'trend' | 'pie' | 'ranking' | 'calendar'

const PATHS: Record<IconName, string> = {
  book: '<path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1 0-5H20"/><path d="M9 7h7M9 11h5"/>',
  chart: '<path d="M3 3v18h18"/><path d="M7 16v-4M12 16V8M17 16v-7"/>',
  receipt: '<path d="M5 3h14v18l-3-2-2 2-2-2-2 2-2-2-3 2z"/><path d="M9 8h6M9 12h6M9 16h3"/>',
  wallet: '<path d="M19 7V5a2 2 0 0 0-2-2H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-4a2 2 0 0 0 0 4h4v3a1 1 0 0 1-1 1H5a2 2 0 0 1-2-2V5"/>',
  folder: '<path d="M4 20h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-8l-2-3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2z"/><path d="M8 13h8"/>',
  tag: '<path d="M12.6 2.6A2 2 0 0 0 11.2 2H4a2 2 0 0 0-2 2v7.2a2 2 0 0 0 .6 1.4l8.7 8.7a2.4 2.4 0 0 0 3.4 0l6.6-6.6a2.4 2.4 0 0 0 0-3.4z"/><circle cx="7.5" cy="7.5" r="1.5"/>',
  transfer: '<path d="m3 16 4 4 4-4"/><path d="M7 20V4"/><path d="m21 8-4-4-4 4"/><path d="M17 4v16"/>',
  users: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
  history: '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/><path d="M12 7v5l3.5 2"/>',
  logout: '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="m16 17 5-5-5-5"/><path d="M21 12H9"/>',
  clock: '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
  trend: '<path d="m22 7-8.5 8.5-5-5L2 17"/><path d="M16 7h6v6"/>',
  pie: '<path d="M21.2 15.9A10 10 0 1 1 8 2.8"/><path d="M22 12A10 10 0 0 0 12 2v10z"/>',
  ranking: '<path d="M10 6h11M10 12h11M10 18h11"/><path d="M4 6h1v4M4 10h2"/><path d="M6 18H4c0-1 2-2 2-3s-1-1.5-2-1"/>',
  calendar: '<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
}

defineProps<{ name: IconName }>()
</script>

<template>
  <!-- PATHS 為本檔內的固定常數，不含任何使用者輸入，v-html 無 XSS 風險 -->
  <svg class="i" viewBox="0 0 24 24" aria-hidden="true" focusable="false" v-html="PATHS[name]"></svg>
</template>
__F54_EOF__

cat > "$FE/src/components/BrandBlock.vue" << '__F54_EOF__'
<script setup lang="ts">
import AppIcon from './AppIcon.vue'
</script>

<template>
  <div class="brand">
    <div class="brand-row">
      <span class="brand-mark"><AppIcon name="book" /></span>
      <span class="brand-sep"></span>
      <span class="brand-name">家庭理財<small>Household Finance Ledger</small></span>
    </div>
    <div class="brand-product">FINANCE LEDGER</div>
  </div>
</template>
__F54_EOF__

cat > "$FE/src/layouts/AppLayout.vue" << '__F54_EOF__'
<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { fetchMyHousehold } from '@/api/auth'
import type { HouseholdOut } from '@/types/api'
import AppIcon, { type IconName } from '@/components/AppIcon.vue'
import BrandBlock from '@/components/BrandBlock.vue'

const TIMEZONE = 'Asia/Taipei'

interface NavItem {
  to: string
  label: string
  icon: IconName
  adminOnly?: boolean
}

const NAV_GROUPS: { title: string; items: NavItem[] }[] = [
  {
    title: '報表',
    items: [
      { to: '/stats', label: '統計', icon: 'chart' },
      { to: '/transactions', label: '交易紀錄', icon: 'receipt' },
    ],
  },
  {
    title: '帳務設定',
    items: [
      { to: '/accounts', label: '帳戶', icon: 'wallet' },
      { to: '/categories', label: '分類', icon: 'folder' },
      { to: '/tags', label: '消費品項', icon: 'tag' },
      { to: '/transfer', label: '匯入/匯出', icon: 'transfer' },
    ],
  },
  {
    title: '帳本管理',
    items: [
      { to: '/members', label: '成員管理', icon: 'users' },
      { to: '/audit-logs', label: '操作紀錄', icon: 'history', adminOnly: true },
    ],
  },
]

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const household = ref<HouseholdOut | null>(null)

const visibleGroups = computed(() =>
  NAV_GROUPS.map((g) => ({ ...g, items: g.items.filter((i) => !i.adminOnly || auth.role === 'admin') })).filter(
    (g) => g.items.length > 0,
  ),
)
const pageTitle = computed(() => (route.meta.title as string | undefined) ?? '家庭理財')
const roleLabel = computed(() => (auth.role === 'admin' ? '管理者' : '使用者'))

// 側欄時鐘：固定顯示台北時間
const clockFormatter = new Intl.DateTimeFormat('sv-SE', {
  timeZone: TIMEZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  hour12: false,
})
const now = ref(clockFormatter.format(new Date()))
let clockTimer: number | undefined

onMounted(async () => {
  clockTimer = window.setInterval(() => {
    now.value = clockFormatter.format(new Date())
  }, 15_000)
  try {
    household.value = await fetchMyHousehold()
  } catch {
    // 失敗不阻斷畫面，側欄 fallback 顯示預設文字
  }
})

onBeforeUnmount(() => window.clearInterval(clockTimer))

function handleLogout() {
  auth.logout()
  router.push({ name: 'login' })
}
</script>

<template>
  <div class="layout">
    <aside class="sidebar">
      <BrandBlock />

      <div class="household-nav">
        <div class="nav-title">目前帳本</div>
        <div class="household-current" :title="household?.name">
          <AppIcon name="book" /><span>{{ household?.name ?? '載入中…' }}</span>
        </div>
      </div>

      <nav class="nav" aria-label="主選單">
        <div v-for="group in visibleGroups" :key="group.title" class="nav-group">
          <div class="nav-title">{{ group.title }}</div>
          <router-link v-for="item in group.items" :key="item.to" :to="item.to" active-class="active">
            <AppIcon :name="item.icon" />{{ item.label }}
          </router-link>
        </div>
      </nav>

      <div class="side-foot">
        <span class="clock" title="目前時間">
          <AppIcon name="clock" /><span class="tz">{{ TIMEZONE }}</span><time>{{ now }}</time>
        </span>
      </div>
    </aside>

    <div class="main">
      <header class="topbar">
        <h1>{{ pageTitle }}</h1>
        <span class="who">登入身分：<b>{{ roleLabel }}</b></span>
        <button class="btn sm" type="button" @click="handleLogout"><AppIcon name="logout" />登出</button>
      </header>
      <main class="content">
        <router-view />
      </main>
    </div>
  </div>
</template>
__F54_EOF__

cat > "$FE/src/utils/date.ts" << '__F54_EOF__'
// 日期工具：一律以瀏覽器本地時區組字串。
// 不可用 toISOString()（UTC），否則台北時間 00:00–07:59 會得到前一天。

function pad(n: number): string {
  return String(n).padStart(2, '0')
}

export function toLocalISODate(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

export function todayLocal(): string {
  return toLocalISODate(new Date())
}

export interface DateRange {
  start: string
  end: string
}

export type RangePreset = 'thisMonth' | 'lastMonth' | 'last3Months' | 'thisYear'

export function presetRange(preset: RangePreset, now: Date = new Date()): DateRange {
  const y = now.getFullYear()
  const m = now.getMonth()
  switch (preset) {
    case 'thisMonth':
      return { start: toLocalISODate(new Date(y, m, 1)), end: toLocalISODate(now) }
    case 'lastMonth':
      // new Date(y, m, 0) = 上個月最後一天（跨年由 Date 自動進位）
      return { start: toLocalISODate(new Date(y, m - 1, 1)), end: toLocalISODate(new Date(y, m, 0)) }
    case 'last3Months':
      // 含本月在內的三個月份：前兩個月 1 號 ~ 今天
      return { start: toLocalISODate(new Date(y, m - 2, 1)), end: toLocalISODate(now) }
    case 'thisYear':
      return { start: `${y}-01-01`, end: toLocalISODate(now) }
  }
}
__F54_EOF__

cat > "$FE/src/stores/statsFilter.ts" << '__F54_EOF__'
import { defineStore } from 'pinia'
import { ref } from 'vue'
import { presetRange } from '@/utils/date'

export type StatsSubTab = 'trend' | 'breakdown' | 'tagBreakdown' | 'topTransactions'

// 統計頁的篩選狀態：放在 store，切到其他頁再回來時保留（原本單頁分頁時的行為）
export const useStatsFilterStore = defineStore('statsFilter', () => {
  const initial = presetRange('thisYear')
  const startDate = ref(initial.start)
  const endDate = ref(initial.end)
  const subTab = ref<StatsSubTab>('trend')
  return { startDate, endDate, subTab }
})
__F54_EOF__

cat > "$FE/src/views/StatsView.vue" << '__F54_EOF__'
<script setup lang="ts">
import { storeToRefs } from 'pinia'
import AppIcon, { type IconName } from '@/components/AppIcon.vue'
import DateRangePicker from '@/components/DateRangePicker.vue'
import MonthlyTrendChart from '@/components/MonthlyTrendChart.vue'
import CategoryBreakdownChart from '@/components/CategoryBreakdownChart.vue'
import TagBreakdownChart from '@/components/TagBreakdownChart.vue'
import TopTransactionsList from '@/components/TopTransactionsList.vue'
import { useStatsFilterStore, type StatsSubTab } from '@/stores/statsFilter'

const SUB_TABS: { key: StatsSubTab; label: string; icon: IconName }[] = [
  { key: 'trend', label: '月收支趨勢', icon: 'trend' },
  { key: 'breakdown', label: '支出分類統計', icon: 'pie' },
  { key: 'tagBreakdown', label: '消費品項排行', icon: 'tag' },
  { key: 'topTransactions', label: '最大單筆排行', icon: 'ranking' },
]

// 四張圖表共用同一組日期區間
const { startDate, endDate, subTab } = storeToRefs(useStatsFilterStore())
</script>

<template>
  <section class="panel">
    <div class="panel-head">
      <div class="keypad" role="tablist" aria-label="統計項目">
        <button
          v-for="t in SUB_TABS"
          :key="t.key"
          type="button"
          role="tab"
          class="key"
          :class="{ active: subTab === t.key }"
          :aria-selected="subTab === t.key"
          @click="subTab = t.key"
        >
          <AppIcon :name="t.icon" />{{ t.label }}
        </button>
      </div>
      <span class="spacer"></span>
      <DateRangePicker v-model:start-date="startDate" v-model:end-date="endDate" />
    </div>
    <div class="panel-body" role="tabpanel">
      <MonthlyTrendChart v-if="subTab === 'trend'" :start-date="startDate" :end-date="endDate" />
      <CategoryBreakdownChart
        v-else-if="subTab === 'breakdown'"
        type="expense"
        :start-date="startDate"
        :end-date="endDate"
      />
      <TagBreakdownChart v-else-if="subTab === 'tagBreakdown'" :start-date="startDate" :end-date="endDate" />
      <TopTransactionsList v-else :start-date="startDate" :end-date="endDate" />
    </div>
  </section>
</template>

<style scoped>
.panel-head { padding-top: 14px; padding-bottom: 12px; }
.keypad { padding: 0; }
</style>
__F54_EOF__

cat > "$FE/src/views/TransactionsView.vue" << '__F54_EOF__'
<script setup lang="ts">
import TransactionList from '@/components/TransactionList.vue'
</script>

<template>
  <section class="panel">
    <div class="panel-body">
      <TransactionList :refresh-key="0" />
    </div>
  </section>
</template>
__F54_EOF__

cat > "$FE/src/views/AccountsView.vue" << '__F54_EOF__'
<script setup lang="ts">
import AccountList from '@/components/AccountList.vue'
</script>

<template>
  <section class="panel">
    <div class="panel-body">
      <AccountList />
    </div>
  </section>
</template>
__F54_EOF__

cat > "$FE/src/views/CategoriesView.vue" << '__F54_EOF__'
<script setup lang="ts">
import CategoryList from '@/components/CategoryList.vue'
</script>

<template>
  <section class="panel">
    <div class="panel-body">
      <CategoryList />
    </div>
  </section>
</template>
__F54_EOF__

cat > "$FE/src/views/TagsView.vue" << '__F54_EOF__'
<script setup lang="ts">
import TagList from '@/components/TagList.vue'
</script>

<template>
  <section class="panel">
    <div class="panel-body">
      <TagList />
    </div>
  </section>
</template>
__F54_EOF__

cat > "$FE/src/views/TransferView.vue" << '__F54_EOF__'
<script setup lang="ts">
import ExcelImportExport from '@/components/ExcelImportExport.vue'
</script>

<template>
  <section class="panel">
    <div class="panel-body">
      <ExcelImportExport />
    </div>
  </section>
</template>
__F54_EOF__

cat > "$FE/src/main.ts" << '__F54_EOF__'
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import './styles/theme.css'
import './style.css'

const app = createApp(App)
app.use(createPinia())
app.use(router)
app.mount('#app')
__F54_EOF__

cat > "$FE/src/style.css" << '__F54_EOF__'
/* 相容層：既有元件仍在使用的舊 class 與舊變數，改以金屬主題（styles/theme.css）呈現。
   各頁改版時逐步改用 theme.css 的 class（.btn / .panel / .grid ...），全部改完後即可移除本檔。 */
:root {
  --color-bg: #f6f7f8;
  --color-surface: #ffffff;
  --color-ink: var(--text);
  --color-primary: var(--brand);
  --color-primary-hover: var(--accent-hover);
  --color-accent: #c17a3d;
  --color-border: var(--line-soft);
  --color-danger: var(--bad);
  --font-sans: var(--font);
}

/* ---------- 登入 / 註冊等單張卡片頁 ---------- */
.auth-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}

.auth-card {
  width: 100%;
  max-width: 400px;
  background: var(--brush-light), var(--metal-plate);
  border: 1px solid var(--line);
  border-radius: var(--radius);
  box-shadow: var(--bevel), 0 18px 50px rgb(30 35 45 / 28%);
  overflow: hidden;
}

.auth-card > :not(.brand) {
  margin-left: 28px;
  margin-right: 28px;
}

.auth-card > :last-child {
  margin-bottom: 28px;
}

.auth-card h1 {
  font-size: 20px;
  margin: 22px 28px 16px;
  text-shadow: 0 1px 0 #fff;
}

.auth-card .subtitle {
  color: var(--muted);
  font-size: 13.5px;
  margin: -14px 28px 20px;
}

/* ---------- 表單欄位 ---------- */
.field {
  margin-bottom: 16px;
}

.field label {
  display: block;
  font-size: 13px;
  font-weight: 700;
  margin-bottom: 6px;
  color: var(--text-2);
  text-shadow: 0 1px 0 rgb(255 255 255 / 70%);
}

.field input,
.field select {
  width: 100%;
}

/* ---------- 主要按鈕（深色金屬鍵） ---------- */
.btn-primary {
  width: 100%;
  min-height: 38px;
  padding: 0 15px;
  font-size: 14px;
  font-weight: 700;
  color: #fff;
  border: 1px solid #2c2f34;
  border-radius: var(--radius-sm);
  background: var(--metal-dark);
  text-shadow: 0 -1px 0 rgb(0 0 0 / 50%);
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 28%), 0 1px 3px rgb(0 0 0 / 35%);
}

.btn-primary:hover {
  background: var(--metal-dark-hover);
}

.btn-primary:active {
  background: linear-gradient(180deg, #44484e, #575b61);
  box-shadow: inset 0 2px 4px rgb(0 0 0 / 45%);
}

.btn-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* ---------- 錯誤訊息 ---------- */
.error-banner {
  background: var(--bad-soft);
  color: #8e1c1c;
  border: 1px solid var(--bad-line);
  border-radius: var(--radius-sm);
  padding: 10px 12px;
  font-size: 13px;
  margin-bottom: 16px;
}

.auth-switch {
  text-align: center;
  margin-top: 18px;
  font-size: 13px;
  color: var(--muted);
}

.auth-switch a {
  color: var(--accent);
  font-weight: 700;
  text-decoration: none;
}
__F54_EOF__

cat > "$FE/src/router/index.ts" << '__F54_EOF__'
import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/login',
      name: 'login',
      component: () => import('@/views/LoginView.vue'),
      meta: { public: true },
    },
    {
      path: '/register',
      name: 'register',
      component: () => import('@/views/RegisterHouseholdView.vue'),
      meta: { public: true },
    },
    // PAUSED: 忘記密碼功能已就緒,待 SMTP 基礎建設驗證後開放
    {
      path: '/forgot-password',
      name: 'forgot-password',
      component: () => import('@/views/ForgotPasswordView.vue'),
      meta: { public: true },
    },
    {
      path: '/reset-password',
      name: 'reset-password',
      component: () => import('@/views/ResetPasswordView.vue'),
      meta: { public: true },
    },
    {
      // 登入後的頁面共用 AppLayout(側欄 + 頂部列),原 Dashboard 的分頁改為子路由
      path: '/',
      component: () => import('@/layouts/AppLayout.vue'),
      children: [
        // 保留 name 'dashboard':LoginView、路由守衛都以此導向首頁
        { path: '', name: 'dashboard', redirect: { name: 'stats' } },
        { path: 'stats', name: 'stats', component: () => import('@/views/StatsView.vue'), meta: { title: '統計' } },
        {
          path: 'transactions',
          name: 'transactions',
          component: () => import('@/views/TransactionsView.vue'),
          meta: { title: '交易紀錄' },
        },
        { path: 'accounts', name: 'accounts', component: () => import('@/views/AccountsView.vue'), meta: { title: '帳戶' } },
        {
          path: 'categories',
          name: 'categories',
          component: () => import('@/views/CategoriesView.vue'),
          meta: { title: '分類' },
        },
        { path: 'tags', name: 'tags', component: () => import('@/views/TagsView.vue'), meta: { title: '消費品項' } },
        {
          path: 'transfer',
          name: 'transfer',
          component: () => import('@/views/TransferView.vue'),
          meta: { title: '匯入/匯出' },
        },
        { path: 'members', name: 'members', component: () => import('@/views/MembersView.vue'), meta: { title: '成員管理' } },
        {
          path: 'audit-logs',
          name: 'audit-logs',
          component: () => import('@/views/AuditLogView.vue'),
          meta: { title: '操作紀錄', requiresAdmin: true },
        },
      ],
    },
    // 未知路徑導回首頁(避免舊書籤或打錯網址出現空白頁)
    { path: '/:pathMatch(.*)*', redirect: { name: 'dashboard' } },
  ],
})

router.beforeEach((to) => {
  const auth = useAuthStore()
  if (!to.meta.public && !auth.isAuthenticated()) {
    return { name: 'login' }
  }
  if (to.meta.public && auth.isAuthenticated()) {
    return { name: 'dashboard' }
  }
  if (to.meta.requiresAdmin && auth.role !== 'admin') {
    return { name: 'dashboard' }
  }
  return true
})

export default router
__F54_EOF__

cat > "$FE/src/components/DateRangePicker.vue" << '__F54_EOF__'
<script setup lang="ts">
import { presetRange, type RangePreset } from '@/utils/date'

const startDate = defineModel<string>('startDate', { required: true })
const endDate = defineModel<string>('endDate', { required: true })

const PRESETS: { key: RangePreset; label: string }[] = [
  { key: 'thisMonth', label: '本月' },
  { key: 'lastMonth', label: '上月' },
  { key: 'last3Months', label: '近 3 個月' },
  { key: 'thisYear', label: '今年' },
]

function apply(key: RangePreset) {
  const r = presetRange(key)
  startDate.value = r.start
  endDate.value = r.end
}

function isActive(key: RangePreset): boolean {
  const r = presetRange(key)
  return r.start === startDate.value && r.end === endDate.value
}
</script>

<template>
  <div class="date-range">
    <input type="date" v-model="startDate" :max="endDate" aria-label="開始日期" />
    <span class="sep">~</span>
    <input type="date" v-model="endDate" :min="startDate" aria-label="結束日期" />
    <span class="presets">
      <button
        v-for="p in PRESETS"
        :key="p.key"
        type="button"
        class="btn sm"
        :class="{ on: isActive(p.key) }"
        :aria-pressed="isActive(p.key)"
        @click="apply(p.key)"
      >
        {{ p.label }}
      </button>
    </span>
  </div>
</template>

<style scoped>
.date-range { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.sep { color: var(--muted); font-weight: 700; }
.presets { display: inline-flex; gap: 6px; margin-left: 6px; }
</style>
__F54_EOF__

cat > "$FE/src/views/MembersView.vue" << '__F54_EOF__'
<script setup lang="ts">
import { onMounted, ref } from 'vue'
import {
  fetchMyHousehold,
  fetchMembers,
  addMember,
  deleteMember,
  updateHousehold,
  archiveHousehold,
  unarchiveHousehold,
} from '@/api/auth'
import { useAuthStore } from '@/stores/auth'
import type { HouseholdOut, UserOut } from '@/types/api'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'
import { validateHouseholdName } from '@/utils/validators'
import AppIcon from '@/components/AppIcon.vue'

const auth = useAuthStore()

const household = ref<HouseholdOut | null>(null)
const members = ref<UserOut[]>([])
const isLoading = ref(true)
const loadError = ref('')

// 帳本名稱編輯狀態(僅 admin 可編輯)
const editingName = ref(false)
const nameDraft = ref('')
const nameError = ref('')
const isSavingName = ref(false)

// 封存/解封狀態(僅 admin 可操作)
const isTogglingArchive = ref(false)

// 新增成員表單狀態
const showAddForm = ref(false)
const newName = ref('')
const newUsername = ref('')
const newEmail = ref('')
const newPassword = ref('')
const newRole = ref<'admin' | 'member'>('member')
const addError = ref('')
const isAdding = ref(false)

const USERNAME_PATTERN = /^[a-zA-Z0-9_.-]{3,50}$/

async function loadData() {
  try {
    const [householdData, membersData] = await Promise.all([fetchMyHousehold(), fetchMembers()])
    household.value = householdData
    members.value = membersData
  } catch {
    loadError.value = '載入資料失敗，請重新登入'
  } finally {
    isLoading.value = false
  }
}

onMounted(loadData)

function startEditName() {
  if (!household.value) return
  nameDraft.value = household.value.name
  nameError.value = ''
  editingName.value = true
}

function cancelEditName() {
  editingName.value = false
  nameError.value = ''
}

async function saveHouseholdName() {
  const err = validateHouseholdName(nameDraft.value)
  if (err) {
    nameError.value = err
    return
  }
  isSavingName.value = true
  try {
    const updated = await updateHousehold(nameDraft.value.trim())
    household.value = updated
    editingName.value = false
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    nameError.value = axiosErr.response?.data?.detail ?? '更新帳本名稱失敗'
  } finally {
    isSavingName.value = false
  }
}

async function handleArchive() {
  const otherMemberCount = members.value.filter((m) => m.id !== auth.userId).length
  if (otherMemberCount > 0) {
    loadError.value = '帳本內還有其他成員,只有最後一位成員時才能封存'
    return
  }
  if (!confirm('確定要封存這個帳本嗎?封存後僅能檢視,需由管理者解封才能恢復使用。')) return

  isTogglingArchive.value = true
  try {
    household.value = await archiveHousehold()
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    loadError.value = axiosErr.response?.data?.detail ?? '封存帳本失敗'
  } finally {
    isTogglingArchive.value = false
  }
}

async function handleUnarchive() {
  isTogglingArchive.value = true
  try {
    household.value = await unarchiveHousehold()
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    loadError.value = axiosErr.response?.data?.detail ?? '解封帳本失敗'
  } finally {
    isTogglingArchive.value = false
  }
}

async function handleDeleteMember(member: UserOut) {
  if (!confirm(`確定要刪除成員「${member.name}」嗎?此操作無法復原。`)) return
  try {
    await deleteMember(member.id)
    await loadData()
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    loadError.value = axiosErr.response?.data?.detail ?? '刪除成員失敗'
  }
}

function resetAddForm() {
  newName.value = ''
  newUsername.value = ''
  newEmail.value = ''
  newPassword.value = ''
  newRole.value = 'member'
  addError.value = ''
}

async function handleAddMember() {
  addError.value = ''

  if (!USERNAME_PATTERN.test(newUsername.value)) {
    addError.value = '帳號需為 3-50 字元，僅限英數、底線、句點、連字號'
    return
  }
  if (newPassword.value.length < 8) {
    addError.value = '密碼至少需要 8 個字元'
    return
  }

  isAdding.value = true
  try {
    await addMember({
      name: newName.value,
      username: newUsername.value,
      email: newEmail.value,
      password: newPassword.value,
      role: newRole.value,
    })
    resetAddForm()
    showAddForm.value = false
    await loadData() // 重新載入成員列表
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    addError.value = axiosErr.response?.data?.detail ?? '新增成員失敗'
  } finally {
    isAdding.value = false
  }
}
</script>

<template>
  <section v-if="household && !household.is_active" class="panel archived">
    <div class="panel-body">
      <h2>{{ household.name }}</h2>
      <p class="hint">此帳本已封存,目前僅能檢視,無法使用其他功能。</p>
      <div v-if="loadError" class="error-banner">{{ loadError }}</div>
      <button
        v-if="auth.role === 'admin'"
        class="btn primary"
        type="button"
        :disabled="isTogglingArchive"
        @click="handleUnarchive"
      >
        {{ isTogglingArchive ? '解封中…' : '解封帳本' }}
      </button>
    </div>
  </section>

  <template v-else>
    <section class="panel">
      <div class="panel-head">
        <h2 v-if="!editingName">
          <AppIcon name="book" />{{ household?.name ?? '載入中…' }}
          <button
            v-if="auth.role === 'admin' && household"
            class="btn ghost sm"
            type="button"
            @click="startEditName"
          >
            編輯
          </button>
        </h2>
        <div v-else class="name-edit">
          <div class="row">
            <input v-model="nameDraft" type="text" maxlength="50" aria-label="帳本名稱" @keyup.enter="saveHouseholdName" />
            <button class="btn primary sm" type="button" :disabled="isSavingName" @click="saveHouseholdName">
              {{ isSavingName ? '儲存中…' : '儲存' }}
            </button>
            <button class="btn sm" type="button" @click="cancelEditName">取消</button>
          </div>
          <span v-if="nameError" class="field-error">{{ nameError }}</span>
        </div>
        <span class="spacer"></span>
        <!-- 僅管理者可見:新增成員為 UX 便利,實際權限由後端 require_admin 把關 -->
        <button
          v-if="auth.role === 'admin' && !isLoading"
          class="btn sm"
          :class="{ on: showAddForm }"
          type="button"
          @click="showAddForm = !showAddForm"
        >
          {{ showAddForm ? '取消' : '+ 新增成員' }}
        </button>
      </div>

      <div class="panel-body">
        <div v-if="loadError" class="error-banner">{{ loadError }}</div>

        <form v-if="showAddForm" class="add-form" @submit.prevent="handleAddMember">
          <div v-if="addError" class="error-banner">{{ addError }}</div>

          <div class="field">
            <label for="new-name">姓名</label>
            <input id="new-name" v-model="newName" type="text" required maxlength="100" />
          </div>
          <div class="field">
            <label for="new-username">帳號</label>
            <input
              id="new-username"
              v-model="newUsername"
              type="text"
              required
              autocomplete="off"
              placeholder="登入用,例如 mom01"
            />
          </div>
          <div class="field">
            <label for="new-email">Email</label>
            <input id="new-email" v-model="newEmail" type="email" required autocomplete="off" />
          </div>
          <div class="field">
            <label for="new-password">初始密碼</label>
            <input
              id="new-password"
              v-model="newPassword"
              type="password"
              required
              minlength="8"
              autocomplete="new-password"
            />
          </div>
          <div class="field">
            <label for="new-role">權限</label>
            <select id="new-role" v-model="newRole">
              <option value="member">使用者</option>
              <option value="admin">管理者</option>
            </select>
          </div>
          <button class="btn primary" type="submit" :disabled="isAdding">
            {{ isAdding ? '新增中…' : '確認新增' }}
          </button>
        </form>

        <div v-if="!isLoading" class="table-wrap">
          <table class="grid">
            <thead>
              <tr>
                <th>姓名</th>
                <th>權限</th>
                <th class="num">操作</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="member in members" :key="member.id">
                <td>{{ member.name }}</td>
                <td>
                  <span class="pill" :class="{ ok: member.role === 'admin' }">
                    {{ member.role === 'admin' ? '管理者' : '使用者' }}
                  </span>
                </td>
                <td class="num">
                  <button
                    v-if="auth.role === 'admin' && member.id !== auth.userId"
                    class="btn danger sm"
                    type="button"
                    @click="handleDeleteMember(member)"
                  >
                    刪除
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>

    <section v-if="auth.role === 'admin' && !isLoading" class="panel">
      <div class="panel-body row">
        <button class="btn sm" type="button" :disabled="isTogglingArchive" @click="handleArchive">
          {{ isTogglingArchive ? '封存中…' : '封存此帳本' }}
        </button>
        <span class="hint">僅在帳本內只剩自己一位成員時可封存</span>
      </div>
    </section>
  </template>
</template>

<style scoped>
.archived { max-width: 520px; }
.archived h2 { margin: 0 0 6px; font-size: 18px; }
.archived .hint { margin: 0 0 18px; }
.panel-head h2 .btn { margin-left: 4px; }
.name-edit { display: flex; flex-direction: column; gap: 4px; }
.name-edit input { width: 240px; }
.field-error { color: var(--bad); font-size: 12px; }
.add-form {
  max-width: 420px;
  margin-bottom: 20px;
  padding-bottom: 20px;
  border-bottom: 1px dashed var(--line);
}
</style>
__F54_EOF__

cat > "$FE/src/views/AuditLogView.vue" << '__F54_EOF__'
<script setup lang="ts">
import { onMounted, ref, computed, watch } from 'vue'
import { fetchAuditLogs } from '@/api/auth'
import type { AuditLogOut } from '@/types/api'

const logs = ref<AuditLogOut[]>([])
const total = ref(0)
const limit = 20
const offset = ref(0)
const isLoading = ref(true)
const loadError = ref('')

const filterAction = ref('')
const filterResourceType = ref('')
const filterStartDate = ref('')
const filterEndDate = ref('')

const actionOptions = [
  { value: '', label: '全部動作' },
  { value: 'login', label: '登入' },
  { value: 'create', label: '新增' },
  { value: 'update', label: '修改' },
  { value: 'delete', label: '刪除' },
]
const resourceOptions = [
  { value: '', label: '全部對象' },
  { value: 'account', label: '帳戶' },
  { value: 'category', label: '分類' },
  { value: 'transaction', label: '交易' },
  { value: 'member', label: '成員' },
  { value: 'user', label: '使用者' },
]
const actionLabel: Record<string, string> = { login: '登入', create: '新增', update: '修改', delete: '刪除' }
const resourceLabel: Record<string, string> = {
  account: '帳戶', category: '分類', transaction: '交易', member: '成員', user: '使用者',
}

const currentPage = computed(() => Math.floor(offset.value / limit) + 1)
const totalPages = computed(() => Math.max(1, Math.ceil(total.value / limit)))

function formatTime(iso: string) {
  return new Date(iso).toLocaleString('zh-TW', { hour12: false })
}

async function loadLogs() {
  isLoading.value = true
  try {
    const page = await fetchAuditLogs(limit, offset.value, {
      action: filterAction.value || undefined,
      resource_type: filterResourceType.value || undefined,
      start_date: filterStartDate.value || undefined,
      end_date: filterEndDate.value || undefined,
    })
    logs.value = page.items
    total.value = page.total
  } catch {
    loadError.value = '載入操作紀錄失敗'
  } finally {
    isLoading.value = false
  }
}

function goToPage(page: number) {
  if (page < 1 || page > totalPages.value) return
  offset.value = (page - 1) * limit
  loadLogs()
}

watch([filterAction, filterResourceType, filterStartDate, filterEndDate], () => {
  offset.value = 0
  loadLogs()
})

onMounted(loadLogs)
</script>

<template>
  <section class="panel">
    <div class="panel-head">
      <div class="row filters">
        <select v-model="filterAction" aria-label="動作">
          <option v-for="opt in actionOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
        </select>
        <select v-model="filterResourceType" aria-label="對象">
          <option v-for="opt in resourceOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
        </select>
        <input v-model="filterStartDate" type="date" aria-label="開始日期" />
        <span class="sep">～</span>
        <input v-model="filterEndDate" type="date" aria-label="結束日期" />
      </div>
      <span class="spacer"></span>
      <span v-if="!isLoading" class="pill">共 {{ total }} 筆</span>
    </div>

    <div v-if="loadError" class="panel-body">
      <div class="error-banner">{{ loadError }}</div>
    </div>

    <div v-if="!isLoading && logs.length" class="table-wrap">
      <table class="grid">
        <thead>
          <tr>
            <th>時間</th>
            <th>操作人</th>
            <th>動作</th>
            <th>對象</th>
            <th>說明</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="log in logs" :key="log.id">
            <td class="nowrap">{{ formatTime(log.created_at) }}</td>
            <td>{{ log.actor_name ?? '（已刪除成員）' }}</td>
            <td class="nowrap">{{ actionLabel[log.action] ?? log.action }}</td>
            <td class="nowrap">{{ resourceLabel[log.resource_type] ?? log.resource_type }}</td>
            <td>{{ log.detail ?? '-' }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <p v-else-if="!isLoading" class="empty">查無符合條件的紀錄</p>

    <div v-if="!isLoading && total > 0" class="pager row">
      <button class="btn sm" type="button" :disabled="currentPage === 1" @click="goToPage(currentPage - 1)">上一頁</button>
      <span>{{ currentPage }} / {{ totalPages }}</span>
      <button class="btn sm" type="button" :disabled="currentPage === totalPages" @click="goToPage(currentPage + 1)">
        下一頁
      </button>
    </div>
  </section>
</template>

<style scoped>
.filters select { min-width: 120px; }
.sep { color: var(--muted); font-weight: 700; }
.pager { justify-content: center; padding: 14px; border-top: 1px solid var(--line-soft); font-size: 13px; }
</style>
__F54_EOF__

cat > "$FE/src/views/LoginView.vue" << '__F54_EOF__'
<script setup lang="ts">
import BrandBlock from '@/components/BrandBlock.vue'
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { login } from '@/api/auth'
import { useAuthStore } from '@/stores/auth'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const router = useRouter()
const auth = useAuthStore()

const username = ref('')
const password = ref('')
const errorMessage = ref('')
const isSubmitting = ref(false)

async function handleSubmit() {
  errorMessage.value = ''
  isSubmitting.value = true
  try {
    const { access_token } = await login({ username: username.value, password: password.value })
    auth.setToken(access_token)
    router.push({ name: 'dashboard' })
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    errorMessage.value = axiosErr.response?.data?.detail ?? '登入失敗，請確認網路連線'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="auth-page">
    <div class="auth-card">
      <BrandBlock />
      <h1>登入</h1>
      <p class="subtitle">家庭理財網站</p>

      <div v-if="errorMessage" class="error-banner">{{ errorMessage }}</div>

      <form @submit.prevent="handleSubmit">
        <div class="field">
          <label for="username">帳號</label>
          <input id="username" v-model="username" type="text" required autocomplete="username" />
        </div>
        <div class="field">
          <label for="password">密碼</label>
          <input id="password" v-model="password" type="password" required autocomplete="current-password" />
        </div>
        <button class="btn-primary" type="submit" :disabled="isSubmitting">
          {{ isSubmitting ? '登入中…' : '登入' }}
        </button>
      </form>

      <p class="auth-switch">
        <router-link to="/forgot-password">忘記密碼？</router-link>
      </p>
      <p class="auth-switch">
        還沒有家庭帳本？<router-link to="/register">建立新帳本</router-link>
      </p>
      <!-- TODO(paused): 忘記密碼功能已完成 API + 頁面(ForgotPasswordView/ResetPasswordView),
           待 SMTP 寄信基礎建設驗證穩定後再開放入口連結 -->
    </div>
  </div>
</template>
__F54_EOF__

cat > "$FE/src/views/RegisterHouseholdView.vue" << '__F54_EOF__'
<script setup lang="ts">
import BrandBlock from '@/components/BrandBlock.vue'
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { registerHousehold } from '@/api/auth'
import { useAuthStore } from '@/stores/auth'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const router = useRouter()
const auth = useAuthStore()

const householdName = ref('')
const adminName = ref('')
const adminUsername = ref('')
const adminEmail = ref('')
const adminPassword = ref('')
const errorMessage = ref('')
const isSubmitting = ref(false)

const USERNAME_PATTERN = /^[a-zA-Z0-9_.-]{3,50}$/

async function handleSubmit() {
  errorMessage.value = ''

  if (!USERNAME_PATTERN.test(adminUsername.value)) {
    errorMessage.value = '帳號需為 3-50 字元，僅限英數、底線、句點、連字號'
    return
  }
  if (adminPassword.value.length < 8) {
    errorMessage.value = '密碼至少需要 8 個字元'
    return
  }

  isSubmitting.value = true
  try {
    const { access_token } = await registerHousehold({
      household_name: householdName.value,
      admin_name: adminName.value,
      admin_username: adminUsername.value,
      admin_email: adminEmail.value,
      admin_password: adminPassword.value,
    })
    auth.setToken(access_token)
    router.push({ name: 'dashboard' })
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    errorMessage.value = axiosErr.response?.data?.detail ?? '建立失敗，請確認網路連線'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="auth-page">
    <div class="auth-card">
      <BrandBlock />
      <h1>建立家庭帳本</h1>
      <p class="subtitle">你將成為第一位管理者</p>

      <div v-if="errorMessage" class="error-banner">{{ errorMessage }}</div>

      <form @submit.prevent="handleSubmit">
        <div class="field">
          <label for="household-name">家庭帳本名稱</label>
          <input id="household-name" v-model="householdName" type="text" required maxlength="100" />
        </div>
        <div class="field">
          <label for="admin-name">你的姓名</label>
          <input id="admin-name" v-model="adminName" type="text" required maxlength="100" />
        </div>
        <div class="field">
          <label for="admin-username">帳號</label>
          <input
            id="admin-username"
            v-model="adminUsername"
            type="text"
            required
            autocomplete="username"
            placeholder="登入用,例如 dad01"
          />
        </div>
        <div class="field">
          <label for="admin-email">Email</label>
          <input
            id="admin-email"
            v-model="adminEmail"
            type="email"
            required
            autocomplete="email"
            placeholder="可與家人共用,忘記密碼時使用"
          />
        </div>
        <div class="field">
          <label for="admin-password">密碼</label>
          <input
            id="admin-password"
            v-model="adminPassword"
            type="password"
            required
            minlength="8"
            autocomplete="new-password"
          />
        </div>
        <button class="btn-primary" type="submit" :disabled="isSubmitting">
          {{ isSubmitting ? '建立中…' : '建立帳本' }}
        </button>
      </form>

      <p class="auth-switch">
        已經有帳本了？<router-link to="/login">登入</router-link>
      </p>
    </div>
  </div>
</template>
__F54_EOF__

cat > "$FE/src/views/ForgotPasswordView.vue" << '__F54_EOF__'
<script setup lang="ts">
import BrandBlock from '@/components/BrandBlock.vue'
import { ref } from 'vue'
import { forgotPassword } from '@/api/auth'

const email = ref('')
const isSubmitting = ref(false)
const isSubmitted = ref(false)
const errorMessage = ref('')

async function handleSubmit() {
  errorMessage.value = ''
  isSubmitting.value = true
  try {
    await forgotPassword(email.value)
    isSubmitted.value = true // 無論帳號是否存在,一律顯示成功,避免帳號列舉
  } catch {
    errorMessage.value = '發送失敗，請稍後再試'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="auth-page">
    <div class="auth-card">
      <BrandBlock />
      <template v-if="!isSubmitted">
        <h1>忘記密碼</h1>
        <p class="subtitle">輸入註冊時填寫的 email，我們會寄送重設連結</p>

        <div v-if="errorMessage" class="error-banner">{{ errorMessage }}</div>

        <form @submit.prevent="handleSubmit">
          <div class="field">
            <label for="email">Email</label>
            <input id="email" v-model="email" type="email" required autocomplete="email" />
          </div>
          <button class="btn-primary" type="submit" :disabled="isSubmitting">
            {{ isSubmitting ? '發送中…' : '發送重設信件' }}
          </button>
        </form>
      </template>

      <template v-else>
        <h1>信件已寄出</h1>
        <p class="subtitle">
          若該 email 有對應帳號，重設連結已寄至你的信箱。若家庭成員共用 email，信中會列出所有相關帳號。
        </p>
      </template>

      <p class="auth-switch">
        <router-link to="/login">返回登入</router-link>
      </p>
    </div>
  </div>
</template>
__F54_EOF__

cat > "$FE/src/views/ResetPasswordView.vue" << '__F54_EOF__'
<script setup lang="ts">
import BrandBlock from '@/components/BrandBlock.vue'
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { resetPassword } from '@/api/auth'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const route = useRoute()
const router = useRouter()

const token = (route.query.token as string) ?? ''
const newPassword = ref('')
const confirmPassword = ref('')
const errorMessage = ref('')
const isSubmitting = ref(false)
const isDone = ref(false)

async function handleSubmit() {
  errorMessage.value = ''

  if (!token) {
    errorMessage.value = '重設連結無效，請重新申請'
    return
  }
  if (newPassword.value.length < 8) {
    errorMessage.value = '密碼至少需要 8 個字元'
    return
  }
  if (newPassword.value !== confirmPassword.value) {
    errorMessage.value = '兩次輸入的密碼不一致'
    return
  }

  isSubmitting.value = true
  try {
    await resetPassword(token, newPassword.value)
    isDone.value = true
    setTimeout(() => router.push({ name: 'login' }), 2000)
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    errorMessage.value = axiosErr.response?.data?.detail ?? '重設失敗，請稍後再試'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="auth-page">
    <div class="auth-card">
      <BrandBlock />
      <template v-if="!isDone">
        <h1>設定新密碼</h1>

        <div v-if="!token" class="error-banner">連結無效，請重新申請忘記密碼</div>
        <div v-else-if="errorMessage" class="error-banner">{{ errorMessage }}</div>

        <form @submit.prevent="handleSubmit">
          <div class="field">
            <label for="new-password">新密碼</label>
            <input
              id="new-password"
              v-model="newPassword"
              type="password"
              required
              minlength="8"
              autocomplete="new-password"
            />
          </div>
          <div class="field">
            <label for="confirm-password">確認新密碼</label>
            <input
              id="confirm-password"
              v-model="confirmPassword"
              type="password"
              required
              minlength="8"
              autocomplete="new-password"
            />
          </div>
          <button class="btn-primary" type="submit" :disabled="isSubmitting || !token">
            {{ isSubmitting ? '處理中…' : '重設密碼' }}
          </button>
        </form>
      </template>

      <template v-else>
        <h1>密碼已重設</h1>
        <p class="subtitle">即將導向登入頁…</p>
      </template>
    </div>
  </div>
</template>
__F54_EOF__

# ---------- 刪除:原 Dashboard 已拆成各子路由頁面 ----------
git rm -q "$FE/src/views/DashboardView.vue"

# ---------- 驗證建置(失敗則還原前端改動,不 commit) ----------
echo "▶ npm install && npm run build(vue-tsc 型別檢查 + vite build)"
if ! ( cd "$FE" && npm install --no-audit --no-fund && npm run build ); then
  echo "❌ 建置失敗,還原本次前端改動" >&2
  git checkout HEAD -- "$FE/src"
  git clean -fdq -- "$FE/src"
  exit 1
fi

git add -A "$FE/src"
git commit -m "feat: 前端金屬主題 + 側欄版面,Dashboard 分頁改子路由;fix: 統計頁今天日期 UTC 偏移"

echo
git log --oneline -3
echo
git diff HEAD~1 --stat | tail -n 30
echo
echo "✅ 完成。確認無誤後:git push origin main && ./deploy.sh,瀏覽器 Ctrl+Shift+R"
