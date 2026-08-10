# CHANGELOG

只放「最近 2 個月」的一行式索引,詳細內容請點連結進 `changelog-details/`。超過 2 個月的索引會依半年封存進 `changelog-archive/`(規則見 `PROJECT-OVERVIEW.md` 開發慣例章節)。

## 2026-08

- 08-10 docs: 記錄前端 PWA plugin 現況(無 HTTPS 下形同虛設)+ 修正 server 目錄樹過時項目 → [詳情](changelog-details/20260810-pwa-docs-and-tree-fix.md)
- 08-10 docs/fix: 釐清 A10 自訂區間統計已完成(文件先前誤列尚未開始);`tag-breakdown` 的 `start_date`/`end_date` 改為選填+預設,與其他統計 API 一致 → [詳情](changelog-details/20260810-a10-clarify-tag-breakdown-fix.md)
- 08-10 feat: 新增管理員手動重設密碼 CLI(Postfix 忘記密碼信件入口暫停期間的臨時替代方案) → [詳情](changelog-details/20260810-admin-reset-password-cli.md)

## 2026-07

- 07-13 fix: 分類統計下鑽補「本分類直接交易」項目(頂層/下鑽 CTE 起點不一致導致金額對不起來,`stats.py` 修正 + `update46/47.sh` 部署) → [詳情](changelog-details/20260713-category-breakdown-self-amount.md)
- 07-10 feat: 交易紀錄消費品項篩選 + 篩選 UI 改為進階篩選面板(帳戶/分類篩選器改版) → [詳情](changelog-details/20260710-transaction-tag-filter-advanced-search.md)
- 07-08 feat: 統計圖表加入消費品項排行(長條圖,非圓餅圖)+ 部署中斷 bug 修復(`TransactionType`/`date` import) → [詳情](changelog-details/20260708-tag-breakdown-stats.md)
- 07-08 feat: 消費品項(Tag)UX 改善 —— 搜尋、使用統計、最近使用分區、Chip 版面 → [詳情](changelog-details/20260708-tag-ux-improvement.md)
- 07-08 fix: Excel 匯入/匯出功能(帳戶餘額未更新、格式死板、中文檔名 500、下載檔名前端寫死) → [詳情](changelog-details/20260708-excel-import-export-fix.md)
- 07-08 feat: 分類管理頁 UX 改善 —— 搜尋改名/刪除、移除多餘選取提示 → [詳情](changelog-details/20260708-category-management-search.md)
- 07-08 feat: 帳本改名 + 名稱防呆 + 封存/解封 + CLI 永久刪除 → [詳情](changelog-details/20260708-household-management.md)
- 07-08 fix: 歷史資料回補 —— 帳戶餘額重新計算腳本 → [詳情](changelog-details/20260708-account-balance-recalc.md)
- 07-08 sop: update.sh/deploy.sh 增修(自動歸檔 + 自動產出腳本檔案)→ 已整併進 `ops/ops-deployment.md`,原始版本見 `archive/deploy-sop-auto-archive-file-output-20260708.md`
- 07-07 feat: 消費品項(Tag)功能 + 分類管理優化 + 交易搜尋,含分類樹第三層遷移為 Tag → [詳情](changelog-details/20260707-tag-feature-launch.md)
- 07-07 feat: 登入效期延長(1天→30天)+ 成員刪除功能 → [詳情](changelog-details/20260707-session-member-delete.md)
- 07-07 fix: Dashboard 標題顯示錯誤 household 名稱 → [詳情](changelog-details/20260707-household-name-fix.md)
- 07-07 fix: A3 分類統計 bug 修復彙整(`category_id` UUID 型別、flex 無界延伸)+ 歷史踩坑彙整 → [詳情](changelog-details/20260707-bug-fix-batch.md)
- 07-07 feat: 交易分類編輯 UX 優化(CategoryPicker 搜尋功能) → [詳情](changelog-details/20260707-category-picker-search.md)
- 07-07 feat: 月收支趨勢圖 + 結餘計算(A1+A2),連帶完成部署架構轉正式環境 → [詳情](changelog-details/20260707-monthly-trend-balance.md)
- 07-07 feat: Excel 匯入/匯出功能初版上線 → [詳情](changelog-details/20260707-excel-import-export-launch.md)
- 07-07 infra: 對外連線改用 FortiGate + Nginx(取代原規劃的 Cloudflare Tunnel) → 已整併進 `ops/ops-infra-public-access.md`
- 07-07 sop: GitHub / Git 化部署流程建立 → 已整併進 `ops/ops-github-workflow.md`
- 07-07 sop: update.sh/deploy.sh 標準作業流程初版 → 已整併進 `ops/ops-deployment.md`,原始版本見 `archive/update-deploy-sop-20260707.md`
