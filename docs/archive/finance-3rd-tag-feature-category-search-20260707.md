# 功能修改:消費品項(Tag)功能 + 分類管理優化 + 交易搜尋

建立日期:2026-07-07

## 一、背景與需求

分類已累積到 80 多項,衍生兩個問題:
1. 部分「店家/商家」類子分類(如「三媽」)只能掛在單一父層下,若同一店家橫跨不同餐別(午餐/晚餐都吃),就得重複建立多次同名分類,無法共用
2. 分類數量太多,不管是交易表單選分類、或篩選列選分類,下拉/逐層鑽取都不好操作

## 二、設計討論與決策

### 方案比較(店家共用問題)

| 方案 | 說明 | 決策 |
|---|---|---|
| A:分類樹改多對父層 | Category 支援多個 parent_id | ❌ 會讓分類統計(Recursive CTE)重複計算,破壞統計正確性,不採用 |
| B:改用 Tag,分類樹收斂回兩層 | 商家改用標籤,分類樹不再往下鑽第三層 | 修改既有分類樹結構,影響範圍大 |
| C(最終採用):新增獨立「消費品項」維度,不動分類樹 | 分類樹完全維持現狀,消費品項是額外的標籤維度,交易可掛 0~多個 | ✅ 採用,重用既有 `Tag`/`TransactionTag`(models.py 早已存在但未使用) |

**核心決策**:「消費品項」與「分類」是兩個正交維度,不互相取代 —— 分類負責「飲食>午餐」這類結構性歸類,消費品項負責「三媽」這種可能橫跨多個分類、需要共用的具體店家/項目名稱。

## 三、後端變更

### 新增檔案
- `app/schemas_tag.py`:`TagCreate`、`TagUpdate`、`TagOut`
- `app/routers/tags.py`:消費品項 CRUD(`GET/POST /tags`、`PATCH/DELETE /tags/{id}`),household 名稱唯一性由 DB constraint 把關
- `ledger-backend/scripts/migrate_leaf_categories_to_tags.py`:一次性資料遷移腳本(見第六節)

### 修改檔案
- `app/models.py`:`Transaction` 加 `tags` relationship(`viewonly=True`,透過既有 `transaction_tags` join table 讀取,寫入一律由 router 手動操作 `TransactionTag`)
- `app/schemas_ledger.py`:
  - `TransactionCreate`/`TransactionUpdate` 加 `tag_ids`
  - `TransactionOut` 加 `tags: list[TagOut]`
- `app/routers/transactions.py`:
  - 新增 `_validate_tag_ids`、`_set_transaction_tags` helper
  - `create_transaction`/`update_transaction` 同步處理 `TransactionTag` 關聯
  - `list_transactions` 新增 `min_amount`/`max_amount` 查詢參數(金額範圍篩選)
- `app/routers/categories.py`:`PATCH /{category_id}` 本來就支援改名(`CategoryUpdate.name`),未修改,前端補上呼叫入口即可
- `app/main.py`:掛載 `tags.router`

### 部署注意事項
- `Tag`/`TransactionTag` 資料表雖然在 `models.py` 已存在,但實際 DB 是否已建表需先確認:
  ```python
  from app.database import engine
  from sqlalchemy import inspect
  insp = inspect(engine)
  print('tags' in insp.get_table_names(), 'transaction_tags' in insp.get_table_names())
  ```
  若為 `False`,需依 `migration-sop-20260707.md` 流程補 migration 才能部署
- **Nginx 反代規則遺漏 `tags` 路徑**(見第五節 Bug 1)

## 四、前端變更

### 新增檔案
- `src/components/TagPicker.vue`:消費品項多選器(平面清單 + 搜尋 + 就地新增,不用逐層鑽取)
- `src/components/TagList.vue`:消費品項管理頁(新增/改名/刪除)
- `src/components/CategoryFilterPicker.vue`:篩選列專用的分類選擇器(按鈕觸發 + 搜尋 + 下拉結果清單,取代原生 `<select>`,80+ 分類不用捲動長清單)

### 修改檔案
- `src/api/ledger.ts`:新增 `fetchTags`、`createTag`、`updateTag`、`deleteTag`、`updateCategory`
- `src/types/ledger.ts`:新增 `TagOut`、`TagCreatePayload`;`TransactionOut` 加 `tags`;`TransactionCreatePayload` 加 `tag_ids`;`TransactionFilters` 加 `min_amount`/`max_amount`
- `src/components/CategoryPicker.vue`:新增分類時,若同層級已有同名分類,直接擋掉並提示「請直接選擇現有分類」
- `src/components/CategoryTreeNode.vue`:分類節點加入「改名」按鈕(inline 編輯,同層重複名稱阻擋)
- `src/components/CategoryList.vue`:新增 `handleRename`,串接 `updateCategory` API
- `src/components/TransactionList.vue`:
  - 新增/編輯表單都加上 `TagPicker`(消費品項多選)
  - 交易卡片消費品項改為獨立彩色標籤(chip)顯示,不再與帳戶/備註文字混在同一行
  - 篩選列新增金額範圍(最低/最高)輸入框
  - 篩選列分類選擇改用 `CategoryFilterPicker`
- `src/views/DashboardView.vue`:新增「消費品項」管理 tab

## 五、Bug 修復紀錄

### 1. Nginx 反代規則遺漏 `tags` 路徑,導致消費品項功能完全打不通

| 項目 | 內容 |
|---|---|
| 現象 | 消費品項新增失敗;消費品項清單顯示「一堆刪除按鈕」 |
| 原因 | `infra-public-access-20260707.md` 的 Nginx `location ~ ^/(auth\|households\|accounts\|categories\|transactions\|stats)(/\|$)` 白名單沒有列進 `tags`,所有 `/tags` 請求被 SPA catch-all(`try_files ... /index.html`)接住,回傳的是前端 `index.html` 的 HTML 字串而非 JSON |
| 附帶現象解釋 | `fetchTags()` 拿到 HTML 字串當作陣列賦值給 `tags.value`,`v-for` 對字串跑迴圈會**逐字元**渲染,因此出現「一堆刪除按鈕」(其實是 HTML 字串被一個字元一個字元渲染成清單項目) |
| 修正 | Nginx regex 加上 `tags`:`^/(auth\|households\|accounts\|categories\|transactions\|stats\|tags)(/\|$)`,此設定不在 git 版控範圍,需手動修改 server 上的 `/etc/nginx/sites-available/ledger-api` 並 `nginx -t && systemctl reload nginx` |

### 2. update18.sh 執行失敗:檔案內容誤植

| 項目 | 內容 |
|---|---|
| 現象 | `./update18.sh` 報一連串 `import: command not found`、`File name too long` |
| 原因 | 複製貼上時把「遷移腳本的 Python 內容」貼進了 `update18.sh`,bash 把 Python docstring / `import` 當成 shell 指令執行 |
| 排查方式 | `head -20 update18.sh` 確認實際檔案內容與預期不符 |
| 修正 | 刪除重建 `update18.sh`,確保 heredoc 完整包住 bash 腳本本體,執行前先 `head -5` 確認開頭是 `#!/usr/bin/env bash` |

## 六、一次性資料遷移:第三層分類 → 消費品項

### 目的
既有分類樹裡「早餐>日牧」「午餐>三媽」「晚餐>阿將/天使雞排/龍品」等第三層節點,本質上是消費品項而非分類結構,遷移後改用消費品項表示,分類樹收斂回既有的兩層(大類>細項)。

### 腳本邏輯(`ledger-backend/scripts/migrate_leaf_categories_to_tags.py`)
1. 找出所有 depth≥3、且自己沒有子分類的葉節點
2. 依 `(household_id, name, type)` 分組(同名視為同一個消費品項,解決共用問題)
3. 每組建立(或重用既有同名)Tag,將該分類底下所有交易的 `category_id` 改指向父層,並掛上該 Tag
4. 刪除已轉換的舊分類節點
5. 安全機制:
   - 若節點自己還有子分類(結構超出預期)→ 跳過並列出警告,不處理
   - 若節點被 `Budget` 引用(刪除會 cascade 砍掉預算)→ 保留節點不刪除,只做交易改指向+掛標籤,列出警告待人工確認
   - 預設 dry-run(僅預覽,不寫入),需加 `--execute` 才真正執行
   - 全程單一 DB transaction,失敗自動 rollback

### 實際執行結果

```
共發現 5 個待轉換分類節點,分成 5 個消費品項群組:
  [expense] 「日牧」 <- 早餐 (節點數:1, 交易筆數:3)
  [expense] 「三媽」 <- 午餐 (節點數:1, 交易筆數:5)
  [expense] 「阿將」 <- 晚餐 (節點數:1, 交易筆數:0)
  [expense] 「天使雞排」 <- 晚餐 (節點數:1, 交易筆數:5)
  [expense] 「龍品」 <- 晚餐 (節點數:1, 交易筆數:1)
預計影響交易筆數合計:14
```

- ✅ dry-run 確認無警告(無子分類衝突、無 Budget 引用衝突)後執行 `--execute`
- ✅ 5 個消費品項建立成功,14 筆交易改指向父層分類並掛上對應消費品項
- ✅ 瀏覽器驗證:交易紀錄分類正確變成「早餐」/「午餐」/「晚餐」,消費品項標籤正確顯示;分類管理頁確認舊子分類已消失

## 七、目前狀態

- ✅ 消費品項 CRUD(新增/改名/刪除)已上線並測試通過
- ✅ 交易新增/編輯表單可掛 0~多個消費品項,不影響既有分類樹
- ✅ 分類/消費品項新增時,同層級或household內重複名稱會被阻擋並提示
- ✅ 分類管理頁新增改名功能,同層重複名稱阻擋
- ✅ 交易紀錄新增金額範圍篩選,搭配既有分類/日期篩選
- ✅ 篩選列分類選擇改為按鍵式搜尋(`CategoryFilterPicker`),取代 80+ 項下拉選單
- ✅ 消費品項標籤改為獨立彩色顯示,字體加大,與帳戶/備註分開排列
- ✅ 舊有第三層「店家」分類已透過遷移腳本轉換完成

## 八、後續可考慮事項

1. 消費品項目前沒有「依消費品項統計」功能(例如「三媽總共花多少」),若有需求可另開 `stats` endpoint,重用 `TransactionTag` 關聯做加總
2. `CategoryFilterPicker` 與 `CategoryPicker`/`TagPicker` 目前是三個獨立元件,若日後篩選邏輯與新增邏輯需求趨於一致,可評估是否合併或抽共用邏輯,降低維護成本
3. 遷移腳本執行後舊分類節點已刪除,若未來需要追溯「這筆交易原本的三層分類長怎樣」,目前沒有保留歷史記錄,僅能從 `audit_logs` 或備份資料回溯
