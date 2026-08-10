# Bug 修復紀錄:Dashboard 標題顯示錯誤 household 名稱

建立日期:2026-07-07

## 一、本次修復項目

### 1. Dashboard 標題寫死,未顯示實際 household 名稱

| 項目 | 內容 |
|---|---|
| 現象 | 登入後首頁(`DashboardView.vue`)標題固定顯示「家庭理財」;成員管理頁(`MembersView.vue`)則正確顯示使用者建立時輸入的名稱(如「洪不讓理財本」),兩頁顯示不一致 |
| 原因 | `DashboardView.vue` 的 `<h1>` 直接寫死字串 `家庭理財`,未綁定任何動態資料;`auth.ts`(Pinia store)也只存 `householdId`,未存 household 名稱 |
| 修正 | 複用 `MembersView.vue` 已使用的 `fetchMyHousehold()`(`@/api/auth`),於 `DashboardView.vue` `onMounted` 時呼叫,並將 `<h1>` 改為 `{{ household?.name ?? '家庭理財' }}` |
| 修正檔案 | `ledger-frontend/src/views/DashboardView.vue`(`update8.sh`) |
| 設計考量 | household 名稱屬頁面層資料,非全域認證狀態,故不寫入 `auth.ts` store,避免過度耦合;API 失敗時 fallback 顯示預設文字「家庭理財」,不阻斷主頁渲染 |
| 復發原因 | 首次改版腳本(`update8.sh` 第一版)依據舊版 `DashboardView.vue`(update7.sh 之前)撰寫字串比對,但檔案已因 `update6.sh`/`update7.sh` 加入 `CategoryBreakdownChart`、`DateRangePicker`、統計子分頁等內容而變動,`python3` 字串比對不符,腳本中止(未 commit),需依 server 實際檔案內容重寫腳本後才修正成功 |

## 二、驗證

- ✅ `update8.sh`(依實際檔案內容重寫版本)執行成功,已 commit / push / deploy
- ✅ 瀏覽器強制重整後測試:Dashboard 標題與成員管理頁一致顯示實際 household 名稱

## 三、教訓

1. **`updateN.sh` 撰寫前務必先 `cat` server 上檔案目前實際內容**,不可依過往版本或記憶假設檔案內容,尤其該檔案近期有多次異動(`update6.sh`/`update7.sh`)時風險更高
2. **共用資料來源優先複用既有 API**:`MembersView.vue` 已有 `fetchMyHousehold()`,直接複用即可,不需在 `ledger.ts` 或後端新增重複 endpoint
3. **頁面層資料與全域認證狀態分離**:非所有跨頁資料都該塞進 Pinia store,household 名稱僅 Dashboard 標題顯示用,各頁各自 `onMounted` 抓取即可,降低 store 耦合度
