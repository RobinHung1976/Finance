#!/usr/bin/env bash
# update55.sh — 文件:前端改版(update54)紀錄 —— 新增 feature-ui-theme.md、changelog-details,
#               同步 CHANGELOG / PROJECT-OVERVIEW / feature-household / feature-stats
# 執行位置:server 的 /root/apps(root)
set -euo pipefail

CURRENT=55

# ---------- 前置驗證(不通過不寫入任何檔案) ----------
[ -d .git ] && [ -f docs/PROJECT-OVERVIEW.md ] \
  || { echo "❌ 請在 Finance repo 根目錄執行(需有 .git、docs/PROJECT-OVERVIEW.md)" >&2; exit 1; }
if ! grep -q "layouts/AppLayout.vue" ledger-frontend/src/router/index.ts; then
  echo "❌ 尚未包含 update54.sh 的改動,請先確認 update54.sh 是否已成功套用" >&2; exit 1
fi
if git ls-files --error-unmatch docs/features/feature-ui-theme.md >/dev/null 2>&1; then
  echo "❌ 已套用過本次更新(feature-ui-theme.md 已在版控中),不需重跑" >&2; exit 1
fi
if ! git diff --quiet HEAD -- docs || ! git diff --cached --quiet -- docs; then
  echo "❌ docs/ 有未 commit 的修改,請先處理後再執行" >&2; exit 1
fi

# 精確字串比對:先全部檢查,全部對得上才寫入(--check 只檢查不寫)
cat > /tmp/update55_edits.py << 'PYEOF'
import sys
# 文件精確字串替換清單:(檔案, 舊字串, 新字串)
EDITS = [
 ('CHANGELOG.md', '## 2026-11\n\n',
  '## 2026-11\n\n- 11-06 feat/fix: 前端金屬主題 + 側欄版面(`AppLayout`),Dashboard 六個分頁改子路由;修正統計頁「今天」在台北 08:00 前變成前一天(`toISOString()` UTC) → [詳情](changelog-details/20261106-ui-metal-theme-layout.md)\n'),
 ('PROJECT-OVERVIEW.md', "| `feature-excel-import-export.md` | Excel 匯入/匯出 |\n",
  "| `feature-excel-import-export.md` | Excel 匯入/匯出 |\n| `feature-ui-theme.md` | 前端版面(側欄/子路由)、金屬主題、`theme.css` class 用法、改版進度 |\n"),
 ('PROJECT-OVERVIEW.md', "| `20261104-restore-drill-fix.md` |\n",
  "| `20261104-restore-drill-fix.md` |\n| `20261106-ui-metal-theme-layout.md` |\n"),
 ('PROJECT-OVERVIEW.md', "**選配 / 未定案**",
  "**前端改版(E,見 `features/feature-ui-theme.md`)**\n- [x] E0 Dashboard 分頁改子路由 + 側欄版面 `AppLayout`(2026-11-06)\n- [x] E1 金屬主題 `theme.css` + `style.css` 相容層(2026-11-06)\n- [ ] E2 逐頁清除 inline style/寫死色碼,完成後移除相容層(交易紀錄 → 帳戶 → 分類 → 消費品項 → 匯入匯出)\n- [ ] E3 圖表配色統一(`utils/chartTheme.ts`)\n- [~] 手機版——**擱置**(2026-11-06 決定先取消,如重啟需做抽屜選單或底部導覽列)\n\n**選配 / 未定案**"),
 ('features/feature-household.md',
  "| `src/views/DashboardView.vue` | 標題顯示實際 household 名稱(`onMounted` 呼叫 `fetchMyHousehold()`),API 失敗 fallback 顯示「家庭理財」 |\n",
  "| `src/layouts/AppLayout.vue` | 側欄「目前帳本」顯示實際 household 名稱(`onMounted` 呼叫 `fetchMyHousehold()`),API 失敗時顯示「載入中…」不阻斷畫面(原為 `DashboardView.vue` 標題,2026-11-06 改版後該檔已刪除,見 `feature-ui-theme.md`) |\n"),
 ('features/feature-household.md',
  "成員列表「刪除」按鈕(僅 admin,不可對自己顯示) |\n",
  "成員列表「刪除」按鈕(僅 admin,不可對自己顯示);路由 `/members`,登出與返回首頁由共用版面提供 |\n"),
 ('features/feature-household.md', "需擴充到路由層或 `DashboardView.vue`", "需擴充到路由層或 `AppLayout.vue`"),
 ('features/feature-household.md',
  "| 2026-07-08 | 帳本改名 + 防呆 + 封存/解封 + CLI 刪除 | `changelog-details/20260708-household-management.md` |\n",
  "| 2026-07-08 | 帳本改名 + 防呆 + 封存/解封 + CLI 刪除 | `changelog-details/20260708-household-management.md` |\n| 2026-11-06 | 前端改版:帳本名稱改在側欄顯示、成員管理頁移入共用版面 | `changelog-details/20261106-ui-metal-theme-layout.md` |\n"),
 ('features/feature-stats.md', "外加「今年」快捷按鈕回到預設值",
  "外加 本月/上月/近 3 個月/今年 快選按鈕(目前區間的按鈕呈按下狀態;日期一律以本地時區計算,見 `feature-ui-theme.md` 第四節)"),
 ('features/feature-stats.md',
  "四個統計子分頁(月收支趨勢/支出分類統計/消費品項排行/最大單筆排行)在「統計」tab 下以子分頁切換,共用同一組 `DateRangePicker`。",
  "四個統計子分頁(月收支趨勢/支出分類統計/消費品項排行/最大單筆排行)位於統計頁 `/stats`(`StatsView.vue`),以 LED 按鍵切換,共用同一組 `DateRangePicker`;子分頁與日期區間存在 Pinia store `statsFilter`,切到其他頁再回來會保留。預設區間今年 1/1 ~ 今天。"),
 ('features/feature-stats.md',
  "| 2026-08-10 | A9 最大單筆排行上線,統計頁新增第四個子分頁 | `changelog-details/20260810-a9-top-transactions.md` |\n",
  "| 2026-08-10 | A9 最大單筆排行上線,統計頁新增第四個子分頁 | `changelog-details/20260810-a9-top-transactions.md` |\n| 2026-11-06 | 統計頁改為 `/stats` 子路由、子分頁改 LED 按鍵、日期快選增加本月/上月/近 3 個月;修正「今天」UTC 偏移 | `changelog-details/20261106-ui-metal-theme-layout.md` |\n"),
]

check_only = '--check' in sys.argv
contents = {}
for f, old, new in EDITS:
    p = 'docs/' + f
    s = contents.get(p) or open(p, encoding='utf-8').read()
    n = s.count(old)
    if n != 1:
        print(f'❌ {p} 比對字串出現 {n} 次(應為 1):{old[:50]!r}', file=sys.stderr)
        sys.exit(1)
    contents[p] = s.replace(old, new)
if not check_only:
    for p, s in contents.items():
        open(p, 'w', encoding='utf-8').write(s)
print('✅ 文件比對' + ('通過' if check_only else '並寫入完成'))
PYEOF
python3 /tmp/update55_edits.py --check

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

# ---------- 既有文件:精確比對修改 ----------
python3 /tmp/update55_edits.py
rm -f /tmp/update55_edits.py

# ---------- 新文件:整份覆寫 ----------
mkdir -p docs/features docs/changelog-details
cat > 'docs/features/feature-ui-theme.md' << '__D55_EOF__'
# 功能現況:前端版面與主題(UI Theme / Layout)

## 一、範圍

- 全站金屬主題(拉絲鋼內容區、深色拉絲側欄、金屬面板與按鍵),品牌色墨綠 `#1f5f4f`(同 PWA `theme_color`)
- 登入後頁面共用側欄 + 頂部列版面(`AppLayout.vue`),功能頁一律為子路由
- 登入/註冊/忘記密碼/重設密碼頁的卡片上方顯示品牌列
- 只做桌面版;窄螢幕(≤ 860px)僅保留側欄疊到上方的基本樣式,完整手機版未做(見第六節)

## 二、路由與版面

| 路徑 | 頁面 | 說明 |
|---|---|---|
| `/` | — | 名稱 `dashboard`,導向 `/stats`(`LoginView`/`RegisterHouseholdView`/路由守衛都以 `dashboard` 導向首頁) |
| `/stats` | `StatsView.vue` | 四個統計子分頁 + 日期區間(見 `feature-stats.md`) |
| `/transactions` | `TransactionsView.vue` | 包 `TransactionList.vue` |
| `/accounts` | `AccountsView.vue` | 包 `AccountList.vue` |
| `/categories` | `CategoriesView.vue` | 包 `CategoryList.vue` |
| `/tags` | `TagsView.vue` | 包 `TagList.vue` |
| `/transfer` | `TransferView.vue` | 包 `ExcelImportExport.vue` |
| `/members` | `MembersView.vue` | 成員管理(見 `feature-household.md`) |
| `/audit-logs` | `AuditLogView.vue` | 操作紀錄,`meta.requiresAdmin`,非管理者導回首頁 |
| 其他未知路徑 | — | 導向 `dashboard` |

以上子路由的父路由為 `src/layouts/AppLayout.vue`,頁面標題取自 `route.meta.title`。

`AppLayout.vue` 內容:

| 區塊 | 說明 |
|---|---|
| 品牌列 | `BrandBlock.vue`:帳本圖示 +「家庭理財 / Household Finance Ledger」+「FINANCE LEDGER」琥珀色指示燈;登入類頁面共用同一元件 |
| 目前帳本 | `fetchMyHousehold()` 取得名稱,失敗時顯示「載入中…」不阻斷畫面;一個使用者只屬於一個帳本,不做切換清單 |
| 選單 | 報表(統計、交易紀錄)/ 帳務設定(帳戶、分類、消費品項、匯入/匯出)/ 帳本管理(成員管理、操作紀錄),「操作紀錄」僅 `role === 'admin'` 顯示;`router-link` 的 `active-class` 標示目前頁面 |
| 側欄底部 | 台北時間時鐘(`Intl.DateTimeFormat`,`timeZone: 'Asia/Taipei'`,每 15 秒更新) |
| 頂部列 | 頁面標題、登入身分(管理者/使用者)、登出按鈕 |

## 三、樣式檔案

| 檔案 | 說明 |
|---|---|
| `src/styles/theme.css` | 主題本體:`:root` 設計變數(金屬漸層、品牌色、狀態色、圓角、陰影)+ 版面(`.layout`/`.sidebar`/`.topbar`/`.content`)+ 元件 class |
| `src/style.css` | **相容層**:舊 class(`.btn-primary`/`.field`/`.error-banner`/`.auth-page`/`.auth-card`/`.auth-switch`)沿用名稱、改成金屬外觀;舊變數(`--color-primary`/`--color-border`/`--color-surface` …)對應到新變數。`main.ts` 先載入 `theme.css` 再載入本檔 |
| `src/components/AppIcon.vue` | 線條圖示元件(24×24 stroke),圖示路徑為檔內常數,`v-html` 不含使用者輸入 |

`theme.css` 的元件 class(新頁面/改版頁面請用這些,不要再寫 inline style):

| class | 用途 |
|---|---|
| `.panel` / `.panel-head` / `.panel-body` | 金屬面板;每個子路由頁面最外層都是 `.panel` |
| `.btn` / `.btn.primary` / `.btn.sm` / `.btn.ghost` / `.btn.danger` / `.btn.on` | 金屬按鍵;`.primary` 為深色鍵,`.on` 為按下狀態(如日期快選目前區間) |
| `.keypad` + `.key` / `.key.active` | 單選按鍵,底部 LED 燈條(未選灰、選取亮綠);用於統計子分頁 |
| `.grid`(table)+ `.num` / `.nowrap` | 金屬表頭表格,`.num` 數字右對齊等寬 |
| `.pill` / `.pill.ok` / `.warn` / `.bad`、`.household-badge` | 標籤 |
| `.hint` / `.empty` / `.row` / `.notice` / `.flash` | 輔助樣式 |
| 全域 `input` / `select` / `textarea` | 內凹金屬輸入框(元件 scoped style 仍可覆寫) |

## 四、日期工具

`src/utils/date.ts`:`todayLocal()`、`toLocalISODate()`、`presetRange('thisMonth' | 'lastMonth' | 'last3Months' | 'thisYear')`。**一律以瀏覽器本地時區組日期字串,不可用 `toISOString()`**(UTC,台北 00:00–07:59 會得到前一天)。`TransactionList.vue` 內另有同邏輯的 `todayLocalISODate()`,改版該頁時可改用此工具。

## 五、改版進度

| 階段 | 內容 | 狀態 |
|---|---|---|
| 第 0 步 | Dashboard 分頁改子路由 + `AppLayout` | ✅ 2026-11-06 |
| 第 1 步 | `theme.css` + 相容層 + 品牌列 + 統計頁/成員管理/操作紀錄套用新樣式 | ✅ 2026-11-06 |
| 第 2 步 | 逐頁清除 inline style 與寫死色碼,改用 `theme.css` class(交易紀錄 → 帳戶 → 分類 → 消費品項 → 匯入匯出);全部改完後移除 `style.css` 相容層 | 未開始 |
| 第 3 步 | 圖表配色統一(抽 `utils/chartTheme.ts`,三張圖表共用收入/支出色與分類色盤) | 未開始 |

## 六、已知限制 / 後續可考慮

1. 手機版未做(2026-11-06 決定先取消):窄螢幕時側欄整塊疊在內容上方,需捲動才看到內容;如重啟,需另做抽屜選單或底部導覽列,並關掉 `body` 的 `background-attachment: fixed`(iOS Safari 不支援且捲動易卡頓)
2. 第 2 步完成前,交易/帳戶/分類/消費品項/匯入匯出頁面內部仍是舊樣式(白色卡片 + inline style),外框已是金屬面板
3. `AppLayout` 與 `MembersView` 各自呼叫一次 `fetchMyHousehold()`;在成員管理頁改帳本名稱後,側欄名稱要重新整理才更新

## 七、沿革

| 日期 | 內容 | 詳情 |
|---|---|---|
| 2026-11-06 | 金屬主題 + 側欄版面上線,Dashboard 分頁改子路由(`update54.sh`) | `changelog-details/20261106-ui-metal-theme-layout.md` |
__D55_EOF__

cat > 'docs/changelog-details/20261106-ui-metal-theme-layout.md' << '__D55_EOF__'
# 2026-11-06 前端改版:金屬主題 + 側欄版面(第 0、1 步)

## 背景

想把前端改成與 Teams Call Report Web 版相同的金屬風格(拉絲鋼底、深色側欄、立體按鍵、LED 燈條),但不使用該專案的易通科技品牌。原本前端狀況:

- `App.vue` 只有 `<router-view />`,沒有共用版面;主要功能全在 `DashboardView.vue` 以 `ref` 切換六個分頁,不是路由
- 樣式分散:全域 `style.css` 2.3KB、23 個 `.vue` 檔共 135 處 inline style、約 25 種寫死色碼,混用 Finance 綠/Tailwind 灰/靛藍三套配色
- 完全沒有 `@media`

## 決策

| 項目 | 決定 | 理由 |
|---|---|---|
| 分頁 vs 路由 | 改為子路由(`/stats` 等),父路由 `AppLayout.vue` | 側欄可直接用 `router-link` 與 active 狀態;瀏覽器上一頁可用;PWA 可直接開到某頁 |
| 品牌色 | 墨綠金屬,基準 `#1f5f4f` | 本來就是 Finance 的主色與 PWA `theme_color`,同時與 TCR 的藍色區隔 |
| 品牌 | 「家庭理財 / Household Finance Ledger」+ 帳本圖示 | 不使用易通科技名稱與 ESi 字標 |
| 手機版 | 先不做 | 僅保留窄螢幕側欄疊上方的基本樣式,避免手機上完全擠壞 |
| 舊 class 衝突 | 不改名,`style.css` 改為相容層 | 原規劃把 12 個檔案的 `.btn-primary`/`.field` 換成 TCR 命名;實作時改為沿用舊名稱、換金屬外觀,這次就不必動元件檔,降低風險,留到第 2 步逐頁整理時再換 |
| 統計頁篩選狀態 | 放 Pinia store(`statsFilter.ts`) | 改成路由後切頁會 unmount,用 store 保留原本「切到別的分頁再回來,區間不變」的行為 |
| `TransactionList` 的 `refreshKey` | 固定傳 `0` | 原用途是帳戶/分類變動後通知交易頁重載;改成路由後每次進入交易頁都會重新掛載並載入,不再需要 |

## 修改內容(`update54.sh`)

新增:

- `src/styles/theme.css`:主題本體(由 TCR `app.css` 移植並精簡,藍色金屬改墨綠金屬,移除 TCR 專用樣式)
- `src/layouts/AppLayout.vue`:側欄(品牌列、目前帳本、選單、時鐘)+ 頂部列(標題、身分、登出)
- `src/components/AppIcon.vue`、`src/components/BrandBlock.vue`
- `src/views/StatsView.vue`(統計子分頁改 `.key` LED 按鍵)、`TransactionsView`/`AccountsView`/`CategoriesView`/`TagsView`/`TransferView.vue`(以 `.panel` 包既有元件)
- `src/stores/statsFilter.ts`、`src/utils/date.ts`

修改:

- `router/index.ts`:子路由 + `meta.title`;`dashboard` 改為導向 `stats`;未知路徑導回首頁
- `main.ts`:先載入 `styles/theme.css` 再載入 `style.css`
- `style.css`:改為相容層
- `DateRangePicker.vue`:快選改為 本月/上月/近 3 個月/今年,目前區間按鈕呈按下狀態
- `MembersView.vue`、`AuditLogView.vue`:移除各自的頁首(返回首頁、登出改由版面提供),改用面板/表格/按鍵樣式;移除過時提示文字「交易紀錄、多帳戶與統計圖表功能將在下一步接續開發」
- `LoginView`/`RegisterHouseholdView`/`ForgotPasswordView`/`ResetPasswordView.vue`:卡片上方加 `<BrandBlock />`

刪除:`DashboardView.vue`

## Bug 修正:統計頁「今天」在早上 8 點前變成昨天

- **現象**:台北時間 00:00–07:59 開統計頁,預設結束日是前一天,當天交易不會算進統計
- **原因**:`DashboardView.vue` 與 `DateRangePicker.vue` 以 `new Date().toISOString().slice(0, 10)` 取今天;`toISOString()` 回傳 UTC,台北為 UTC+8
- **修正**:新增 `utils/date.ts`,以 `getFullYear()`/`getMonth()`/`getDate()`(本地時區)組字串;統計頁預設區間與快選都改用 `presetRange()`

## 部署與驗證

- `update54.sh`:前置驗證以 sha256 比對 11 個要覆寫/刪除的檔案,與產生腳本時看到的版本不一致就中止;腳本內先跑 `npm install && npm run build`,失敗自動還原、不 commit
- commit:`59775dc`(chore 歸檔)、`aa49cff`(feat)
- `deploy.sh`:`ledger-api` active,`/` 與 `/health` 皆 200
- 使用者實測(2026-11-06):登入頁品牌列、登入後進 `/stats`、側欄各頁 active 狀態與帳本名稱、交易新增/編輯/刪除/進階篩選、統計四個子分頁與日期快選(切頁回來區間保留)、成員管理改名、瀏覽器上一頁,全部正常

## 目前狀態

第 0、1 步完成。第 2 步(逐頁清 inline style、移除相容層)、第 3 步(圖表配色)未開始,見 `features/feature-ui-theme.md` 第五節。
__D55_EOF__

git add docs
git commit -m "docs: 前端金屬主題 + 側欄版面改版紀錄(feature-ui-theme.md、changelog-details),同步 overview/stats/household"

echo
git log --oneline -3
echo
git diff HEAD~1 --stat
echo
echo "✅ 完成。確認無誤後:git push origin main(純文件異動,deploy.sh 可跑可不跑)"
