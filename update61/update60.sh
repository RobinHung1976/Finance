#!/usr/bin/env bash
# update60.sh — 前端改版 E2.5 + E3:剩餘元件改用金屬主題、統一圖表配色、移除 style.css 相容層
#   - 選擇器(CategoryPicker/TagPicker/三個篩選器)改用 theme.css 共用樣式(金屬鍵、選取為品牌綠)
#   - 統計:月收支趨勢改統計卡片;分類圓餅麵包屑改金屬鍵;品項排行/最大單筆排行改 LED 收支按鍵、長條依收支上色
#   - 新增 utils/chartTheme.ts(收支色、10 色分類色盤、Chart.js 全域字型/格線)
#   - 登入/註冊/忘記密碼/重設密碼、成員管理改用 theme.css class;刪除 src/style.css
# 執行位置:server 的 /root/apps(root)
set -euo pipefail

CURRENT=60
FE=ledger-frontend

# ---------- 前置驗證(不通過不寫入任何檔案) ----------
[ -d .git ] && [ -d "$FE/src" ] && [ -f deploy.sh ] \
  || { echo "❌ 請在 Finance repo 根目錄執行(需有 .git、$FE/src、deploy.sh)" >&2; exit 1; }
if ! git ls-files --error-unmatch docs/changelog-details/20261106-e2-pages-restyle.md >/dev/null 2>&1; then
  echo "❌ 尚未包含 update59.sh 的改動,請先確認 update59.sh 是否已成功套用" >&2; exit 1
fi
if git ls-files --error-unmatch "$FE/src/utils/chartTheme.ts" >/dev/null 2>&1; then
  echo "❌ 已套用過本次更新(chartTheme.ts 已在版控中),不需重跑" >&2; exit 1
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
check_sha src/main.ts 4faed25b4eb3956b0e761397890e5b572c040671a804423a0fddfcf4c2074f16
check_sha src/styles/theme.css fea1579a5a622dd8123a286b66f103007db96d5c234bd3db5b2ddb083060fc3a
check_sha src/components/AccountFilterPicker.vue c957bf2fadc6083cf30a91cb7e6fc93527a9300f975b52d58ff66792f6143adf
check_sha src/components/CategoryBreakdownChart.vue cc365638b6f560cebe1cd0a8c1931a8c6330af1f5a6eeb90954458fa5b699c95
check_sha src/components/CategoryFilterPicker.vue 21a0eced3677b460ae7fbfcb93313a5f90f3b3a6dc62d1b6b3d33f1919d349c2
check_sha src/components/CategoryList.vue 022c6083177231413ab313a38b5b2ef91bf0ae02023eee2c477594611d5e7be0
check_sha src/components/CategoryPicker.vue 22dd60788440ce37bf9ec92c75074397faf8d6c3eeb378979917f764bb87128e
check_sha src/components/MonthlyTrendChart.vue ab24668da41944d0d16a96181b6422c466ebccca420694c38bb1f2e873c35e90
check_sha src/components/TagBreakdownChart.vue 9fb0161b4ae4b508ac42c3a9e06df73b27fb568b41c97c6d8d89f4df49f0752b
check_sha src/components/TagFilterPicker.vue e7589c3671508d410ca1d49080b53afbf3a49977078eceafc2116b283c61c1ec
check_sha src/components/TagPicker.vue 42c28d2f57752e1a6c85bd3b281b1994361b19ab94406ec5ae189146d7100ee4
check_sha src/components/TopTransactionsList.vue 417846618ef598cff826f53903d82e83dabd6f899344356eb66f376ed6733f89
check_sha src/components/TransactionFormDialog.vue 6d1a51d8efa4f1a0a42bb9ec53ce8a0b3364d43fa390aa069518112898e7af33
check_sha src/components/TransactionList.vue 558d63ac6422ecab59d543032f0ef475c3e9cc3b6612da938c6094eae5cf139f
check_sha src/views/ForgotPasswordView.vue 0de03b1c4d26dc293ce7892767f2633aef811ea2f0f5210a76bc5029124e8c19
check_sha src/views/LoginView.vue ceee2346a30d8743bd1bb443cf2f3202bdd403dcb1f5c9d174d23f62ab7f9ed2
check_sha src/views/MembersView.vue 39227075a11114d06c6ff4f9132c93184ac3f39d3bf36433f05141ae51212878
check_sha src/views/RegisterHouseholdView.vue 9622bdc0b74593179620bdf41340355f4c8aae0fe1adff745bdea949ada1c0dc
check_sha src/views/ResetPasswordView.vue e5219065be130ceb7b885920b4bcfa3b9e1339abb4ff321de92877f7d5de5d7a
check_sha src/style.css d173dd855ab52763a85d7d565d3b5a19a6876be490060176cb11666ad0afce1f
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
mkdir -p "$FE/src/utils"
cat > "$FE/src/utils/chartTheme.ts" << '__F60_EOF__'
import { Chart } from 'chart.js'

// 圖表配色:與 styles/theme.css 的 --c-income / --c-expense 同值(Chart.js 畫在 canvas 上,讀不到 CSS 變數)
export const CHART_COLORS = {
  income: '#1f8a4c',
  expense: '#b8391a',
  /** 「本分類直接交易(未再細分)」等中性項目 */
  neutral: '#9CA3AF',
  text: '#30363e',
  grid: 'rgba(30, 35, 45, 0.10)',
} as const

// 分類色盤:10 色,彼此色相分開、明度相近,在金屬灰底上皆可辨識;避開純紅綠以免與收支色混淆
export const CATEGORY_PALETTE = [
  '#2f7d68', '#3b6ea8', '#c8892e', '#8a5ab0', '#c0504d',
  '#4a9bb5', '#6f8f2e', '#b5657e', '#5c6f86', '#a0703c',
] as const

export function paletteColor(index: number): string {
  return CATEGORY_PALETTE[index % CATEGORY_PALETTE.length]
}

/** '#rrggbb' + 透明度(0~1)→ rgba() */
export function withAlpha(hex: string, alpha: number): string {
  const n = Number.parseInt(hex.slice(1), 16)
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${alpha})`
}

// 全域預設:字型、文字色、格線色(模組載入時套用一次)
Chart.defaults.font.family = '"Segoe UI", "Noto Sans TC", "Microsoft JhengHei", "PingFang TC", system-ui, sans-serif'
Chart.defaults.color = CHART_COLORS.text
Chart.defaults.borderColor = CHART_COLORS.grid
__F60_EOF__

cat > "$FE/src/main.ts" << '__F60_EOF__'
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import './styles/theme.css'

const app = createApp(App)
app.use(createPinia())
app.use(router)
app.mount('#app')
__F60_EOF__

cat > "$FE/src/styles/theme.css" << '__F60_EOF__'
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
:is(.category-picker, .tag-picker) .add-btn {
  color: var(--accent); text-shadow: none; border-style: dashed; border-color: var(--field-line); background: transparent; box-shadow: none;
}
:is(.category-picker, .tag-picker) .add-btn:hover { background: rgb(255 255 255 / 70%); }
:is(.category-picker, .tag-picker) .create-form { display: flex; gap: 8px; margin-top: 10px; }
:is(.category-picker, .tag-picker) .create-form input { flex: 1; min-width: 0; }
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
__F60_EOF__

cat > "$FE/src/components/AccountFilterPicker.vue" << '__F60_EOF__'
<script setup lang="ts">
import { computed, ref } from 'vue'
import type { AccountOut } from '@/types/ledger'

const props = defineProps<{
  accounts: AccountOut[]
  modelValue: string
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

const searchQuery = ref('')

const filteredAccounts = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  const list = q ? props.accounts.filter((a) => a.name.toLowerCase().includes(q)) : props.accounts
  return [...list].sort((a, b) => a.name.localeCompare(b.name))
})

function selectAccount(id: string) {
  emit('update:modelValue', id)
}
function clearSelection() {
  emit('update:modelValue', '')
}
</script>

<template>
  <div class="filter-picker-box">
    <input v-model="searchQuery" type="search" class="search-input" placeholder="搜尋帳戶…" />
    <div class="option-grid">
      <button type="button" class="option-btn" :class="{ selected: !modelValue }" @click="clearSelection">
        所有帳戶
      </button>
      <button
        v-for="a in filteredAccounts"
        :key="a.id"
        type="button"
        class="option-btn"
        :class="{ selected: a.id === modelValue }"
        @click="selectAccount(a.id)"
      >
        {{ a.name }}
      </button>
      <p v-if="filteredAccounts.length === 0" class="no-result">沒有符合的帳戶</p>
    </div>
  </div>
</template>
__F60_EOF__

cat > "$FE/src/components/CategoryBreakdownChart.vue" << '__F60_EOF__'
<script setup lang="ts">
import { ref, nextTick, onMounted, onBeforeUnmount, watch } from 'vue'
import Chart from 'chart.js/auto'
import { fetchCategoryBreakdown } from '@/api/ledgerApi'
import type { CategoryBreakdownOut, EntryType } from '@/types/ledger'
import { CHART_COLORS, paletteColor } from '@/utils/chartTheme'

const props = withDefaults(defineProps<{ type?: EntryType; startDate: string; endDate: string }>(), {
  type: 'expense',
})

const breadcrumb = ref<{ id: string; name: string }[]>([])
const canvasRef = ref<HTMLCanvasElement | null>(null)
const data = ref<CategoryBreakdownOut | null>(null)
const errorMsg = ref('')
let chartInstance: Chart | null = null

// 「本分類直接交易(未再細分)」固定用中性灰,跟一般子分類的彩色區隔開來
const SELF_COLOR = CHART_COLORS.neutral

function formatCurrency(v: number): string {
  return v.toLocaleString('zh-TW', { style: 'currency', currency: 'TWD', maximumFractionDigits: 0 })
}

function currentParentId(): string | null {
  return breadcrumb.value.length ? breadcrumb.value[breadcrumb.value.length - 1].id : null
}

async function loadAndRender() {
  errorMsg.value = ''
  try {
    // rollup 固定 true:UI 不再提供切換,子分類一律捲到頂層
    data.value = await fetchCategoryBreakdown(props.type, props.startDate, props.endDate, currentParentId())
    await nextTick()
    requestAnimationFrame(renderChart) // 等瀏覽器完成 layout,避免 canvas 量到 0x0
  } catch {
    errorMsg.value = '載入分類統計失敗,請稍後再試'
  }
}

function drillInto(index: number) {
  if (!data.value) return
  const item = data.value.items[index]
  if (!item.has_children) return
  breadcrumb.value.push({ id: item.category_id, name: item.category_name })
  loadAndRender()
}

function goToLevel(index: number) {
  breadcrumb.value = index < 0 ? [] : breadcrumb.value.slice(0, index + 1)
  loadAndRender()
}

function renderChart() {
  if (!canvasRef.value || !data.value) return
  chartInstance?.destroy()

  const items = data.value.items
  chartInstance = new Chart(canvasRef.value, {
    type: 'doughnut',
    data: {
      labels: items.map((i) => i.category_name),
      datasets: [
        {
          data: items.map((i) => i.amount),
          backgroundColor: items.map((i, idx) => (i.is_self ? SELF_COLOR : paletteColor(idx))),
          borderColor: '#f4f5f7',
          borderWidth: 2,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      onClick: (_evt, elements) => {
        if (elements.length > 0) drillInto(elements[0].index)
      },
      onHover: (evt, elements) => {
        const target = evt.native?.target as HTMLElement | undefined
        if (!target) return
        const hoveringDrillable = elements.length > 0 && items[elements[0].index]?.has_children
        target.style.cursor = hoveringDrillable ? 'pointer' : 'default'
      },
      plugins: {
        legend: { position: 'bottom' },
        tooltip: {
          callbacks: {
            label: (ctx) => {
              const item = items[ctx.dataIndex]
              const hint = item.has_children ? '(點擊查看子分類)' : ''
              return `${item.category_name}: ${formatCurrency(item.amount)} (${item.percentage}%) ${hint}`
            },
          },
        },
      },
    },
  })
}

onMounted(loadAndRender)
onBeforeUnmount(() => chartInstance?.destroy())
watch(() => [props.type, props.startDate, props.endDate], () => {
  breadcrumb.value = []
  loadAndRender()
})
</script>

<template>
  <div class="category-breakdown">
    <nav class="crumbs" aria-label="分類層級">
      <button type="button" class="btn sm" :class="{ on: breadcrumb.length === 0 }" @click="goToLevel(-1)">頂層</button>
      <template v-for="(crumb, idx) in breadcrumb" :key="crumb.id">
        <span class="sep">›</span>
        <button type="button" class="btn sm" :class="{ on: idx === breadcrumb.length - 1 }" @click="goToLevel(idx)">
          {{ crumb.name }}
        </button>
      </template>
      <span class="hint">點圓餅區塊可查看子分類</span>
    </nav>
    <div v-if="errorMsg" class="error-banner">{{ errorMsg }}</div>
    <p v-else-if="data && data.items.length === 0" class="empty">此期間無資料</p>
    <div v-else class="chart-wrap"><canvas ref="canvasRef"></canvas></div>
    <p v-if="data && data.items.length > 0" class="total">總計 <span class="amount expense">{{ formatCurrency(data.total) }}</span></p>
  </div>
</template>

<style scoped>
.category-breakdown { display: flex; flex-direction: column; height: 100%; }
.crumbs { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; margin-bottom: 12px; }
.crumbs .hint { margin-left: 8px; }
.sep { color: var(--muted); font-weight: 700; }
.chart-wrap { position: relative; height: 320px; }
.total { margin: 10px 0 0; text-align: center; font-weight: 700; }
</style>
__F60_EOF__

cat > "$FE/src/components/CategoryFilterPicker.vue" << '__F60_EOF__'
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

function selectCategory(category: CategoryOut) {
  emit('update:modelValue', category.id)
  path.value.push(category)
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
            :class="{ active: idx === path.length - 1 }"
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
__F60_EOF__

cat > "$FE/src/components/CategoryList.vue" << '__F60_EOF__'
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
.ic-expense { color: var(--c-expense); }
.ic-income { color: var(--c-income); }
.intro { margin: 0 0 10px; }
.rename { flex-wrap: nowrap; }
.rename input { flex: 1; min-width: 160px; }
.field-error { color: var(--bad); font-size: 12px; white-space: nowrap; }
.tree { padding: 4px 0 8px; }
</style>
__F60_EOF__

cat > "$FE/src/components/CategoryPicker.vue" << '__F60_EOF__'
<script setup lang="ts">
import { computed, ref, watch } from 'vue'
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

function selectCategory(category: CategoryOut) {
  emit('update:modelValue', category.id)
  path.value.push(category)
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
  const isDuplicate = currentLevelCategories.value.some(
    (c) => c.name.trim().toLowerCase() === trimmedName.toLowerCase()
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
      parent_id: currentParentId.value,
    })
    emit('created', created)
    emit('update:modelValue', created.id)
    path.value.push(created)
    newCategoryName.value = ''
    showCreateForm.value = false
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    createError.value = axiosErr.response?.data?.detail ?? '新增失敗'
  } finally {
    isCreating.value = false
  }
}

const selectedCategoryName = computed(
  () => props.categories.find((c) => c.id === props.modelValue)?.name ?? ''
)
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
            :class="{ active: idx === path.length - 1 }"
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

        <button type="button" class="option-btn add-btn" @click="showCreateForm = !showCreateForm">
          + 新增分類
        </button>
      </div>
    </template>

    <form v-if="showCreateForm" class="create-form" @submit.prevent="handleCreate">
      <input v-model="newCategoryName" type="text" maxlength="100" placeholder="分類名稱" required />
      <button class="btn primary sm" type="submit" :disabled="isCreating">
        {{ isCreating ? '新增中…' : '確認' }}
      </button>
    </form>
    <div v-if="createError" class="error-banner">{{ createError }}</div>

    <template v-if="!hideSelectedHint">
      <p v-if="modelValue" class="selected-hint">已選擇：{{ selectedCategoryName }}</p>
      <p v-else class="selected-hint missing">尚未選擇分類</p>
    </template>
  </div>
</template>
__F60_EOF__

cat > "$FE/src/components/MonthlyTrendChart.vue" << '__F60_EOF__'
<script setup lang="ts">
import { ref, nextTick, onMounted, onBeforeUnmount, watch } from 'vue'
import Chart from 'chart.js/auto'
import { fetchMonthlyTrend } from '@/api/ledgerApi'
import type { MonthlyTrendOut } from '@/types/ledger'
import { CHART_COLORS, withAlpha } from '@/utils/chartTheme'

const props = defineProps<{ startDate: string; endDate: string }>()

const loading = ref(true)
const error = ref<string | null>(null)
const data = ref<MonthlyTrendOut | null>(null)

const canvasRef = ref<HTMLCanvasElement | null>(null)
let chartInstance: Chart | null = null

function formatCurrency(value: number | null): string {
  if (value === null) return '-'
  return value.toLocaleString('zh-TW', { style: 'currency', currency: 'TWD', maximumFractionDigits: 0 })
}

function renderChart() {
  if (!canvasRef.value || !data.value) return

  chartInstance?.destroy()

  const labels = data.value.months.map((m) => m.month)
  const incomeData = data.value.months.map((m) => m.income)
  const expenseData = data.value.months.map((m) => m.expense)

  chartInstance = new Chart(canvasRef.value, {
    type: 'line',
    data: {
      labels,
      datasets: [
        {
          label: '收入',
          data: incomeData,
          borderColor: CHART_COLORS.income,
          backgroundColor: withAlpha(CHART_COLORS.income, 0.12),
          tension: 0.3,
          fill: true,
        },
        {
          label: '支出',
          data: expenseData,
          borderColor: CHART_COLORS.expense,
          backgroundColor: withAlpha(CHART_COLORS.expense, 0.12),
          tension: 0.3,
          fill: true,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { position: 'top' },
        tooltip: {
          callbacks: {
            label: (ctx) => `${ctx.dataset.label}: ${formatCurrency(ctx.parsed.y)}`,
          },
        },
      },
      scales: {
        y: {
          ticks: { callback: (v) => formatCurrency(Number(v)) },
        },
      },
    },
  })
}

async function loadData() {
  loading.value = true
  error.value = null
  try {
    data.value = await fetchMonthlyTrend(props.startDate, props.endDate)
    await nextTick()
    requestAnimationFrame(renderChart) // 等瀏覽器完成 layout,避免 canvas 量到 0x0
  } catch (e) {
    error.value = '統計資料載入失敗,請稍後再試'
    console.error(e)
  } finally {
    loading.value = false
  }
}

watch(() => [props.startDate, props.endDate], loadData)

onMounted(loadData)
onBeforeUnmount(() => chartInstance?.destroy())
</script>

<template>
  <div class="trend">
    <div v-if="loading" class="empty">載入中…</div>
    <div v-else-if="error" class="error-banner">{{ error }}</div>
    <template v-else-if="data">
      <div class="stat-grid">
        <div class="stat">
          <div class="stat-label">總收入</div>
          <div class="stat-value income">{{ formatCurrency(data.total_income) }}</div>
        </div>
        <div class="stat">
          <div class="stat-label">總支出</div>
          <div class="stat-value expense">{{ formatCurrency(data.total_expense) }}</div>
        </div>
        <div class="stat">
          <div class="stat-label">結餘</div>
          <div class="stat-value" :class="data.total_balance >= 0 ? 'income' : 'expense'">
            {{ formatCurrency(data.total_balance) }}
          </div>
        </div>
      </div>
      <div class="chart-box">
        <div class="chart-wrap"><canvas ref="canvasRef"></canvas></div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.chart-box { margin-top: 16px; }
.chart-wrap { position: relative; height: 320px; }
</style>
__F60_EOF__

cat > "$FE/src/components/TagBreakdownChart.vue" << '__F60_EOF__'
<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { fetchTagBreakdown } from '@/api/ledgerApi'
import type { TagBreakdownItem } from '@/types/ledger'
import { formatCurrency } from '@/utils/ledgerLabels'

const props = defineProps<{
  startDate: string
  endDate: string
}>()

const items = ref<TagBreakdownItem[]>([])
const loading = ref(false)
const errorMsg = ref('')
const type = ref<'expense' | 'income'>('expense')

async function load() {
  loading.value = true
  errorMsg.value = ''
  try {
    const result = await fetchTagBreakdown(props.startDate, props.endDate, type.value)
    items.value = result.items
  } catch (e) {
    errorMsg.value = '載入消費品項排行失敗'
    items.value = []
  } finally {
    loading.value = false
  }
}

onMounted(load)
watch([() => props.startDate, () => props.endDate, type], load)

const maxAmount = computed(() =>
  items.value.length ? Math.max(...items.value.map((i) => i.total_amount)) : 1,
)
</script>

<template>
  <div class="tag-breakdown">
    <div class="header-row">
      <div class="keypad sm" role="radiogroup" aria-label="收支類型">
        <button type="button" role="radio" class="key" :class="{ active: type === 'expense' }" :aria-checked="type === 'expense'" @click="type = 'expense'">支出</button>
        <button type="button" role="radio" class="key" :class="{ active: type === 'income' }" :aria-checked="type === 'income'" @click="type = 'income'">收入</button>
      </div>
    </div>

    <p class="hint">
      依消費品項排行(單筆交易可能同時掛多個品項,故總和不等於{{ type === 'expense' ? '支出' : '收入' }}總額)
    </p>

    <div v-if="loading" class="empty">載入中…</div>
    <div v-else-if="errorMsg" class="error-banner">{{ errorMsg }}</div>
    <div v-else-if="items.length === 0" class="empty">此區間無已標記消費品項的交易</div>

    <div v-else class="bar-list">
      <div v-for="item in items" :key="item.tag_id" class="bar-row">
        <span class="label" :title="item.name">{{ item.name }}</span>
        <div class="bar-track">
          <div class="bar-fill" :class="type" :style="{ width: `${(item.total_amount / maxAmount) * 100}%` }" />
        </div>
        <span class="amount" :class="type">{{ formatCurrency(item.total_amount) }}</span>
        <span class="count">{{ item.transaction_count }} 筆</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.tag-breakdown { height: 360px; display: flex; flex-direction: column; overflow: hidden; }
.header-row { display: flex; justify-content: space-between; align-items: center; gap: 12px; margin-bottom: 6px; }
.keypad.sm { padding: 0; gap: 8px; }
.keypad.sm .key { height: 32px; padding: 0 14px 6px; font-size: 13px; }
.keypad.sm .key::after { left: 10px; right: 10px; bottom: 3px; height: 3px; }
.hint { margin: 4px 0 10px; }
.bar-list { flex: 1; overflow-y: auto; padding-right: 4px; }
.bar-track {
  height: 12px; overflow: hidden; border-radius: 6px; background: #d9dde2;
  box-shadow: inset 0 1px 2px rgb(0 0 0 / 25%), 0 1px 0 rgb(255 255 255 / 70%);
}
.bar-fill { height: 100%; border-radius: 6px; transition: width 0.3s ease; box-shadow: inset 0 1px 0 rgb(255 255 255 / 35%); }
.bar-fill.expense { background: linear-gradient(180deg, #d9603c, var(--c-expense)); }
.bar-fill.income { background: linear-gradient(180deg, #34a868, var(--c-income)); }
@media (prefers-reduced-motion: reduce) { .bar-fill { transition: none; } }
.bar-row { display: grid; grid-template-columns: 110px 1fr 110px 56px; align-items: center; gap: 10px; padding: 5px 0; }
.label { overflow: hidden; font-size: 13.5px; font-weight: 600; text-overflow: ellipsis; white-space: nowrap; }
.amount { font-size: 13.5px; text-align: right; }
.count { font-size: 12px; color: var(--muted); text-align: right; font-variant-numeric: tabular-nums; }
</style>
__F60_EOF__

cat > "$FE/src/components/TagFilterPicker.vue" << '__F60_EOF__'
<script setup lang="ts">
import { ref, computed } from 'vue'
import type { TagOut } from '@/types/ledger'

const RECENT_LIMIT = 8

const props = defineProps<{
  modelValue: string[]
  tags: TagOut[]
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string[]] }>()

const searchQuery = ref('')
const isSearching = computed(() => searchQuery.value.trim().length > 0)

const filteredTags = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return props.tags
  return props.tags.filter((t) => t.name.toLowerCase().includes(q))
})

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

function isSelected(id: string) {
  return props.modelValue.includes(id)
}
function toggleTag(id: string) {
  const next = isSelected(id) ? props.modelValue.filter((v) => v !== id) : [...props.modelValue, id]
  emit('update:modelValue', next)
}
function clearSelection() {
  emit('update:modelValue', [])
}
</script>

<template>
  <div class="filter-picker-box tags">
    <input v-model="searchQuery" type="search" class="search-input" placeholder="搜尋消費品項…" />

    <div class="option-grid">
      <button type="button" class="option-btn" :class="{ selected: modelValue.length === 0 }" @click="clearSelection">
        所有品項
      </button>
    </div>

    <template v-if="!isSearching">
      <div v-if="recentTags.length" class="tag-section-label">最近使用</div>
      <div v-if="recentTags.length" class="option-grid">
        <button
          v-for="t in recentTags"
          :key="t.id"
          type="button"
          class="option-btn"
          :class="{ selected: isSelected(t.id) }"
          @click="toggleTag(t.id)"
        >
          {{ t.name }}
        </button>
      </div>

      <div v-if="recentTags.length && otherTags.length" class="tag-section-label">全部品項</div>
      <div class="option-grid">
        <button
          v-for="t in otherTags"
          :key="t.id"
          type="button"
          class="option-btn"
          :class="{ selected: isSelected(t.id) }"
          @click="toggleTag(t.id)"
        >
          {{ t.name }}
        </button>
      </div>
    </template>

    <template v-else>
      <div class="option-grid">
        <button
          v-for="t in filteredTags"
          :key="t.id"
          type="button"
          class="option-btn"
          :class="{ selected: isSelected(t.id) }"
          @click="toggleTag(t.id)"
        >
          {{ t.name }}
        </button>
        <p v-if="filteredTags.length === 0" class="no-result">沒有符合的消費品項</p>
      </div>
    </template>
  </div>
</template>
__F60_EOF__

cat > "$FE/src/components/TagPicker.vue" << '__F60_EOF__'
<script setup lang="ts">
import { ref, computed } from 'vue'
import { createTag } from '@/api/ledgerApi'
import type { TagOut } from '@/types/ledger'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const RECENT_LIMIT = 8

const props = defineProps<{
  modelValue: string[]
  tags: TagOut[]
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
        <button type="button" class="tag-btn add-btn" @click="showCreateForm = !showCreateForm">
          + 新增品項
        </button>
      </div>
    </template>

    <template v-else>
      <div class="tag-grid">
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
        <button type="button" class="tag-btn add-btn" @click="showCreateForm = !showCreateForm">
          + 新增品項
        </button>
      </div>
    </template>

    <form v-if="showCreateForm" class="create-form" @submit.prevent="handleCreate">
      <input v-model="newTagName" type="text" maxlength="50" placeholder="品項名稱（例如：三媽）" required />
      <button class="btn primary sm" type="submit" :disabled="isCreating">
        {{ isCreating ? '新增中…' : '確認' }}
      </button>
    </form>
    <div v-if="createError" class="error-banner">{{ createError }}</div>
  </div>
</template>
__F60_EOF__

cat > "$FE/src/components/TopTransactionsList.vue" << '__F60_EOF__'
<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { fetchTopTransactions } from '@/api/ledgerApi'
import type { TopTransactionItem } from '@/types/ledger'
import { formatCurrency } from '@/utils/ledgerLabels'

const props = defineProps<{
  startDate: string
  endDate: string
}>()

const items = ref<TopTransactionItem[]>([])
const loading = ref(false)
const errorMsg = ref('')
const type = ref<'expense' | 'income'>('expense')
const limit = ref(5)

async function load() {
  loading.value = true
  errorMsg.value = ''
  try {
    const result = await fetchTopTransactions(props.startDate, props.endDate, type.value, limit.value)
    items.value = result.items
  } catch (e) {
    errorMsg.value = '載入最大單筆排行失敗'
    items.value = []
  } finally {
    loading.value = false
  }
}

onMounted(load)
watch([() => props.startDate, () => props.endDate, type, limit], load)

const maxAmount = computed(() =>
  items.value.length ? Math.max(...items.value.map((i) => i.amount)) : 1,
)
</script>

<template>
  <div class="top-transactions">
    <div class="header-row">
      <div class="keypad sm" role="radiogroup" aria-label="收支類型">
        <button type="button" role="radio" class="key" :class="{ active: type === 'expense' }" :aria-checked="type === 'expense'" @click="type = 'expense'">支出</button>
        <button type="button" role="radio" class="key" :class="{ active: type === 'income' }" :aria-checked="type === 'income'" @click="type = 'income'">收入</button>
      </div>
      <select v-model.number="limit" class="limit-select" aria-label="顯示筆數">
        <option :value="5">Top 5</option>
        <option :value="10">Top 10</option>
        <option :value="20">Top 20</option>
      </select>
    </div>

    <p class="hint">依單筆交易金額排行,不套用進階篩選(帳戶/分類/消費品項)</p>

    <div v-if="loading" class="empty">載入中…</div>
    <div v-else-if="errorMsg" class="error-banner">{{ errorMsg }}</div>
    <div v-else-if="items.length === 0" class="empty">此區間無交易</div>

    <div v-else class="bar-list">
      <div v-for="(item, index) in items" :key="item.id" class="bar-row">
        <span class="rank">{{ index + 1 }}</span>
        <div class="info">
          <div class="info-top">
            <span class="category" :title="item.category_name">{{ item.category_name }}</span>
            <span class="account" :title="item.account_name">{{ item.account_name }}</span>
          </div>
          <div class="bar-track">
            <div class="bar-fill" :class="type" :style="{ width: `${(item.amount / maxAmount) * 100}%` }" />
          </div>
        </div>
        <div class="right">
          <span class="amount" :class="type">{{ formatCurrency(item.amount) }}</span>
          <span class="date">{{ item.date }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.top-transactions { height: 360px; display: flex; flex-direction: column; overflow: hidden; }
.header-row { display: flex; justify-content: space-between; align-items: center; gap: 12px; margin-bottom: 6px; }
.keypad.sm { padding: 0; gap: 8px; }
.keypad.sm .key { height: 32px; padding: 0 14px 6px; font-size: 13px; }
.keypad.sm .key::after { left: 10px; right: 10px; bottom: 3px; height: 3px; }
.hint { margin: 4px 0 10px; }
.bar-list { flex: 1; overflow-y: auto; padding-right: 4px; }
.bar-track {
  height: 12px; overflow: hidden; border-radius: 6px; background: #d9dde2;
  box-shadow: inset 0 1px 2px rgb(0 0 0 / 25%), 0 1px 0 rgb(255 255 255 / 70%);
}
.bar-fill { height: 100%; border-radius: 6px; transition: width 0.3s ease; box-shadow: inset 0 1px 0 rgb(255 255 255 / 35%); }
.bar-fill.expense { background: linear-gradient(180deg, #d9603c, var(--c-expense)); }
.bar-fill.income { background: linear-gradient(180deg, #34a868, var(--c-income)); }
@media (prefers-reduced-motion: reduce) { .bar-fill { transition: none; } }
.limit-select { width: 110px; }
.bar-row { display: grid; grid-template-columns: 28px 1fr 120px; align-items: center; gap: 12px; padding: 8px 0; border-bottom: 1px solid var(--line-soft); }
.rank {
  display: grid; place-items: center; width: 24px; height: 24px; border-radius: 50%; font-size: 12px; font-weight: 800; color: var(--text-2);
  background: var(--metal-key); border: 1px solid #a9b0b8; box-shadow: inset 0 1px 0 #fff;
}
.info { min-width: 0; }
.info-top { display: flex; justify-content: space-between; gap: 8px; margin-bottom: 5px; font-size: 13.5px; }
.category { overflow: hidden; font-weight: 600; text-overflow: ellipsis; white-space: nowrap; }
.account { flex-shrink: 0; overflow: hidden; color: var(--muted); text-overflow: ellipsis; white-space: nowrap; }
.right { display: flex; flex-direction: column; align-items: flex-end; }
.amount { font-size: 14px; }
.date { font-size: 11.5px; color: var(--muted); font-variant-numeric: tabular-nums; }
</style>
__F60_EOF__

cat > "$FE/src/components/TransactionFormDialog.vue" << '__F60_EOF__'
<script setup lang="ts">
import { computed, ref } from 'vue'
import type { AxiosError } from 'axios'
import AppIcon from './AppIcon.vue'
import CategoryPicker from './CategoryPicker.vue'
import TagPicker from './TagPicker.vue'
import { createTransaction, updateTransaction } from '@/api/ledgerApi'
import { todayLocal } from '@/utils/date'
import type { AccountOut, CategoryOut, EntryType, TagOut, TransactionOut } from '@/types/ledger'
import type { ApiError } from '@/types/api'

const props = defineProps<{
  accounts: AccountOut[]
  categories: CategoryOut[]
  tags: TagOut[]
}>()

const emit = defineEmits<{
  saved: []
  categoryCreated: [category: CategoryOut]
  tagCreated: [tag: TagOut]
}>()

const dialogRef = ref<HTMLDialogElement | null>(null)
const editingId = ref<string | null>(null) // null = 新增模式

const type = ref<EntryType>('expense')
const accountId = ref('')
const categoryId = ref('')
const amount = ref<number | null>(null)
const date = ref(todayLocal())
const note = ref('')
const tagIds = ref<string[]>([])
const error = ref('')
const isSaving = ref(false)

const isEdit = computed(() => editingId.value !== null)

// 新增:沿用上一次新增的類型/帳戶/分類(連續記帳較快),其餘清空、日期重設為今天
function openCreate() {
  editingId.value = null
  date.value = todayLocal()
  amount.value = null
  note.value = ''
  tagIds.value = []
  error.value = ''
  if (!accountId.value || !props.accounts.some((a) => a.id === accountId.value)) {
    accountId.value = props.accounts.find((a) => a.is_default_expense)?.id ?? ''
  }
  dialogRef.value?.showModal()
}

function openEdit(tx: TransactionOut) {
  editingId.value = tx.id
  type.value = tx.type
  accountId.value = tx.account_id
  categoryId.value = tx.category_id
  amount.value = tx.amount
  date.value = tx.date
  note.value = tx.note ?? ''
  tagIds.value = tx.tags.map((t) => t.id)
  error.value = ''
  dialogRef.value?.showModal()
}

function close() {
  dialogRef.value?.close()
}

function setType(next: EntryType) {
  if (type.value === next) return
  type.value = next
  categoryId.value = '' // 收支類型的分類樹不同,切換後需重選
}

function validate(): string {
  if (!accountId.value) return '請選擇帳戶'
  if (!categoryId.value) return '請選擇分類'
  if (!amount.value || amount.value <= 0 || !Number.isInteger(amount.value)) return '金額必須是大於 0 的整數'
  if (!date.value) return '請選擇日期'
  return ''
}

async function handleSubmit() {
  error.value = validate()
  if (error.value) return

  const payload = {
    account_id: accountId.value,
    category_id: categoryId.value,
    amount: amount.value as number,
    type: type.value,
    date: date.value,
    note: note.value.trim() || null,
    tag_ids: tagIds.value,
  }

  isSaving.value = true
  try {
    if (editingId.value) {
      await updateTransaction(editingId.value, payload)
    } else {
      await createTransaction(payload)
    }
    close()
    emit('saved')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    error.value = axiosErr.response?.data?.detail ?? (isEdit.value ? '更新失敗' : '新增失敗')
  } finally {
    isSaving.value = false
  }
}

defineExpose({ openCreate, openEdit })
</script>

<template>
  <dialog ref="dialogRef" class="modal" aria-labelledby="tx-dialog-title">
    <form @submit.prevent="handleSubmit">
      <div class="panel-head">
        <h2 id="tx-dialog-title"><AppIcon :name="isEdit ? 'edit' : 'plus'" />{{ isEdit ? '編輯交易' : '新增交易' }}</h2>
        <span class="spacer"></span>
        <button type="button" class="btn ghost sm" aria-label="關閉" @click="close"><AppIcon name="x" /></button>
      </div>

      <div class="panel-body">
        <div v-if="error" class="error-banner" role="alert">{{ error }}</div>

        <div class="form-grid">
          <div class="form-field wide">
            <span class="label">收支類型</span>
            <div class="keypad" role="radiogroup" aria-label="收支類型">
              <button
                type="button"
                role="radio"
                class="key"
                :class="{ active: type === 'expense' }"
                :aria-checked="type === 'expense'"
                @click="setType('expense')"
              >
                <AppIcon name="expense" class="ic-expense" />支出
              </button>
              <button
                type="button"
                role="radio"
                class="key"
                :class="{ active: type === 'income' }"
                :aria-checked="type === 'income'"
                @click="setType('income')"
              >
                <AppIcon name="income" class="ic-income" />收入
              </button>
            </div>
          </div>

          <div class="form-field">
            <label for="tx-amount">金額</label>
            <input id="tx-amount" v-model.number="amount" type="number" min="1" step="1" required inputmode="numeric" />
          </div>
          <div class="form-field">
            <label for="tx-date">日期</label>
            <input id="tx-date" v-model="date" type="date" required />
          </div>
          <div class="form-field">
            <label for="tx-account">帳戶</label>
            <select id="tx-account" v-model="accountId" required>
              <option value="" disabled>請選擇帳戶</option>
              <option v-for="a in accounts" :key="a.id" :value="a.id">{{ a.name }}</option>
            </select>
          </div>
          <div class="form-field">
            <label for="tx-note">備註 <span class="hint">（選填）</span></label>
            <input id="tx-note" v-model="note" type="text" maxlength="500" />
          </div>

          <div class="form-field wide">
            <span class="label">分類</span>
            <CategoryPicker
              v-model="categoryId"
              :type="type"
              :categories="categories"
              @created="(c: CategoryOut) => emit('categoryCreated', c)"
            />
          </div>
          <div class="form-field wide">
            <span class="label">消費品項 <span class="hint">（選填）</span></span>
            <TagPicker v-model="tagIds" :tags="tags" @created="(t: TagOut) => emit('tagCreated', t)" />
          </div>
        </div>
      </div>

      <div class="modal-foot">
        <button type="button" class="btn" @click="close">取消</button>
        <button type="submit" class="btn primary" :disabled="isSaving">
          {{ isSaving ? '儲存中…' : isEdit ? '儲存' : '確認新增' }}
        </button>
      </div>
    </form>
  </dialog>
</template>

<style scoped>
.form-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
.keypad { padding: 0; }
.ic-expense { color: var(--c-expense); }
.ic-income { color: var(--c-income); }
</style>
__F60_EOF__

cat > "$FE/src/components/TransactionList.vue" << '__F60_EOF__'
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import type { AxiosError } from 'axios'
import AppIcon from './AppIcon.vue'
import CategoryFilterPicker from './CategoryFilterPicker.vue'
import AccountFilterPicker from './AccountFilterPicker.vue'
import TagFilterPicker from './TagFilterPicker.vue'
import TransactionFormDialog from './TransactionFormDialog.vue'
import { fetchAccounts, fetchCategories, fetchTags, fetchTransactions, deleteTransaction } from '@/api/ledgerApi'
import { formatCurrency, ENTRY_TYPE_LABEL } from '@/utils/ledgerLabels'
import { presetRange, toLocalISODate, todayLocal, type RangePreset } from '@/utils/date'
import { toCsv, downloadCsv } from '@/utils/csv'
import type { AccountOut, CategoryOut, EntryType, TagOut, TransactionOut } from '@/types/ledger'
import type { ApiError } from '@/types/api'

const PRESETS: { key: RangePreset; label: string }[] = [
  { key: 'thisMonth', label: '本月' },
  { key: 'lastMonth', label: '上月' },
  { key: 'last3Months', label: '近 3 個月' },
  { key: 'thisYear', label: '今年' },
]

const accounts = ref<AccountOut[]>([])
const categories = ref<CategoryOut[]>([])
const tags = ref<TagOut[]>([])
const transactions = ref<TransactionOut[]>([])
const isLoading = ref(true)
const loadError = ref('')

// ---------- 查詢條件(後端篩選,條件一變就重新查詢) ----------
const initialRange = presetRange('thisMonth')
const filterStartDate = ref(initialRange.start)
const filterEndDate = ref(initialRange.end)
const filterAccountId = ref('')
const filterCategoryId = ref('')
const filterTagIds = ref<string[]>([])
const filterMinAmount = ref<number | null>(null)
const filterMaxAmount = ref<number | null>(null)
const showAdvancedFilter = ref(false)

// ---------- 結果篩選(前端,不重新查詢) ----------
const typeFilter = ref<Record<EntryType, boolean>>({ expense: true, income: true })
const searchText = ref('')
type SortKey = 'date' | 'amount'
const sortKey = ref<SortKey>('date')
const sortDesc = ref(true)

const formDialog = ref<InstanceType<typeof TransactionFormDialog> | null>(null)

// ---------- 名稱查表 ----------
const accountById = computed(() => new Map(accounts.value.map((a) => [a.id, a])))
const categoryById = computed(() => new Map(categories.value.map((c) => [c.id, c])))

function accountName(id: string): string {
  return accountById.value.get(id)?.name ?? '（已刪除帳戶）'
}
function categoryName(id: string): string {
  const names: string[] = []
  const seen = new Set<string>() // 防呆:資料若出現循環 parent 不會卡死
  let current = categoryById.value.get(id)
  while (current && !seen.has(current.id)) {
    seen.add(current.id)
    names.unshift(current.name)
    current = current.parent_id ? categoryById.value.get(current.parent_id) : undefined
  }
  return names.length > 0 ? names.join(' - ') : '（已刪除分類）'
}

// ---------- 載入 ----------
async function loadReferenceData() {
  const [accountsData, categoriesData, tagsData] = await Promise.all([fetchAccounts(), fetchCategories(), fetchTags()])
  accounts.value = accountsData
  categories.value = categoriesData
  tags.value = tagsData
}

let requestSeq = 0 // 條件快速連續變動時,只採用最後一次查詢的結果
async function loadTransactions() {
  const seq = ++requestSeq
  isLoading.value = true
  loadError.value = ''
  try {
    const data = await fetchTransactions({
      start_date: filterStartDate.value || undefined,
      end_date: filterEndDate.value || undefined,
      account_id: filterAccountId.value || undefined,
      category_id: filterCategoryId.value || undefined,
      tag_ids: filterTagIds.value.length ? filterTagIds.value : undefined,
      min_amount: filterMinAmount.value ?? undefined,
      max_amount: filterMaxAmount.value ?? undefined,
    })
    if (seq === requestSeq) transactions.value = data
  } catch {
    if (seq === requestSeq) loadError.value = '載入交易紀錄失敗'
  } finally {
    if (seq === requestSeq) isLoading.value = false
  }
}

async function reloadAll() {
  try {
    await loadReferenceData()
  } catch {
    loadError.value = '載入帳戶/分類資料失敗'
  }
  await loadTransactions()
}

onMounted(reloadAll)

watch(
  [filterStartDate, filterEndDate, filterAccountId, filterCategoryId, filterTagIds, filterMinAmount, filterMaxAmount],
  loadTransactions,
)

// ---------- 查詢條件操作 ----------
function applyPreset(key: RangePreset) {
  const r = presetRange(key)
  filterStartDate.value = r.start
  filterEndDate.value = r.end
}
function isPresetActive(key: RangePreset): boolean {
  const r = presetRange(key)
  return r.start === filterStartDate.value && r.end === filterEndDate.value
}

const activeAdvancedFilterCount = computed(
  () => [filterAccountId.value, filterCategoryId.value, filterTagIds.value.length].filter(Boolean).length,
)

function toggleType(t: EntryType) {
  typeFilter.value = { ...typeFilter.value, [t]: !typeFilter.value[t] }
}

function clearFilters() {
  filterAccountId.value = ''
  filterCategoryId.value = ''
  filterTagIds.value = []
  filterMinAmount.value = null
  filterMaxAmount.value = null
  typeFilter.value = { expense: true, income: true }
  searchText.value = ''
}

// ---------- 結果 ----------
function searchableText(tx: TransactionOut): string {
  return [categoryName(tx.category_id), accountName(tx.account_id), tx.note ?? '', ...tx.tags.map((t) => t.name), String(tx.amount)]
    .join(' ')
    .toLowerCase()
}

const visibleTransactions = computed(() => {
  const keyword = searchText.value.trim().toLowerCase()
  const rows = transactions.value.filter(
    (tx) => typeFilter.value[tx.type] && (!keyword || searchableText(tx).includes(keyword)),
  )
  const dir = sortDesc.value ? -1 : 1
  // 後端已依日期新到舊排序;排序穩定(相同值維持原順序)
  return rows
    .map((tx, i) => ({ tx, i }))
    .sort((a, b) => {
      const diff =
        sortKey.value === 'amount' ? a.tx.amount - b.tx.amount : a.tx.date.localeCompare(b.tx.date)
      return diff !== 0 ? diff * dir : a.i - b.i
    })
    .map(({ tx }) => tx)
})

function setSort(key: SortKey) {
  if (sortKey.value === key) {
    sortDesc.value = !sortDesc.value
  } else {
    sortKey.value = key
    sortDesc.value = true
  }
}
function sortMark(key: SortKey): string {
  return sortKey.value === key ? (sortDesc.value ? ' ▼' : ' ▲') : ''
}

const totalIncome = computed(() =>
  visibleTransactions.value.filter((t) => t.type === 'income').reduce((sum, t) => sum + t.amount, 0),
)
const totalExpense = computed(() =>
  visibleTransactions.value.filter((t) => t.type === 'expense').reduce((sum, t) => sum + t.amount, 0),
)
const totalBalance = computed(() => accounts.value.reduce((sum, a) => sum + a.balance, 0))

function dateHint(isoDate: string): string {
  if (isoDate === todayLocal()) return '今天'
  const y = new Date()
  y.setDate(y.getDate() - 1)
  return isoDate === toLocalISODate(y) ? '昨天' : ''
}

// ---------- 新增 / 編輯 / 刪除 ----------
function openCreate() {
  formDialog.value?.openCreate()
}
function openEdit(tx: TransactionOut) {
  formDialog.value?.openEdit(tx)
}

async function handleDelete(tx: TransactionOut) {
  const label = `${tx.date} ${categoryName(tx.category_id)} ${formatCurrency(tx.amount)}`
  if (!confirm(`確定刪除此筆交易？\n${label}\n帳戶餘額將會回復。`)) return
  try {
    await deleteTransaction(tx.id)
    await reloadAll() // 帳戶餘額已變動
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    alert(axiosErr.response?.data?.detail ?? '刪除失敗')
  }
}

// ---------- 匯出 CSV(目前畫面上的結果,含前端篩選與排序) ----------
function exportCsv() {
  const header = ['日期', '類型', '分類', '帳戶', '消費品項', '備註', '金額', '收支(支出為負)']
  const rows = visibleTransactions.value.map((tx) => [
    tx.date,
    ENTRY_TYPE_LABEL[tx.type],
    categoryName(tx.category_id),
    accountName(tx.account_id),
    tx.tags.map((t) => t.name).join('、'),
    tx.note ?? '',
    tx.amount,
    tx.type === 'expense' ? -tx.amount : tx.amount,
  ])
  downloadCsv(`交易紀錄_${filterStartDate.value || '起'}_${filterEndDate.value || '今'}.csv`, toCsv(header, rows))
}
</script>

<template>
  <!-- ========== 查詢 ========== -->
  <section class="panel">
    <div class="panel-head">
      <h2><AppIcon name="search" />交易查詢</h2>
      <span class="spacer"></span>
      <button type="button" class="btn primary" @click="openCreate"><AppIcon name="plus" />新增交易</button>
    </div>
    <div class="panel-body">
      <div class="form-grid">
        <div class="form-field">
          <label for="q-start">開始日期</label>
          <input id="q-start" v-model="filterStartDate" type="date" :max="filterEndDate || undefined" />
        </div>
        <div class="form-field">
          <label for="q-end">結束日期</label>
          <input id="q-end" v-model="filterEndDate" type="date" :min="filterStartDate || undefined" />
        </div>
        <div class="form-field span2">
          <span class="label">快速選擇</span>
          <div class="row">
            <button
              v-for="p in PRESETS"
              :key="p.key"
              type="button"
              class="btn sm"
              :class="{ on: isPresetActive(p.key) }"
              :aria-pressed="isPresetActive(p.key)"
              @click="applyPreset(p.key)"
            >
              {{ p.label }}
            </button>
          </div>
        </div>

        <div class="form-field span2">
          <span class="label">類型</span>
          <div class="keypad" role="group" aria-label="收支類型">
            <button
              type="button"
              class="key"
              :class="{ active: typeFilter.expense }"
              :aria-pressed="typeFilter.expense"
              @click="toggleType('expense')"
            >
              <AppIcon name="expense" class="ic-expense" />支出
            </button>
            <button
              type="button"
              class="key"
              :class="{ active: typeFilter.income }"
              :aria-pressed="typeFilter.income"
              @click="toggleType('income')"
            >
              <AppIcon name="income" class="ic-income" />收入
            </button>
          </div>
        </div>
        <div class="form-field span2">
          <span class="label">金額區間</span>
          <div class="row nowrap">
            <input v-model.number="filterMinAmount" type="number" min="0" placeholder="最低金額" aria-label="最低金額" />
            <span class="sep">~</span>
            <input v-model.number="filterMaxAmount" type="number" min="0" placeholder="最高金額" aria-label="最高金額" />
          </div>
        </div>
      </div>

      <div class="row adv-row">
        <button
          type="button"
          class="btn sm"
          :class="{ on: showAdvancedFilter }"
          :aria-expanded="showAdvancedFilter"
          @click="showAdvancedFilter = !showAdvancedFilter"
        >
          <AppIcon name="filter" />進階篩選<template v-if="activeAdvancedFilterCount">（{{ activeAdvancedFilterCount }}）</template>
        </button>
        <span class="hint">帳戶、分類、消費品項</span>
        <span class="spacer"></span>
        <button type="button" class="btn ghost sm" @click="clearFilters"><AppIcon name="x" />清除條件</button>
      </div>

      <div v-if="showAdvancedFilter" class="adv-grid">
        <div class="form-field">
          <span class="label">帳戶</span>
          <AccountFilterPicker v-model="filterAccountId" :accounts="accounts" />
        </div>
        <div class="form-field">
          <span class="label">分類</span>
          <CategoryFilterPicker v-model="filterCategoryId" :categories="categories" />
        </div>
        <div class="form-field">
          <span class="label">消費品項</span>
          <TagFilterPicker v-model="filterTagIds" :tags="tags" />
        </div>
      </div>
    </div>
  </section>

  <!-- ========== 結果 ========== -->
  <section class="panel">
    <div class="panel-head">
      <h2><AppIcon name="table" />交易明細</h2>
      <span class="pill">{{ filterStartDate || '起' }} ~ {{ filterEndDate || '今' }}・{{ visibleTransactions.length }} 筆</span>
      <span class="spacer"></span>
      <button type="button" class="btn sm" :disabled="visibleTransactions.length === 0" @click="exportCsv">
        <AppIcon name="download" />匯出 CSV
      </button>
    </div>

    <div class="panel-body summary">
      <div class="stat-grid">
        <div class="stat">
          <div class="stat-label">筆數</div>
          <div class="stat-value">{{ visibleTransactions.length }}</div>
        </div>
        <div class="stat">
          <div class="stat-label">收入</div>
          <div class="stat-value income">{{ formatCurrency(totalIncome) }}</div>
        </div>
        <div class="stat">
          <div class="stat-label">支出</div>
          <div class="stat-value expense">{{ formatCurrency(totalExpense) }}</div>
        </div>
        <div class="stat">
          <div class="stat-label">結餘（收入 − 支出）</div>
          <div class="stat-value" :class="totalIncome - totalExpense < 0 ? 'expense' : 'income'">
            {{ formatCurrency(totalIncome - totalExpense) }}
          </div>
        </div>
        <div class="stat">
          <div class="stat-label">帳戶總餘額（目前）</div>
          <div class="stat-value">{{ formatCurrency(totalBalance) }}</div>
        </div>
      </div>
      <div v-if="accounts.length" class="row balances">
        <span class="hint">帳戶餘額</span>
        <span v-for="a in accounts" :key="a.id" class="pill" :class="{ bad: a.balance < 0 }">
          {{ a.name }}：<b>{{ formatCurrency(a.balance) }}</b>
        </span>
      </div>
    </div>

    <div class="toolbar">
      <input v-model="searchText" type="search" placeholder="搜尋 分類 / 帳戶 / 品項 / 備註 / 金額" aria-label="搜尋" />
      <span v-if="isLoading" class="hint">載入中…</span>
    </div>

    <div v-if="loadError" class="panel-body">
      <div class="error-banner">{{ loadError }}</div>
    </div>

    <div v-if="visibleTransactions.length" class="table-wrap">
      <table class="grid">
        <thead>
          <tr>
            <th class="sortable" @click="setSort('date')">日期{{ sortMark('date') }}</th>
            <th>類型</th>
            <th>分類</th>
            <th>帳戶</th>
            <th>消費品項</th>
            <th>備註</th>
            <th class="num sortable" @click="setSort('amount')">金額{{ sortMark('amount') }}</th>
            <th class="num">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="tx in visibleTransactions" :key="tx.id">
            <td class="nowrap">
              {{ tx.date }}<span v-if="dateHint(tx.date)" class="date-hint">{{ dateHint(tx.date) }}</span>
            </td>
            <td><span class="badge" :class="tx.type">{{ ENTRY_TYPE_LABEL[tx.type] }}</span></td>
            <td class="cat">{{ categoryName(tx.category_id) }}</td>
            <td class="nowrap">{{ accountName(tx.account_id) }}</td>
            <td class="tags"><span v-for="t in tx.tags" :key="t.id" class="chip">{{ t.name }}</span></td>
            <td class="note">{{ tx.note ?? '' }}</td>
            <td class="num">
              <span class="amount" :class="tx.type">
                {{ tx.type === 'income' ? '+' : '-' }}{{ formatCurrency(tx.amount) }}
              </span>
            </td>
            <td class="actions">
              <button type="button" class="btn sm" @click="openEdit(tx)"><AppIcon name="edit" />編輯</button>
              <button type="button" class="btn danger sm" @click="handleDelete(tx)"><AppIcon name="trash" />刪除</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p v-else-if="!isLoading && !loadError" class="empty">沒有符合條件的交易紀錄。</p>
  </section>

  <TransactionFormDialog
    ref="formDialog"
    :accounts="accounts"
    :categories="categories"
    :tags="tags"
    @saved="reloadAll"
    @category-created="(c: CategoryOut) => categories.push(c)"
    @tag-created="(t: TagOut) => tags.push(t)"
  />
</template>

<style scoped>
.keypad { padding: 0; }
.ic-expense { color: var(--c-expense); }
.ic-income { color: var(--c-income); }
.row.nowrap { flex-wrap: nowrap; }
.row.nowrap input { min-width: 0; flex: 1; }
.sep { color: var(--muted); font-weight: 700; }
.adv-row { margin-top: 16px; padding-top: 14px; border-top: 1px dashed var(--line); }
.adv-row .spacer { flex: 1; }
.adv-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 16px; margin-top: 14px; }
.summary { padding-bottom: 14px; }
.balances { margin-top: 12px; }
.balances b { font-variant-numeric: tabular-nums; }
.date-hint { margin-left: 6px; font-size: 11.5px; font-weight: 700; color: var(--accent); }
.cat { min-width: 120px; }
.tags { min-width: 90px; }
.note { min-width: 120px; max-width: 320px; white-space: normal; word-break: break-word; color: var(--text-2); }
</style>
__F60_EOF__

cat > "$FE/src/views/ForgotPasswordView.vue" << '__F60_EOF__'
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
      <div class="auth-body">
      <template v-if="!isSubmitted">
        <h1>忘記密碼</h1>
        <p class="subtitle">輸入註冊時填寫的 email，我們會寄送重設連結</p>

        <div v-if="errorMessage" class="error-banner">{{ errorMessage }}</div>

        <form class="stack-form" @submit.prevent="handleSubmit">
          <div class="form-field">
            <label for="email">Email</label>
            <input id="email" v-model="email" type="email" required autocomplete="email" />
          </div>
          <button class="btn primary block" type="submit" :disabled="isSubmitting">
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
  </div>
</template>
__F60_EOF__

cat > "$FE/src/views/LoginView.vue" << '__F60_EOF__'
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
      <div class="auth-body">
      <h1>登入</h1>
      <p class="subtitle">家庭理財網站</p>

      <div v-if="errorMessage" class="error-banner">{{ errorMessage }}</div>

      <form class="stack-form" @submit.prevent="handleSubmit">
        <div class="form-field">
          <label for="username">帳號</label>
          <input id="username" v-model="username" type="text" required autocomplete="username" />
        </div>
        <div class="form-field">
          <label for="password">密碼</label>
          <input id="password" v-model="password" type="password" required autocomplete="current-password" />
        </div>
        <button class="btn primary block" type="submit" :disabled="isSubmitting">
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
  </div>
</template>
__F60_EOF__

cat > "$FE/src/views/MembersView.vue" << '__F60_EOF__'
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

        <form v-if="showAddForm" class="add-form stack-form" @submit.prevent="handleAddMember">
          <div v-if="addError" class="error-banner">{{ addError }}</div>

          <div class="form-field">
            <label for="new-name">姓名</label>
            <input id="new-name" v-model="newName" type="text" required maxlength="100" />
          </div>
          <div class="form-field">
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
          <div class="form-field">
            <label for="new-email">Email</label>
            <input id="new-email" v-model="newEmail" type="email" required autocomplete="off" />
          </div>
          <div class="form-field">
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
          <div class="form-field">
            <label for="new-role">權限</label>
            <select id="new-role" v-model="newRole">
              <option value="member">使用者</option>
              <option value="admin">管理者</option>
            </select>
          </div>
          <div>
            <button class="btn primary" type="submit" :disabled="isAdding">
              {{ isAdding ? '新增中…' : '確認新增' }}
            </button>
          </div>
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
__F60_EOF__

cat > "$FE/src/views/RegisterHouseholdView.vue" << '__F60_EOF__'
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
      <div class="auth-body">
      <h1>建立家庭帳本</h1>
      <p class="subtitle">你將成為第一位管理者</p>

      <div v-if="errorMessage" class="error-banner">{{ errorMessage }}</div>

      <form class="stack-form" @submit.prevent="handleSubmit">
        <div class="form-field">
          <label for="household-name">家庭帳本名稱</label>
          <input id="household-name" v-model="householdName" type="text" required maxlength="100" />
        </div>
        <div class="form-field">
          <label for="admin-name">你的姓名</label>
          <input id="admin-name" v-model="adminName" type="text" required maxlength="100" />
        </div>
        <div class="form-field">
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
        <div class="form-field">
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
        <div class="form-field">
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
        <button class="btn primary block" type="submit" :disabled="isSubmitting">
          {{ isSubmitting ? '建立中…' : '建立帳本' }}
        </button>
      </form>

      <p class="auth-switch">
        已經有帳本了？<router-link to="/login">登入</router-link>
      </p>
      </div>
    </div>
  </div>
</template>
__F60_EOF__

cat > "$FE/src/views/ResetPasswordView.vue" << '__F60_EOF__'
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
      <div class="auth-body">
      <template v-if="!isDone">
        <h1>設定新密碼</h1>

        <div v-if="!token" class="error-banner">連結無效，請重新申請忘記密碼</div>
        <div v-else-if="errorMessage" class="error-banner">{{ errorMessage }}</div>

        <form class="stack-form" @submit.prevent="handleSubmit">
          <div class="form-field">
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
          <div class="form-field">
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
          <button class="btn primary block" type="submit" :disabled="isSubmitting || !token">
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
  </div>
</template>
__F60_EOF__

git rm -q "$FE/src/style.css"

# ---------- 驗證建置(失敗則還原前端改動,不 commit) ----------
echo "▶ npm install && npm run build(vue-tsc 型別檢查 + vite build)"
if ! ( cd "$FE" && npm install --no-audit --no-fund && npm run build ); then
  echo "❌ 建置失敗,還原本次前端改動" >&2
  git checkout HEAD -- "$FE/src"
  git clean -fdq -- "$FE/src"
  exit 1
fi

git add -A "$FE/src"
git commit -m "feat: 選擇器/統計元件/登入頁改用金屬主題,統一圖表配色(chartTheme.ts),移除 style.css 相容層"

echo
git log --oneline -3
echo
git diff HEAD~1 --stat | tail -n 30
echo
echo "✅ 完成。確認無誤後:git push origin main && ./deploy.sh,瀏覽器 Ctrl+Shift+R"
