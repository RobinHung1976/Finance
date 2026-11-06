# CHANGELOG

只放「最近 2 個月」的一行式索引,詳細內容請點連結進 `changelog-details/`。超過 2 個月的索引會依半年封存進 `changelog-archive/`(規則見 `PROJECT-OVERVIEW.md` 開發慣例章節)。

## 2026-11

- 11-06 feat/fix: 帳戶/分類/消費品項/匯入匯出頁改用金屬主題(表格、LED 按鍵、統計卡片),E2 五頁完成;修正匯入完成後無法重選同一檔案、載入帳戶失敗無提示 → [詳情](changelog-details/20261106-e2-pages-restyle.md)
- 11-06 feat: 交易紀錄頁改為查詢面板 + 報表表格(統計卡片、排序、搜尋、類型篩選),新增/編輯改對話框,匯出 CSV(完成 C1) → [詳情](changelog-details/20261106-transactions-report-view.md)
- 11-06 feat/fix: 前端金屬主題 + 側欄版面(`AppLayout`),Dashboard 六個分頁改子路由;修正統計頁「今天」在台北 08:00 前變成前一天(`toISOString()` UTC) → [詳情](changelog-details/20261106-ui-metal-theme-layout.md)
- 11-04 fix: `ledger-backup restore` 讀不到備份檔(postgres 身分無法讀 root 暫存目錄)+ 首次還原演練成功 → [詳情](changelog-details/20261104-restore-drill-fix.md)
- 11-03 infra: ESXi 主機 SSD 故障導致 FinanceServer VM 與資料庫遺失(無備份);改於 Proxmox VM 205 以 `rebuild-server.sh` 重建(資料庫為空)→ [詳情](changelog-details/20261103-server-rebuild-ssd-failure.md)
- 11-03 ops: 新增每日資料庫備份 `ledger-backup`(VM 本機 + SMB 192.168.100.107,保留 3 天)與災難復原流程 → 見 `ops/ops-backup.md`
- 11-03 docs: `CHANGELOG.md` 輪替,2026-07、2026-08 索引封存至 `changelog-archive/CHANGELOG-2026-H2.md`
