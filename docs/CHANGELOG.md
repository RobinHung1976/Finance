# CHANGELOG

只放「最近 2 個月」的一行式索引,詳細內容請點連結進 `changelog-details/`。超過 2 個月的索引會依半年封存進 `changelog-archive/`(規則見 `PROJECT-OVERVIEW.md` 開發慣例章節)。

## 2026-11

- 11-04 fix: `ledger-backup restore` 讀不到備份檔(postgres 身分無法讀 root 暫存目錄)+ 首次還原演練成功 → [詳情](changelog-details/20261104-restore-drill-fix.md)
- 11-03 infra: ESXi 主機 SSD 故障導致 FinanceServer VM 與資料庫遺失(無備份);改於 Proxmox VM 205 以 `rebuild-server.sh` 重建(資料庫為空)→ [詳情](changelog-details/20261103-server-rebuild-ssd-failure.md)
- 11-03 ops: 新增每日資料庫備份 `ledger-backup`(VM 本機 + SMB 192.168.100.107,保留 3 天)與災難復原流程 → 見 `ops/ops-backup.md`
- 11-03 docs: `CHANGELOG.md` 輪替,2026-07、2026-08 索引封存至 `changelog-archive/CHANGELOG-2026-H2.md`
