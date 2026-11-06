#!/usr/bin/env bash
# update59.sh — 文件:帳戶/分類/消費品項/匯入匯出頁改版(update58)紀錄 —— 新增 changelog-details,
#               同步 CHANGELOG / PROJECT-OVERVIEW(E2 完成、新增 E2.5)/ feature-ui-theme / accounts / categories / tags / excel-import-export
# 執行位置:server 的 /root/apps(root)
set -euo pipefail

CURRENT=59

# ---------- 前置驗證(不通過不寫入任何檔案) ----------
[ -d .git ] && [ -f docs/PROJECT-OVERVIEW.md ] \
  || { echo "❌ 請在 Finance repo 根目錄執行(需有 .git、docs/PROJECT-OVERVIEW.md)" >&2; exit 1; }
if ! grep -q 'class="tag-key"' ledger-frontend/src/components/TagList.vue; then
  echo "❌ 尚未包含 update58.sh 的改動,請先確認 update58.sh 是否已成功套用" >&2; exit 1
fi
if git ls-files --error-unmatch docs/changelog-details/20261106-e2-pages-restyle.md >/dev/null 2>&1; then
  echo "❌ 已套用過本次更新,不需重跑" >&2; exit 1
fi
if ! git diff --quiet HEAD -- docs || ! git diff --cached --quiet -- docs; then
  echo "❌ docs/ 有未 commit 的修改,請先處理後再執行" >&2; exit 1
fi

cat > /tmp/update59_edits.py << 'PYEOF'
import sys
EDITS = [
 ('CHANGELOG.md', '## 2026-11\n\n',
  '## 2026-11\n\n- 11-06 feat/fix: 帳戶/分類/消費品項/匯入匯出頁改用金屬主題(表格、LED 按鍵、統計卡片),E2 五頁完成;修正匯入完成後無法重選同一檔案、載入帳戶失敗無提示 → [詳情](changelog-details/20261106-e2-pages-restyle.md)\n'),
 ('PROJECT-OVERVIEW.md', "| `20261106-transactions-report-view.md` |\n",
  "| `20261106-transactions-report-view.md` |\n| `20261106-e2-pages-restyle.md` |\n"),
 ('PROJECT-OVERVIEW.md',
  "- [ ] E2 逐頁清除 inline style/寫死色碼,完成後移除相容層(交易紀錄 ✅ 2026-11-06 → 帳戶 → 分類 → 消費品項 → 匯入匯出)\n",
  "- [x] E2 五個功能頁改用 `theme.css` class(交易紀錄、帳戶、分類、消費品項、匯入匯出,2026-11-06)\n- [ ] E2.5 共用選擇器(`CategoryPicker`/`TagPicker`/篩選器)、`TagBreakdownChart`/`TopTransactionsList`、登入類頁面改版,完成後移除 `style.css` 相容層\n"),
 ('features/feature-ui-theme.md',
  "| 進行中:交易紀錄 ✅ 2026-11-06(查詢面板 + 報表表格,見 `feature-transactions.md`) |\n",
  "| ✅ 2026-11-06(交易紀錄見 `feature-transactions.md`;其餘四頁見 `changelog-details/20261106-e2-pages-restyle.md`)。相容層尚未移除,見第 2.5 步 |\n| 第 2.5 步 | 共用選擇器(`CategoryPicker`/`TagPicker`/`AccountFilterPicker`/`CategoryFilterPicker`/`TagFilterPicker`)、`TagBreakdownChart`/`TopTransactionsList`、登入類頁面、`MembersView` 的 `.field` 改用 `theme.css`,完成後移除 `style.css` | 未開始 |\n"),
 ('features/feature-ui-theme.md',
  "2. 第 2 步完成前,帳戶/分類/消費品項/匯入匯出頁面內部仍是舊樣式(白色卡片 + inline style),外框已是金屬面板\n",
  "2. 共用選擇器(交易對話框內的分類/品項選擇、交易查詢的進階篩選)仍是舊樣式(白底按鈕網格),見第 2.5 步\n"),
 ('features/feature-ui-theme.md',
  "| `.hint` / `.empty` / `.row` / `.notice` / `.flash` | 輔助樣式 |\n",
  "| `.hint` / `.empty` / `.row` / `.notice` / `.flash` | 輔助樣式 |\n| 全域 `input[type=file]` | 檔案選擇按鈕為金屬按鍵外觀 |\n"),
 ('features/feature-ui-theme.md',
  "| 2026-11-06 | E2 交易紀錄頁改版,`theme.css` 新增表單格線/統計卡片/對話框等 class(`update56.sh`) | `changelog-details/20261106-transactions-report-view.md` |\n",
  "| 2026-11-06 | E2 交易紀錄頁改版,`theme.css` 新增表單格線/統計卡片/對話框等 class(`update56.sh`) | `changelog-details/20261106-transactions-report-view.md` |\n| 2026-11-06 | E2 帳戶/分類/消費品項/匯入匯出頁改版(`update58.sh`) | `changelog-details/20261106-e2-pages-restyle.md` |\n"),
 ('features/feature-accounts.md',
  "`src/components/AccountList.vue`:帳戶管理頁。",
  "`src/components/AccountList.vue`:帳戶管理頁(`/accounts`)。表格列出名稱(預設支出帳戶加標籤)/類型/餘額/操作,最下方合計列,負餘額紅色;「調整餘額」在餘額欄就地編輯;操作含設為預設、調整餘額、刪除。新增帳戶表單:名稱、類型、起始餘額(必填,可為 0 或負數)、是否為預設支出帳戶。"),
 ('features/feature-accounts.md',
  "| 2026-07-08 | 歷史帳戶餘額回補腳本,回補修正前已匯入的落差資料 | `changelog-details/20260708-account-balance-recalc.md` |\n",
  "| 2026-07-08 | 歷史帳戶餘額回補腳本,回補修正前已匯入的落差資料 | `changelog-details/20260708-account-balance-recalc.md` |\n| 2026-11-06 | 帳戶頁改為表格 + 合計列(前端改版 E2) | `changelog-details/20261106-e2-pages-restyle.md` |\n"),
 ('features/feature-categories.md',
  "| `CategoryTreeNode.vue` | 遞迴摺疊樹節點,含改名按鈕(inline 編輯,同層重複名稱阻擋) |",
  "| `CategoryTreeNode.vue` | 遞迴摺疊樹節點,每列含改名/刪除按鈕(inline 編輯,同層重複名稱阻擋),有子分類時顯示數量標籤 |"),
 ('features/feature-categories.md',
  "| `CategoryList.vue` | 管理頁。上半部複用 `CategoryPicker`",
  "| `CategoryList.vue` | 管理頁(`/categories`),支出/收入以 LED 按鍵切換。上半部「建立分類」複用 `CategoryPicker`"),
 ('features/feature-categories.md',
  "輸入搜尋框後改顯示扁平清單(完整路徑,可就地改名/刪除)",
  "輸入搜尋框後改顯示表格(完整路徑,可就地改名/刪除)"),
 ('features/feature-categories.md',
  "| 2026-07-10 | 篩選列分類選擇改回逐層鑽取麵包屑(原本嘗試攤開全部,使用者反映太亂) | `changelog-details/20260710-transaction-tag-filter-advanced-search.md` |\n",
  "| 2026-07-10 | 篩選列分類選擇改回逐層鑽取麵包屑(原本嘗試攤開全部,使用者反映太亂) | `changelog-details/20260710-transaction-tag-filter-advanced-search.md` |\n| 2026-11-06 | 分類管理頁改用金屬主題(LED 類型按鍵、樹狀列按鍵、搜尋結果表格) | `changelog-details/20261106-e2-pages-restyle.md` |\n"),
 ('features/feature-tags.md',
  "| `TagList.vue` | 消費品項管理頁。搜尋框 + chip 網格版面(取代逐行排列);",
  "| `TagList.vue` | 消費品項管理頁(`/tags`)。新增欄在面板標題列;搜尋框 + 金屬膠囊鍵網格(顯示使用次數,未使用者淡色);"),
 ('features/feature-tags.md',
  "點擊 chip 開單一詳情面板(使用次數、最後使用日期、改名/刪除)",
  "點擊品項在面板下方開明細列(使用次數、最後使用日期、改名/刪除/關閉)"),
 ('features/feature-tags.md',
  "| `TransactionList.vue` | 新增/編輯表單掛 `TagPicker`;交易卡片消費品項改為獨立彩色 chip 顯示,與帳戶/備註分行 |",
  "| `TransactionFormDialog.vue` / `TransactionList.vue` | 新增/編輯對話框掛 `TagPicker`;交易明細表格「消費品項」欄以 chip 顯示 |"),
 ('features/feature-tags.md',
  "| 2026-07-08 | 統計圖表加入消費品項排行 | `changelog-details/20260708-tag-breakdown-stats.md` |\n",
  "| 2026-07-08 | 統計圖表加入消費品項排行 | `changelog-details/20260708-tag-breakdown-stats.md` |\n| 2026-11-06 | 管理頁改用金屬主題(標題列新增欄、膠囊鍵、明細列) | `changelog-details/20261106-e2-pages-restyle.md` |\n"),
 ('features/feature-excel-import-export.md',
  "| `src/components/ExcelImportExport.vue` | 帳戶選擇、檔案上傳、預覽表格(重複/新分類標記、勾選強制匯入)、匯出年份選擇 |",
  "| `src/components/ExcelImportExport.vue` | 頁面 `/transfer`,分「匯出 Excel」(年份選擇)與「匯入 Excel」兩個面板。匯入:目標帳戶、檔案上傳、預覽(統計卡片 總筆數/有效/重複/錯誤/將匯入 + 表格,狀態標籤 匯入/新分類/重複跳過/強制匯入,勾選強制匯入);匯入完成或取消後清空檔案欄位(否則重選同一檔案不觸發 `change`) |"),
 ('features/feature-excel-import-export.md',
  "| 2026-07-08 | 修復帳戶餘額未同步、格式過於死板、中文檔名 500、下載檔名前端寫死 | `changelog-details/20260708-excel-import-export-fix.md` |\n",
  "| 2026-07-08 | 修復帳戶餘額未同步、格式過於死板、中文檔名 500、下載檔名前端寫死 | `changelog-details/20260708-excel-import-export-fix.md` |\n| 2026-11-06 | 改用金屬主題(預覽統計卡片 + 表格);修正匯入後無法重選同一檔案、載入帳戶失敗無提示 | `changelog-details/20261106-e2-pages-restyle.md` |\n"),
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
python3 /tmp/update59_edits.py --check

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
python3 /tmp/update59_edits.py
rm -f /tmp/update59_edits.py

# ---------- 新文件 ----------
cat > 'docs/changelog-details/20261106-e2-pages-restyle.md' << '__D59_EOF__'
# 2026-11-06 帳戶/分類/消費品項/匯入匯出頁改用金屬主題(前端改版 E2-2)

## 背景

E2 第一頁(交易紀錄,`20261106-transactions-report-view.md`)完成後,其餘四頁內部仍是舊樣式:白色卡片、純文字按鈕(`.btn-text`)、inline style 與寫死色碼。本次一次改完,行為與 API 呼叫不變。

## 修改內容(`update58.sh`)

| 頁面 | 元件 | 改動 |
|---|---|---|
| 帳戶 | `AccountList.vue` | 改為表格(名稱 + 預設支出帳戶標籤/類型/餘額/操作)+ 合計列,負餘額紅色;「調整餘額」在餘額欄就地編輯;新增表單改 `.form-grid` 欄位格線;起始餘額、調整餘額為空時前端擋下(原本未檢查) |
| 分類 | `CategoryList.vue`、`CategoryTreeNode.vue` | 支出/收入改 LED 按鍵(放在「建立分類」面板標題列);分類樹每列改金屬按鍵(改名/刪除),子分類數量改小標籤;搜尋結果改表格(完整路徑,可就地改名/刪除) |
| 消費品項 | `TagList.vue` | 新增欄移到面板標題列;品項改金屬膠囊鍵(含使用次數,未使用者淡色),選取後為品牌綠;下方明細列顯示使用次數/最後使用日與改名/刪除/關閉 |
| 匯入匯出 | `ExcelImportExport.vue` | 拆成「匯出 Excel」「匯入 Excel」兩個面板;預覽改統計卡片(總筆數/有效/重複/錯誤/將匯入)+ 表格(類型色塊、狀態標籤 匯入/新分類/重複跳過/強制匯入) |
| 共用 | `styles/theme.css` | 新增 `input[type=file]` 金屬按鍵樣式 |
| 路由頁 | `AccountsView`/`CategoriesView`/`TagsView`/`TransferView.vue` | 不再外包 `.panel`,改由元件自帶面板 |

## Bug 修正(匯入頁)

1. **重選同一個檔案沒反應**
   - 現象:匯入完成或按「取消」後,再選同一個 `.xlsx` 不會出現「預覽」按鈕
   - 原因:只清掉 `selectedFile`,`<input type="file">` 的 value 還在,選同一檔案不觸發 `change`
   - 修正:匯入成功與取消時呼叫 `clearFileInput()` 清空欄位
2. **載入帳戶失敗沒有提示**
   - 現象:`fetchAccounts()` 失敗時目標帳戶下拉為空,畫面無任何訊息(且產生 unhandled promise rejection)
   - 修正:加 `.catch()`,顯示「載入帳戶失敗,請重新整理頁面」

## 驗證

- 開發環境以 Playwright + 假資料實測:帳戶新增(含空餘額錯誤訊息)/調整餘額(負數)/設為預設、分類展開/改名/搜尋、消費品項重名阻擋、匯入預覽/強制匯入/確認匯入後檔案欄位清空,API payload 與改版前一致
- `update58.sh`:sha256 比對 10 個既有檔案,腳本內建置通過才 commit;部署後 `ledger-api` active、`/` 與 `/health` 皆 200
- 使用者實測(2026-11-06):四頁操作與交易紀錄、統計頁,全部正常

## 目前狀態

E2 五頁全部完成。仍使用舊樣式/相容層的:`CategoryPicker.vue`、`TagPicker.vue`(含交易對話框內)、篩選器三元件、`TagBreakdownChart.vue`、`TopTransactionsList.vue`、登入/註冊/忘記密碼/重設密碼頁、`MembersView.vue` 的 `.field`。這些改完才能移除 `style.css`,與 E3 圖表配色一起處理。
__D59_EOF__

git add docs
git commit -m "docs: E2 帳戶/分類/消費品項/匯入匯出頁改版紀錄,同步各 feature 文件與 E2 進度"

echo
git log --oneline -3
echo
git diff HEAD~1 --stat
echo
echo "✅ 完成。確認無誤後:git push origin main(純文件異動,不需 deploy)"
