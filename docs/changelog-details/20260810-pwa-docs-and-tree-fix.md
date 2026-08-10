# 文件核對:PWA 現況記錄 + server 目錄樹修正

## 一、背景

推進 A 系列統計功能討論的過程中,`deploy.sh` 的 build log 出現 `vite-plugin-pwa` 相關輸出(`sw.js`/`workbox-*.js`),但這件事完全沒有記錄在任何現有文件裡。追查 `vite.config.ts` 後確認前端確實裝了 PWA plugin,順便對照先前 `tree` 指令的實際輸出,核對出 `ops-server-requirements.md` 的目錄樹也有多處過時(缺 `audit.py`/`schemas_tag.py`/`schemas_import_export.py`/`validators.py`/`services/` 等實際存在的檔案)。

## 二、決策

- **PWA**:核對後確認目前生產環境無 HTTPS,Service Worker 規範上不會註冊,PWA 功能形同虛設(離線快取、可安裝成 App 皆不生效),但不影響現有功能運作。決定**維持現狀不處理**——不移除 plugin,也暫不特別解決 HTTPS,純粹先把現況記錄進文件,待 HTTPS 問題解決後再回頭檢視。
- **目錄樹**:趁這次一併核對修正,避免文件與實際程式碼落差持續擴大。

## 三、修改內容(文件,無程式碼變動)

- `ops/ops-infra-public-access.md`:「已知限制/風險」章節新增 PWA 形同虛設的說明,歸類為與無 HTTPS 同一根因
- `ops/ops-server-requirements.md`:
  - 前端目錄樹補上 `vite.config.ts`(PWA plugin 設定)、修正 `views/`/`components/` 清單(補 `DateRangePicker`、`RegisterHouseholdView`、`AuditLogView` 等實際存在但先前未列出的項目)
  - 後端目錄樹補上 `audit.py`、`schemas_tag.py`、`schemas_import_export.py`、`validators.py`、`services/excel_transfer.py`、`reset_password.py`(管理員重設密碼 CLI)

## 四、目前狀態

- ✅ PWA 現況已記錄,決策為維持不動
- ✅ server 目錄樹與實際程式碼結構一致
- ⏳ 待 HTTPS 問題解決(見 `ops/ops-infra-public-access.md` 緩解方案)後,回頭檢視 PWA 是否要正式啟用
