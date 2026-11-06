#!/usr/bin/env bash
# update62.sh — 文件:update60(E2.5 + E3、移除 style.css)與 update61(新增按鍵、消費品項頁比照分類頁)紀錄
#               新增 2 份 changelog-details,同步 CHANGELOG / PROJECT-OVERVIEW / feature-ui-theme / categories / tags / stats
# 執行位置:server 的 /root/apps(root)
set -euo pipefail

CURRENT=62

# ---------- 前置驗證(不通過不寫入任何檔案) ----------
[ -d .git ] && [ -f docs/PROJECT-OVERVIEW.md ] \
  || { echo "❌ 請在 Finance repo 根目錄執行(需有 .git、docs/PROJECT-OVERVIEW.md)" >&2; exit 1; }
if ! grep -q "add-key" ledger-frontend/src/components/TagPicker.vue; then
  echo "❌ 尚未包含 update61.sh 的改動,請先確認 update60/61 是否已成功套用" >&2; exit 1
fi
if git ls-files --error-unmatch docs/changelog-details/20261106-add-keys-tags-page.md >/dev/null 2>&1; then
  echo "❌ 已套用過本次更新,不需重跑" >&2; exit 1
fi
if ! git diff --quiet HEAD -- docs || ! git diff --cached --quiet -- docs; then
  echo "❌ docs/ 有未 commit 的修改,請先處理後再執行" >&2; exit 1
fi

cat > /tmp/update62_edits.py << 'PYEOF'
import sys
EDITS = [
 ('CHANGELOG.md', '## 2026-11\n\n',
  '## 2026-11\n\n- 11-06 feat: 新增分類/品項改為醒目按鍵,消費品項頁版面比照分類頁 → [詳情](changelog-details/20261106-add-keys-tags-page.md)\n- 11-06 feat: 選擇器/統計元件/登入頁改用金屬主題,圖表配色統一(`chartTheme.ts`),移除 `style.css` 相容層(E2.5 + E3) → [詳情](changelog-details/20261106-e25-e3-theme-completion.md)\n'),
 ('PROJECT-OVERVIEW.md', "| `20261106-e2-pages-restyle.md` |\n",
  "| `20261106-e2-pages-restyle.md` |\n| `20261106-e25-e3-theme-completion.md` |\n| `20261106-add-keys-tags-page.md` |\n"),
 ('PROJECT-OVERVIEW.md',
  "- [ ] E2.5 共用選擇器(`CategoryPicker`/`TagPicker`/篩選器)、`TagBreakdownChart`/`TopTransactionsList`、登入類頁面改版,完成後移除 `style.css` 相容層\n- [ ] E3 圖表配色統一(`utils/chartTheme.ts`)\n",
  "- [x] E2.5 共用選擇器、`TagBreakdownChart`/`TopTransactionsList`、登入類頁面改版,移除 `style.css` 相容層(2026-11-06)\n- [x] E3 圖表配色統一 `utils/chartTheme.ts`(2026-11-06)\n"),
 ('features/feature-ui-theme.md',
  "| `src/style.css` | **相容層**:舊 class(`.btn-primary`/`.field`/`.error-banner`/`.auth-page`/`.auth-card`/`.auth-switch`)沿用名稱、改成金屬外觀;舊變數(`--color-primary`/`--color-border`/`--color-surface` …)對應到新變數。`main.ts` 先載入 `theme.css` 再載入本檔 |\n",
  "| `src/utils/chartTheme.ts` | 圖表配色:`CHART_COLORS`(收入/支出/中性灰/文字/格線)、`CATEGORY_PALETTE`(10 色分類色盤)、`paletteColor()`、`withAlpha()`;載入時設定 Chart.js 全域字型/文字色/格線色。收支色與 `theme.css` 的 `--c-income`/`--c-expense` 同值,改色要兩邊一起改 |\n"),
 ('features/feature-ui-theme.md',
  "| `src/styles/theme.css` | 主題本體:",
  "| `src/styles/theme.css` | 主題本體(`main.ts` 唯一載入的全域樣式;原 `style.css` 相容層已於 2026-11-06 移除):"),
 ('features/feature-ui-theme.md',
  "| 全域 `input[type=file]` | 檔案選擇按鈕為金屬按鍵外觀 |\n",
  "| 全域 `input[type=file]` | 檔案選擇按鈕為金屬按鍵外觀 |\n| `.category-picker` / `.tag-picker` / `.filter-picker-box`(含 `.option-btn`、`.tag-btn`、`.crumb`、`.search-results` …) | 五個選擇器共用樣式,元件內不再寫 scoped style;`.filter-picker-box.tags` 為膠囊形 |\n| `.key.add-key` + `.create-row` | 選擇器內「新增分類/新增品項」按鍵(開啟時亮綠燈) |\n| `.error-banner` | 錯誤訊息框 |\n| `.auth-page` / `.auth-card` / `.auth-body`、`.stack-form`、`.btn.block`、`.auth-switch` | 登入/註冊等單張卡片頁 |\n| `--c-income` / `--c-expense` | 收支圖示與長條顏色 |\n"),
 ('features/feature-ui-theme.md',
  "| ✅ 2026-11-06(交易紀錄見 `feature-transactions.md`;其餘四頁見 `changelog-details/20261106-e2-pages-restyle.md`)。相容層尚未移除,見第 2.5 步 |\n",
  "| ✅ 2026-11-06(交易紀錄見 `feature-transactions.md`;其餘四頁見 `changelog-details/20261106-e2-pages-restyle.md`) |\n"),
 ('features/feature-ui-theme.md',
  "完成後移除 `style.css` | 未開始 |\n| 第 3 步 | 圖表配色統一(抽 `utils/chartTheme.ts`,三張圖表共用收入/支出色與分類色盤) | 未開始 |\n",
  "完成後移除 `style.css` | ✅ 2026-11-06 |\n| 第 3 步 | 圖表配色統一(抽 `utils/chartTheme.ts`,三張圖表共用收入/支出色與分類色盤) | ✅ 2026-11-06 |\n"),
 ('features/feature-ui-theme.md',
  "2. 共用選擇器(交易對話框內的分類/品項選擇、交易查詢的進階篩選)仍是舊樣式(白底按鈕網格),見第 2.5 步\n",
  "2. 管理頁(分類、消費品項)上方的選擇器點選項目會呈選取狀態但沒有實際作用,與交易對話框共用同一元件所致\n"),
 ('features/feature-ui-theme.md',
  "| 2026-11-06 | E2 帳戶/分類/消費品項/匯入匯出頁改版(`update58.sh`) | `changelog-details/20261106-e2-pages-restyle.md` |\n",
  "| 2026-11-06 | E2 帳戶/分類/消費品項/匯入匯出頁改版(`update58.sh`) | `changelog-details/20261106-e2-pages-restyle.md` |\n| 2026-11-06 | E2.5 + E3:選擇器/統計元件/登入頁改用主題、`chartTheme.ts`、移除 `style.css`(`update60.sh`) | `changelog-details/20261106-e25-e3-theme-completion.md` |\n| 2026-11-06 | 新增分類/品項改為醒目按鍵、消費品項頁版面比照分類頁(`update61.sh`) | `changelog-details/20261106-add-keys-tags-page.md` |\n"),
 ('features/feature-categories.md',
  "新增同名分類會被阻擋 |",
  "新增同名分類會被阻擋。「新增分類」為選項下方獨立一列的立體按鍵,開啟後在右側輸入,並提示加在哪一層;搜尋中開啟會帶入搜尋字 |"),
 ('features/feature-categories.md',
  "| 2026-11-06 | 分類管理頁改用金屬主題(LED 類型按鍵、樹狀列按鍵、搜尋結果表格) | `changelog-details/20261106-e2-pages-restyle.md` |\n",
  "| 2026-11-06 | 分類管理頁改用金屬主題(LED 類型按鍵、樹狀列按鍵、搜尋結果表格) | `changelog-details/20261106-e2-pages-restyle.md` |\n| 2026-11-06 | 「新增分類」改為醒目按鍵並顯示新增層級 | `changelog-details/20261106-add-keys-tags-page.md` |\n"),
 ('features/feature-tags.md',
  "搜尋時收斂為單一清單;支援就地新增 |",
  "搜尋時收斂為單一清單;「新增品項」為下方獨立一列的立體按鍵,開啟後在右側輸入,搜尋中開啟會帶入搜尋字 |"),
 ('features/feature-tags.md',
  "| `TagList.vue` | 消費品項管理頁(`/tags`)。新增欄在面板標題列;搜尋框 + 金屬膠囊鍵網格(顯示使用次數,未使用者淡色);分「最近使用」(取前 12)/「全部品項」兩區;點擊品項在面板下方開明細列(使用次數、最後使用日期、改名/刪除/關閉);刪除確認文字依 `usage_count` 是否為 0 顯示不同訊息 |",
  "| `TagList.vue` | 消費品項管理頁(`/tags`),版面比照分類頁:上方「建立消費品項」直接使用 `TagPicker` 瀏覽/搜尋/新增;下方「全部消費品項」搜尋框 + 表格(品項/使用次數/最後使用/改名、刪除,依使用次數多→少,未使用者淡色);改名同名阻擋;刪除確認文字依 `usage_count` 是否為 0 顯示不同訊息 |"),
 ('features/feature-tags.md',
  "| 2026-11-06 | 管理頁改用金屬主題(標題列新增欄、膠囊鍵、明細列) | `changelog-details/20261106-e2-pages-restyle.md` |\n",
  "| 2026-11-06 | 管理頁改用金屬主題(標題列新增欄、膠囊鍵、明細列) | `changelog-details/20261106-e2-pages-restyle.md` |\n| 2026-11-06 | 管理頁版面改為比照分類頁(上方 TagPicker 建立、下方表格);「新增品項」改醒目按鍵 | `changelog-details/20261106-add-keys-tags-page.md` |\n"),
 ('features/feature-stats.md',
  "彙總類 API 一律在 DB 層用 `group by`/`func.sum`/`func.count` 完成,不把交易全部拉回 Python 迭代(`stats.py`、`tags.py` 的 `usage_count`、`recalc_account_balances.py` 皆遵循同一模式)。\n",
  "彙總類 API 一律在 DB 層用 `group by`/`func.sum`/`func.count` 完成,不把交易全部拉回 Python 迭代(`stats.py`、`tags.py` 的 `usage_count`、`recalc_account_balances.py` 皆遵循同一模式)。\n\n前端圖表配色統一由 `utils/chartTheme.ts` 提供:趨勢圖收入綠/支出紅(`CHART_COLORS`),分類圓餅用 10 色 `CATEGORY_PALETTE`,「直接歸類」固定灰 `#9CA3AF`;消費品項排行、最大單筆排行的長條依收支上色,支出/收入以 LED 小按鍵切換。\n"),
 ('features/feature-stats.md',
  "| 2026-11-06 | 統計頁改為 `/stats` 子路由、子分頁改 LED 按鍵、日期快選增加本月/上月/近 3 個月;修正「今天」UTC 偏移 | `changelog-details/20261106-ui-metal-theme-layout.md` |\n",
  "| 2026-11-06 | 統計頁改為 `/stats` 子路由、子分頁改 LED 按鍵、日期快選增加本月/上月/近 3 個月;修正「今天」UTC 偏移 | `changelog-details/20261106-ui-metal-theme-layout.md` |\n| 2026-11-06 | 圖表配色統一(`chartTheme.ts`),趨勢圖改統計卡片,排行改 LED 收支按鍵 | `changelog-details/20261106-e25-e3-theme-completion.md` |\n"),
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
python3 /tmp/update62_edits.py --check

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
python3 /tmp/update62_edits.py
rm -f /tmp/update62_edits.py

# ---------- 新文件 ----------
cat > 'docs/changelog-details/20261106-e25-e3-theme-completion.md' << '__D62_EOF__'
# 2026-11-06 前端改版收尾:選擇器/統計元件/登入頁改用主題、圖表配色統一、移除相容層(E2.5 + E3)

## 背景

E2 五個功能頁完成後(`20261106-e2-pages-restyle.md`),仍有共用選擇器、兩個統計元件、登入類頁面在用舊樣式或 `style.css` 相容層;三張圖表各自寫死配色(趨勢圖 Finance 綠/紅、圓餅圖 Tailwind 靛藍色盤、長條圖 `#4a90d9` 藍),與主題不一致。

## 決策

| 項目 | 決定 | 理由 |
|---|---|---|
| 選擇器樣式 | 五個選擇器沿用原 class 名稱,樣式集中到 `theme.css` 的「選擇器」區段,刪除各自 scoped style | 五個元件結構幾乎相同,原本各寫一份 30~120 行 CSS;集中後只需維護一處 |
| 圖表配色 | 新增 `utils/chartTheme.ts`;收支色與 `theme.css` 的 `--c-income`/`--c-expense` 同值 | Chart.js 畫在 canvas 上讀不到 CSS 變數,需在 TS 端另存一份 |
| 分類色盤 | 10 色,色相分開、明度相近,刻意避開純紅/純綠 | 避免與收支色混淆;「本分類直接歸類」維持固定灰 `#9CA3AF` |
| 相容層 | 刪除 `src/style.css`;`.error-banner`、`.auth-*` 移入 `theme.css`;`.btn-primary` → `.btn.primary.block`、`.field` → `.form-field` | 程式碼已無任何地方使用舊 class 與舊變數 |

## 修改內容(`update60.sh`)

- `styles/theme.css`:新增選擇器共用樣式、`.error-banner`、登入卡片(`.auth-page`/`.auth-card`/`.auth-body`/`.stack-form`/`.btn.block`/`.auth-switch`)、`--c-income`/`--c-expense`
- 選擇器:`CategoryPicker`/`TagPicker`/`AccountFilterPicker`/`CategoryFilterPicker`/`TagFilterPicker.vue` 刪除 scoped style 與 inline style;選項為金屬鍵、選取為品牌綠
- 統計:
  - `MonthlyTrendChart.vue`:總收入/總支出/結餘改 `.stat` 卡片,折線用 `CHART_COLORS`
  - `CategoryBreakdownChart.vue`:層級導覽改 `.btn.sm`(目前層 `.on`)+ 提示「點圓餅區塊可查看子分類」,色盤改 `paletteColor()`
  - `TagBreakdownChart.vue`/`TopTransactionsList.vue`:支出/收入改 LED 小按鍵,長條依收支上色,名次改圓形徽章
- 新增 `utils/chartTheme.ts`:`CHART_COLORS`、`CATEGORY_PALETTE`、`paletteColor()`、`withAlpha()`,並設定 Chart.js 全域字型/文字色/格線色
- 登入/註冊/忘記密碼/重設密碼頁、`MembersView.vue`:改用上述 class
- `main.ts`:移除 `style.css` 載入;刪除 `src/style.css`

## 驗證

- Playwright + 假資料:登入/註冊/重設密碼頁、統計四分頁、交易對話框選擇器、進階篩選、成員新增截圖檢查;交易/帳戶/分類/品項/匯入匯出操作回歸測試,API payload 與改版前一致
- 部署後 `ledger-api` active、`/` 與 `/health` 皆 200;使用者實測(2026-11-06)全部正常
__D62_EOF__

cat > 'docs/changelog-details/20261106-add-keys-tags-page.md' << '__D62_EOF__'
# 2026-11-06 新增分類/品項改為醒目按鍵、消費品項頁版面比照分類頁

## 背景

`update60.sh` 部署後使用者回饋:

1. 選擇器裡的「+ 新增分類」「+ 新增品項」是虛線小按鈕,不明顯
2. 消費品項與分類是性質相近的東西,但兩頁版面/操作位置不同(分類頁上方建立、下方列表;品項頁新增欄在標題列、品項攤成膠囊鍵、點選後下方出明細列),使用者會困惑

## 修改內容(`update61.sh`)

**新增按鍵(`CategoryPicker.vue`、`TagPicker.vue`、`theme.css`)**

- 「新增分類」「新增品項」改為與支出/收入同款的立體按鍵(`.key.add-key`),綠色 +,開啟新增欄位時亮綠燈(再按一次收起)
- 按鍵獨立一列(虛線分隔),不再混在選項網格中;新增欄位顯示在按鍵右側
- 新增分類顯示加在哪一層(「加在『最上層』」/ placeholder「在『餐飲』新增分類」)
- 搜尋中開啟新增欄位時,自動帶入搜尋字
- TagPicker 搜尋無結果時顯示「沒有符合…的品項」

**消費品項頁(`TagList.vue` 改寫)**

- 上方「建立消費品項」:直接使用 `TagPicker`(與交易對話框相同),瀏覽/搜尋/新增
- 下方「全部消費品項」:數量標籤 + 搜尋框 + 表格(品項/使用次數/最後使用/改名、刪除),未使用品項淡色;改名同名阻擋、刪除依使用次數顯示不同確認文字(規則不變)
- 移除原本的膠囊鍵網格與明細列

## 已知行為

管理頁上方選擇器點選品項會呈選取狀態(綠色),但沒有實際作用;分類頁的 `CategoryPicker` 原本即如此,維持一致。

## 驗證

- Playwright + 假資料:交易對話框新增分類/品項(搜尋字帶入、POST payload)、品項頁新增/改名重名阻擋/搜尋/刪除
- 部署後 `ledger-api` active、`/` 與 `/health` 皆 200;使用者實測(2026-11-06)全部正常
__D62_EOF__

git add docs
git commit -m "docs: E2.5/E3 主題收尾、新增按鍵與消費品項頁改版紀錄,同步 feature 文件"

echo
git log --oneline -3
echo
git diff HEAD~1 --stat
echo
echo "✅ 完成。確認無誤後:git push origin main(純文件異動,不需 deploy)"
