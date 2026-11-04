# 2026-11-04 ledger-backup 還原 bug 修正 + 首次還原演練

## 現象

第一次執行 `ledger-backup restore ledger_20261104_100040.tar.gz` 時:

```
pg_restore: error: could not open input file "/tmp/tmp.vC5jcE6dxF/ledger_db.dump": Permission denied
⚠️  pg_restore 有回報錯誤(常見為無害的權限訊息),請確認網站資料是否正確
```

資料庫實際上**完全沒有被還原**,但訊息讓人以為只是無害警告。

## 原因

1. 備份檔解壓到 `mktemp -d` 建立的暫存目錄(權限 700,只有 root 可讀),但 `pg_restore` 以 `sudo -u postgres` 執行,讀不到檔案
2. `pg_restore` 失敗時的訊息寫成「常見為無害的權限訊息」,錯誤判斷

## 修正

```bash
# 由 root 讀檔,經 stdin 交給 postgres 身分的 pg_restore
if sudo -u postgres pg_restore --clean --if-exists -d "$DB_NAME" < "$tmp/ledger_db.dump"; then
  log "✅ 資料庫還原完成"
else
  log "❌ pg_restore 失敗,資料庫可能未還原或只還原一部分,請檢查上方錯誤訊息"
  log "   還原前的狀態在 $safety,可用 pg_restore 手動還原"
fi
```

已更新 `/usr/local/sbin/ledger-backup` 與原始檔(本機 `Finance\Developing\ledger-backup.sh`)。備份(`pg_dump`)不受影響:輸出由 root 的 shell 重新導向寫檔,權限沒有問題。

## 還原演練結果

| 步驟 | 結果 |
|---|---|
| 1. `ledger-backup run` → `ledger_20261104_100040.tar.gz` | ✅ 本機 + SMB 比對一致 |
| 2. 網頁新增一筆收入 500 | ✅ |
| 3. `ledger-backup restore ledger_20261104_100040.tar.gz` | ✅ 先自動備份到 `pre-restore/pre-restore_20261104_100615.tar.gz`,再還原 |
| 4. 網頁確認 | ✅ 500 那筆消失,其餘帳本、帳戶、交易都在,可正常登入 |

結論:備份 → 異機存放 → 還原整條流程可用。之後每季演練一次(見 `ops/ops-backup.md` 第五節)。
