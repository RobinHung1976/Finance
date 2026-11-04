# 2026-11-03 FinanceServer 主機 SSD 故障、資料遺失與重建

## 現象

ESXi 主機(192.168.100.229)上,`FinanceServer`、`OVOC-8-2-1342`、`rbsbcha01`、`ESI-WebServer-Backup` 四台 VM 狀態顯示「無效」,名稱變成 `.vmx` 路徑;datastore `SSD01` 容量 0 B。

## 原因

`SSD01` 所在的 Transcend **TS1TSSD230S 1TB SSD** 硬體故障:

| 時間 | 跡象 |
|---|---|
| 一開始 | 所有寫入指令失敗(`Cmd 0x2a`,sense `0x4/0x44` Hardware Error / Internal target failure),VMFS 需寫入鎖定資料,因此無法掛載。讀取仍正常 |
| SMART | Health 顯示 OK,但 Reallocated Sector Count 215、Reallocation Event 129,快閃記憶體已大量出現壞區塊 |
| 救援過程中 | 讀取也開始失敗(`READ DMA EXT` / `ABRT`),最後連 VMFS 中繼資料區都讀不到,`vmfs6-fuse` 無法開啟檔案系統 |

這顆 SSD 同時是 ESXi 的開機碟,拔除後 ESXi 主機無法開機。

## 救援嘗試(失敗)

1. 用 Ubuntu Live USB 接上 SSD,以 `vmfs6-tools`(Ubuntu 26.04 套件庫已移除,改裝 `vmfs6-tools_0.2.1-1build2_amd64.deb`)唯讀掛載,一度可列出 FinanceServer 檔案(`-flat.vmdk` 最後修改 11/2 00:27)
2. `rsync` 複製到本機 NTFS 分割時,速度在 ESI-WebServer-Backup 的資料區掉到 145 kB/s,dmesg 出現大量讀取錯誤
3. 改用 `ddrescue` 前,VMFS 目錄區已無法讀取,救援中止
4. **沒有任何其他備份**,決定放棄舊資料、重建

教訓:發現 SSD 可讀時應**第一時間用 `ddrescue` 對整個分割做映像**(一次讀完、跳過壞區塊),而不是逐檔 `rsync`;也應**先救最重要的 FinanceServer**(rsync 依字母順序先處理了 ESI)。

## 影響

- **帳本資料全部遺失**(PostgreSQL 在 VM 內):household、使用者、帳戶、分類、交易、消費品項皆無法救回
- 程式碼無影響(在 GitHub `RobinHung1976/Finance`)
- server 上的 `/root/apps/docs` 文件集一併遺失;Claude 專案與本機 `Finance\reorg\` 有副本

## 重建內容

### 主機

| 項目 | 舊 | 新 |
|---|---|---|
| Hypervisor | ESXi(192.168.100.229) | **Proxmox VE**(node `pve02`),系統碟 512GB SSD,備份碟 SATA 1TB(原 Seagate ST1000DM003,已清空) |
| VM | FinanceServer | **VM 205 `finance-server`**:q35、2 vCPU(x86-64-v2-AES)、4 GB RAM、50 GB(local-lvm,discard/ssd)、virtio 網卡 vmbr0 |
| OS | — | Ubuntu Server 24.04 LTS,使用者 `fiadmin`,時區 `Asia/Taipei`,已裝 `qemu-guest-agent` |
| IP | 192.168.100.205 | 沿用 192.168.100.205(FortiGate VIP 不用改) |

### 應用程式

以新的 `rebuild-server.sh` 一次完成:PostgreSQL、clone repo、`.env`、venv、建表、`ledger-api` systemd、前端 build、Nginx(:17756)、ufw。

- **資料表建立方式**:baseline migration `6f900ce6a7ff` 為空,全新 DB 無法 `alembic upgrade head`,改用 `Base.metadata.create_all()` + `alembic stamp head`
- **新的 `SECRET_KEY` 與 DB 密碼**:舊值已遺失,重新產生
- **GitHub deploy key**(Title `Finance-Server`)重建時先設為唯讀;評估改由 Windows 本機 commit/push 不便後,2026-11-04 決定維持原流程(server 上 commit/push),key 重新加回並開啟 write access
- 確認 `docs/` 屬於 Finance repo(`PROJECT-OVERVIEW.md` 第三節原記載為獨立,已更正)
- 腳本 bug 修正:GitHub 認證成功時 `ssh -T` 仍回傳 1,搭配 `set -o pipefail` 被誤判為失敗、卡在貼 key 的迴圈 → 改為 `{ ssh -T github-finance 2>&1 || true; } | grep -q "successfully authenticated"`

重建後驗證:11 張資料表皆存在、`alembic_version` 1 筆,其餘 0 筆,需重新註冊帳本。

### 備份(本次新增)

見 `ops/ops-backup.md`。第一層 `ledger-backup` 已上線:每日 02:00 備份資料庫 + `.env` 到 VM 本機與 `//192.168.100.107/dbbackup/finance`,保留 3 天;首次備份 `ledger_20261103_165411.tar.gz` 兩邊比對一致。

## 目前狀態

- ✅ Finance 服務重建完成,資料庫為空
- ✅ 第一層每日資料庫備份上線
- ✅ 第二層 Proxmox 整台 VM 備份上線:每日 02:30 → `sata1t`(保留 7 天)、04:00 → 192.168.100.107 `win10-backup-pve02`(保留 4 天),首次備份已完成
- ⏳ 還原演練尚未執行
- ⏳ `/root/apps/docs` 文件集需從副本放回 server
