# 備份與災難復原

2026-11-03 原 FinanceServer VM 隨 ESXi 主機 SSD 故障一併遺失,且**當時完全沒有備份**,資料庫無法救回(事件經過見 `changelog-details/20261103-server-rebuild-ssd-failure.md`)。本文件記錄重建後建立的備份機制與還原流程。

## 一、備份架構(兩層)

| 層級 | 內容 | 頻率 / 保留 | 存放位置 | 用途 |
|---|---|---|---|---|
| 第一層:資料庫 | `pg_dump -Fc ledger_db` + `ledger-backend/.env` | 每日 02:00,保留 3 天(可調) | VM 本機 `/var/backups/ledger/` + SMB `//192.168.100.107/dbbackup/finance/` | **主要保護**。任何主機掛掉都能救回帳本資料 |
| 第二層:整台 VM | Proxmox vzdump(pve02 上所有 VM) | 每日 02:30,保留 7 天 | Proxmox 本機 SATA 1TB(storage `sata1t`) | 快速整台還原(含 Nginx、systemd、`.env`) |
| 第二層:整台 VM(異機) | Proxmox vzdump(pve02 上所有 VM) | 每日 04:00,保留 4 天 | Windows 192.168.100.107 `E:\ProxmoxBackup`(storage `win10-backup-pve02`) | Proxmox 主機整台故障時的整台還原 |

**關鍵原則**:備份一定要有一份放在**另一台實體設備**上。目前資料庫(第一層)與整台 VM(第二層 `win10-backup-pve02`)都各有一份在 192.168.100.107。

## 二、第一層:`ledger-backup`

### 1. 檔案位置

| 用途 | 路徑 |
|---|---|
| 工具本體 | `/usr/local/sbin/ledger-backup`(原始檔:本機 `Finance\Developing\ledger-backup.sh`) |
| 設定檔 | `/etc/ledger-backup.conf`(權限 600) |
| SMB 帳密 | `/etc/ledger-backup.cred`(權限 600,帳號 `bkadmin`) |
| 排程 | `ledger-backup.timer` / `ledger-backup.service`(systemd) |
| 本機備份 | `/var/backups/ledger/ledger_YYYYMMDD_HHMMSS.tar.gz` |
| 還原前自動備份 | `/var/backups/ledger/pre-restore/` |
| SMB 備份 | `\\192.168.100.107\dbbackup\finance\` |

備份檔 `ledger_YYYYMMDD_HHMMSS.tar.gz` 內含:
- `ledger_db.dump`:`pg_dump -Fc` 格式,產生後立即用 `pg_restore -l` 驗證可讀
- `env`:`.env` 副本(含 `SECRET_KEY`、DB 密碼)

> ⚠️ 備份檔含機密(`SECRET_KEY`、DB 密碼),SMB 分享資料夾只能開放給 `bkadmin` 與管理員。

### 2. 指令

| 用途 | 指令 |
|---|---|
| 立即備份 | `ledger-backup run` |
| 調整保留天數 | `ledger-backup set-retention 7` |
| 調整每日備份時間 | `ledger-backup set-time 03:00` |
| 列出本機與 SMB 備份 | `ledger-backup list` |
| 排程狀態 / 最近執行紀錄 | `ledger-backup status` |
| 還原 | `ledger-backup restore ledger_20261103_020000.tar.gz` |
| 重新設定 SMB 帳密 | `ledger-backup install` |

### 3. 運作細節

- **保留天數 N** = 保留「今天往前 N-1 天」到今天的所有檔案,依**檔名日期**判斷(含手動備份)。本機與 SMB 套用相同天數
- SMB 每次備份時才掛載,用完即卸載,不常駐;複製後以 `cmp` 比對兩邊一致
- SMB 失敗時本機備份仍保留,指令回傳非 0(`systemctl status ledger-backup.service` 會顯示 failed)
- 排程 `Persistent=true`:VM 在 02:00 關機的話,開機後會補跑一次
- 用 `flock` 防止同時執行兩份備份
- 目前**無失敗通知**(2026-11-03 決定先不做),需定期 `ledger-backup status` 檢查

### 4. 還原(只還原資料庫)

```bash
ledger-backup list                       # 找出要還原的檔名
ledger-backup restore <檔名>              # 需輸入 YES 確認
```

流程:本機找不到檔案會自動從 SMB 取回 → 驗證 dump → **先備份目前狀態到 `pre-restore/`** → 停 `ledger-api` → `pg_restore --clean --if-exists` → 啟動 `ledger-api`。

備份中的 `.env` 與目前不同時,不會自動覆蓋,另存為 `/var/backups/ledger/restored.env`。若要讓舊的登入 token 繼續有效,把其中的 `SECRET_KEY` 換回 `ledger-backend/.env` 後 `systemctl restart ledger-api`。

## 三、第二層:Proxmox 整台 VM 備份

### 1. 現行設定(2026-11-03 建立並測試完成)

Datacenter → Backup:

| Schedule | Storage | 實際位置 | Retention | Selection |
|---|---|---|---|---|
| 每日 02:30 | `sata1t` | pve02 本機 SATA 1TB | `keep-daily=7` | All(pve02 上所有 VM) |
| 每日 04:00 | `win10-backup-pve02` | 192.168.100.107 `E:\ProxmoxBackup\pve02\dump` | `keep-daily=4` | All |

- Selection 為 All,目前包含 205 `finance-server` 與 223 `esi-webserver-bk`,之後新增的 VM 也會自動納入
- 首次手動備份大小:205 約 2.89 GiB、223 約 3.92 GiB(zstd 壓縮),每日約 7 GiB;`sata1t` 7 天約 50 GiB、`win10-backup-pve02` 4 天約 28 GiB。新增 VM 時記得確認 192.168.100.107 的 `E:` 剩餘空間
- 02:30 與 02:00 資料庫備份相隔 30 分鐘,資料庫備份數秒內完成,不會互相干擾
- VM 已安裝 `qemu-guest-agent`,Snapshot 模式會先凍結檔案系統,備份一致性較佳
- 確認備份成功:`.log` 最後一行應為 `INFO: Finished Backup of VM <id>`;`.tmp` / `.vma.dat` 表示仍在進行中

### 2. 重新建立(Proxmox 重灌時)

1. Datacenter → Storage:確認 `sata1t`(Directory)與 `win10-backup-pve02`(SMB/CIFS → `//192.168.100.107`)的 Content 含 **VZDump backup file**
2. Datacenter → Backup → Add:依上表建立兩個排程,Mode `Snapshot`、Compression `ZSTD`
3. 選取排程 → **Run now**,完成後到 storage → Backups 確認有檔案

### 3. 還原整台 VM

`sata1t`(或 `win10-backup-pve02`)→ Backups → 選備份 → Restore。新的 Proxmox 主機要從 Windows 還原時,先把 `win10-backup-pve02` 加回 Storage 即可看到備份。若原 VM 205 仍在,會被覆蓋;要並存測試則改用新 VMID 並**先拔掉網路**,避免和 192.168.100.205 IP 衝突。

## 四、災難復原:主機整台不見時

前提:SMB 上有 `ledger_*.tar.gz`。

1. 建立新 VM:Ubuntu Server **24.04** LTS、固定 IP `192.168.100.205`、時區 `Asia/Taipei`(規格見 `ops/ops-server-requirements.md`)
2. 執行 `rebuild-server.sh`(本機 `Finance\Developing\`),依提示把新的 deploy key 加到 GitHub(勾選 Allow write access,見 `ops/ops-github-workflow.md`)
3. 上傳 `ledger-backup.sh` → `./ledger-backup.sh install`(SMB 路徑 `//192.168.100.107/dbbackup/finance`,子資料夾 `.`)
4. `ledger-backup list` → `ledger-backup restore <最新檔名>`
5. 用 `restored.env` 的 `SECRET_KEY` 取代新 `.env` 的 `SECRET_KEY`(可選,讓使用者不用重新登入)
6. 瀏覽器確認 `http://192.168.100.205:17756/` 資料正確

預估 20-30 分鐘(大部分是 `npm` build)。

### `rebuild-server.sh` 重點

- baseline migration `6f900ce6a7ff` 是**空的**(原始資料表不是 migration 建的),全新 DB 直接 `alembic upgrade head` 會失敗。腳本改為 `Base.metadata.create_all()` 建表 + `alembic stamp head`;已有資料表時才走 `alembic upgrade head`
- 會自動產生新的 DB 密碼與 `SECRET_KEY`;`.env` 已存在時沿用、不覆蓋
- 可重複執行,已完成的步驟會略過
- Python 套件版本(`requirements.txt`)需要 Python 3.12,**不要用 Ubuntu 26.04**;Vite 8 需要 Node ≥ 20.19,腳本改用 NodeSource 22.x

## 五、定期檢查

| 頻率 | 項目 |
|---|---|
| 每週 | `ledger-backup status`:`LAST` 有在跑、紀錄沒有 ❌;Windows 上確認 `\\192.168.100.107\dbbackup\finance` 有最近 3 天的檔案;Proxmox Datacenter → Backup 的任務紀錄(Tasks)沒有失敗 |
| 每季 | **還原演練**:另建測試 VM(或在 VM 上用 `restore` 還原後再還原回來),確認備份檔真的能用 |
| 主機變動時 | Proxmox 換碟、Windows 備份主機改密碼/改 IP → 重跑 `ledger-backup install` |
