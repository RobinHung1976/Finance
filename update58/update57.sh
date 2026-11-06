#!/usr/bin/env bash
# update57.sh — 文件:交易紀錄頁改版(update56)紀錄 —— 新增 changelog-details、覆寫 feature-transactions.md,
#               同步 CHANGELOG / PROJECT-OVERVIEW(C1 完成、E2 進度)/ feature-ui-theme
# 執行位置:server 的 /root/apps(root)
set -euo pipefail

CURRENT=57

# ---------- 前置驗證(不通過不寫入任何檔案) ----------
[ -d .git ] && [ -f docs/PROJECT-OVERVIEW.md ] \
  || { echo "❌ 請在 Finance repo 根目錄執行(需有 .git、docs/PROJECT-OVERVIEW.md)" >&2; exit 1; }
if ! git ls-files --error-unmatch ledger-frontend/src/components/TransactionFormDialog.vue >/dev/null 2>&1; then
  echo "❌ 尚未包含 update56.sh 的改動,請先確認 update56.sh 是否已成功套用" >&2; exit 1
fi
if git ls-files --error-unmatch docs/changelog-details/20261106-transactions-report-view.md >/dev/null 2>&1; then
  echo "❌ 已套用過本次更新,不需重跑" >&2; exit 1
fi
if ! git diff --quiet HEAD -- docs || ! git diff --cached --quiet -- docs; then
  echo "❌ docs/ 有未 commit 的修改,請先處理後再執行" >&2; exit 1
fi
got=$(sha256sum docs/features/feature-transactions.md | cut -d' ' -f1)
[ "$got" = "a9e0dc5e2619fb5386497f1016bab37dc1c4ef2e0e33380d201de98ffb1f2fd4" ] || { echo "❌ docs/features/feature-transactions.md 內容與預期版本不符,中止" >&2; exit 1; }

cat > /tmp/update57_edits.py << 'PYEOF'
import sys
EDITS = [
 ('CHANGELOG.md', '## 2026-11\n\n',
  '## 2026-11\n\n- 11-06 feat: 交易紀錄頁改為查詢面板 + 報表表格(統計卡片、排序、搜尋、類型篩選),新增/編輯改對話框,匯出 CSV(完成 C1) → [詳情](changelog-details/20261106-transactions-report-view.md)\n'),
 ('PROJECT-OVERVIEW.md', "| `20261106-ui-metal-theme-layout.md` |\n",
  "| `20261106-ui-metal-theme-layout.md` |\n| `20261106-transactions-report-view.md` |\n"),
 ('PROJECT-OVERVIEW.md', "- [ ] C1 CSV 匯出\n",
  "- [x] C1 CSV 匯出(2026-11-06,交易紀錄頁前端匯出目前查詢結果,見 `features/feature-transactions.md`)\n"),
 ('PROJECT-OVERVIEW.md', "- [ ] E2 逐頁清除 inline style/寫死色碼,完成後移除相容層(交易紀錄 → 帳戶 → 分類 → 消費品項 → 匯入匯出)\n",
  "- [ ] E2 逐頁清除 inline style/寫死色碼,完成後移除相容層(交易紀錄 ✅ 2026-11-06 → 帳戶 → 分類 → 消費品項 → 匯入匯出)\n"),
 ('features/feature-ui-theme.md',
  "| 第 2 步 | 逐頁清除 inline style 與寫死色碼,改用 `theme.css` class(交易紀錄 → 帳戶 → 分類 → 消費品項 → 匯入匯出);全部改完後移除 `style.css` 相容層 | 未開始 |\n",
  "| 第 2 步 | 逐頁清除 inline style 與寫死色碼,改用 `theme.css` class(交易紀錄 → 帳戶 → 分類 → 消費品項 → 匯入匯出);全部改完後移除 `style.css` 相容層 | 進行中:交易紀錄 ✅ 2026-11-06(查詢面板 + 報表表格,見 `feature-transactions.md`) |\n"),
 ('features/feature-ui-theme.md',
  "| `.hint` / `.empty` / `.row` / `.notice` / `.flash` | 輔助樣式 |\n",
  "| `.form-grid` + `.form-field`(`.wide` / `.span2`) | 查詢/表單欄位格線,標籤在上 |\n| `.stat-grid` + `.stat`(`.stat-value.income` / `.expense`) | 報表統計卡片 |\n| `.badge.income` / `.badge.expense`、`.chip`、`.amount.income` / `.expense` | 類型色塊、消費品項小標籤、金額正負色 |\n| `.toolbar`、`.grid th.sortable` | 表格上方工具列、可點擊排序表頭 |\n| `dialog.modal` + `.modal-foot` | 原生 `<dialog>` 對話框(`showModal()`) |\n| `.hint` / `.empty` / `.row` / `.notice` / `.flash` | 輔助樣式 |\n"),
 ('features/feature-ui-theme.md',
  "2. 第 2 步完成前,交易/帳戶/分類/消費品項/匯入匯出頁面內部仍是舊樣式(白色卡片 + inline style),外框已是金屬面板\n",
  "2. 第 2 步完成前,帳戶/分類/消費品項/匯入匯出頁面內部仍是舊樣式(白色卡片 + inline style),外框已是金屬面板\n"),
 ('features/feature-ui-theme.md',
  "| 2026-11-06 | 金屬主題 + 側欄版面上線,Dashboard 分頁改子路由(`update54.sh`) | `changelog-details/20261106-ui-metal-theme-layout.md` |\n",
  "| 2026-11-06 | 金屬主題 + 側欄版面上線,Dashboard 分頁改子路由(`update54.sh`) | `changelog-details/20261106-ui-metal-theme-layout.md` |\n| 2026-11-06 | E2 交易紀錄頁改版,`theme.css` 新增表單格線/統計卡片/對話框等 class(`update56.sh`) | `changelog-details/20261106-transactions-report-view.md` |\n"),
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
python3 /tmp/update57_edits.py --check

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
python3 /tmp/update57_edits.py
rm -f /tmp/update57_edits.py

# ---------- 整份覆寫 / 新文件 ----------
cat > 'docs/features/feature-transactions.md' << '__D57_EOF__'
# 功能現況:交易紀錄(Transactions)

## 一、後端

`app/routers/transactions.py`:

- CRUD(`create_transaction`/`update_transaction` 同步處理帳戶餘額連動與 `TransactionTag` 關聯)
- `list_transactions` 查詢參數:日期區間、`account_id`、`category_id`、`min_amount`/`max_amount`、`tag_ids: list[str] | None`
- 消費品項篩選為 **OR 語意**(交易掛任一被選取品項即列入)+ `join TransactionTag` + `.distinct()`(避免重複列出)

## 二、前端

頁面 `/transactions`(`src/views/TransactionsView.vue`)直接渲染 `src/components/TransactionList.vue`,分兩個面板:

**交易查詢**(條件一變就自動重新查詢,快速連續變動時只採用最後一次查詢結果)

- 開始/結束日期 + 快選 本月/上月/近 3 個月/今年(`utils/date.ts` 的 `presetRange()`,本地時區);預設本月 1 號 ~ 今天
- 類型 LED 按鍵:支出/收入,可只看其中一種(**前端篩選**,後端無 type 參數)
- 金額區間(後端 `min_amount`/`max_amount`)
- 「進階篩選」按鈕(顯示已套用數量)展開帳戶/分類/消費品項三個篩選器:
  - 帳戶:搜尋框 + 攤開按鈕網格(`AccountFilterPicker.vue`)
  - 分類:逐層鑽取麵包屑(`CategoryFilterPicker.vue`)+ 搜尋跨層級跳轉 + 清除
  - 消費品項:「最近使用/全部品項」分區 + 搜尋(`TagFilterPicker.vue`)+ 清除
- 「清除條件」:重設日期以外的所有條件(含類型、搜尋字)

**交易明細**

- 統計卡片:筆數、收入、支出、結餘(收入 − 支出)、帳戶總餘額(目前);下方一排各帳戶餘額(負數紅色)。筆數/收入/支出/結餘依**畫面上目前顯示的結果**計算(含類型與搜尋篩選)
- 搜尋框(前端):比對分類完整路徑、帳戶、消費品項、備註、金額
- 表格:日期(今天/昨天加註)、類型色塊、分類(`父 - 子` 完整路徑)、帳戶、消費品項 chip、備註、金額(收入綠 `+`、支出紅 `-`)、編輯/刪除;日期與金額欄可點擊排序(穩定排序,預設日期新到舊)
- 匯出 CSV(`utils/csv.ts`,前端產生):匯出目前畫面上的結果與排序;UTF-8 BOM(Excel 中文不亂碼);欄位 日期/類型/分類/帳戶/消費品項/備註/金額/收支(支出為負);文字格以 `= + - @` Tab CR 開頭時前面補單引號,避免 Excel 當公式執行(CSV injection);檔名 `交易紀錄_<起>_<迄>.csv`

**新增/編輯**:對話框 `src/components/TransactionFormDialog.vue`(原生 `<dialog>`,Esc 關閉),新增與編輯共用同一表單:

- 欄位:收支類型(LED 按鍵)、金額(正整數)、日期、帳戶、備註、分類(`CategoryPicker`)、消費品項(`TagPicker`)
- 新增時沿用上一次新增的類型/帳戶/分類,金額/備註/品項清空、日期重設為今天;第一次新增預設帳戶為 `is_default_expense`
- 切換收入/支出時清空分類(兩邊分類樹不同)
- 前端驗證:帳戶、分類必選,金額需為大於 0 的整數
- 儲存/刪除成功後重新載入帳戶(餘額已變動)與交易;刪除前 `confirm()` 顯示日期/分類/金額

`src/api/ledgerApi.ts`(原 `ledger.ts`,因與 `types/ledger.ts` 同名易混淆而改名):`fetchTransactions` 用 `URLSearchParams` 手動組 query string(而非讓 axios 序列化陣列參數),確保 `tag_ids` 重複 key 格式與 FastAPI `Query(list[str])` 相容。

## 三、已知限制 / 後續可考慮

1. 消費品項篩選僅支援 OR 語意,若未來需要 AND(必須同時掛滿所有勾選品項),需額外設計 `HAVING COUNT(DISTINCT tag_id) = 選取數量` 或子查詢
2. 分類篩選為「精確符合單一分類」,不含子分類
3. 「進階篩選」目前是單一收合區塊,篩選欄位若持續增加可評估改用分頁籤
4. 類型篩選與搜尋為前端篩選,只作用在已查回的資料;交易量大時若要分頁,需改為後端參數
5. 表格在窄螢幕需橫向捲動(手機版擱置,見 `feature-ui-theme.md`)

## 四、沿革

| 日期 | 內容 | 詳情 |
|---|---|---|
| 2026-07-07 | CategoryPicker 搜尋功能上線 | `changelog-details/20260707-category-picker-search.md` |
| 2026-07-07 | 消費品項掛載、chip 顯示、金額範圍篩選 | `changelog-details/20260707-tag-feature-launch.md` |
| 2026-07-10 | 消費品項篩選 + 篩選 UI 改為進階篩選面板(含帳戶/分類篩選器改版) | `changelog-details/20260710-transaction-tag-filter-advanced-search.md` |
| 2026-11-06 | 改為查詢面板 + 報表表格(統計卡片、排序、搜尋、類型篩選)、新增/編輯改對話框、匯出 CSV | `changelog-details/20261106-transactions-report-view.md` |
__D57_EOF__

cat > 'docs/changelog-details/20261106-transactions-report-view.md' << '__D57_EOF__'
# 2026-11-06 交易紀錄頁改為查詢面板 + 報表表格(前端改版 E2-1)

## 背景

前端金屬主題上線後(`20261106-ui-metal-theme-layout.md`),交易紀錄頁內部仍是舊樣式:依日期分組的白色卡片、135 處 inline style 中最大宗(16 處 + 247 行 scoped style)。希望改成與 Teams Call Report 相同的「查詢表單 + 報表」版面:欄位標籤在上的查詢區、LED 類型按鍵、統計卡片、可排序表格、匯出 CSV。

## 決策

| 項目 | 決定 | 理由 |
|---|---|---|
| 新增/編輯位置 | 對話框(原生 `<dialog>`),新增與編輯共用 `TransactionFormDialog.vue` | 改成表格後,列內展開放不下 `CategoryPicker`/`TagPicker`;共用表單避免兩份驗證邏輯不一致 |
| 查詢觸發 | 條件一變就自動查詢(維持原行為),不加「執行查詢」按鈕 | 本機 DB 查詢很快;TCR 用按鈕是因為 Microsoft Graph 查詢慢 |
| 匯出 CSV | 這次一起做,前端產生目前畫面結果 | 順便完成待辦 C1;不需新增後端 API |
| 類型篩選 | 前端篩選 | 後端 `list_transactions` 沒有 type 參數,資料已全部查回,不值得為此改 API |
| 日期分組 | 改為表格日期欄,今天/昨天加註 | 表格可排序後分組標題不再適用 |
| 新增預設值 | 沿用上一次新增的類型/帳戶/分類 | 原本表單關閉後也保留這三項,連續記帳較快,維持此行為 |

## 修改內容(`update56.sh`)

新增:

- `src/components/TransactionFormDialog.vue`:新增/編輯對話框,`defineExpose({ openCreate, openEdit })` 供父元件呼叫,儲存成功 emit `saved`
- `src/utils/csv.ts`:`toCsv()`(每格加雙引號、跳脫雙引號、文字格防公式注入)、`downloadCsv()`(UTF-8 BOM、Blob 下載)

修改:

- `src/components/TransactionList.vue`:整份改寫(查詢面板、統計卡片、搜尋、排序表格、CSV);移除 `refreshKey` prop(改成路由後每次進入頁面都重新掛載載入,已無作用);查詢加序號,快速連續變動條件時只採用最後一次結果
- `src/views/TransactionsView.vue`:不再外包 `.panel`(`TransactionList` 自帶兩個面板)
- `src/styles/theme.css`:新增 `.form-grid`/`.form-field`、`.stat-grid`/`.stat`、`.badge`、`.chip`、`.amount`、`.toolbar`、`.grid th.sortable`、`dialog.modal`、`.modal-foot`
- `src/components/AppIcon.vue`:新增 income/expense/plus/edit/trash/download/search/filter/x/table 圖示

## 驗證

- 開發環境以 Playwright + 假資料實測:類型切換、搜尋、排序、CSV 內容(BOM、欄位、負數、公式字元前綴)、新增(驗證訊息、送出 payload)、編輯(PATCH payload)、刪除(確認訊息、DELETE)皆正常
- `update56.sh`:sha256 比對 4 個既有檔案,腳本內建置通過才 commit
- 部署後 `ledger-api` active、`/` 與 `/health` 皆 200
- 使用者實測(2026-11-06):新增(沿用上一筆帳戶/分類、未選分類的錯誤訊息)、編輯(金額/日期/收支互換,餘額更新)、刪除(確認訊息、餘額回補)、進階篩選與清除條件、CSV 以 Excel 開啟中文正常且筆數一致、其他頁不受影響,全部正常

## 目前狀態

交易紀錄頁完成 E2;帳戶 → 分類 → 消費品項 → 匯入匯出尚未改版,`style.css` 相容層仍保留。
__D57_EOF__

git add docs
git commit -m "docs: 交易紀錄頁改版紀錄,feature-transactions 改寫,C1 CSV 匯出完成,E2 進度"

echo
git log --oneline -3
echo
git diff HEAD~1 --stat
echo
echo "✅ 完成。確認無誤後:git push origin main(純文件異動,不需 deploy)"
