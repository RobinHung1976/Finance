# 功能修改:分類統計下鑽補「本分類直接交易」項目

建立日期:2026-07-13

## 一、背景與現象

使用者在「統計 > 支出分類統計」查看 Dean 這個分類時:

- 頂層畫面(未下鑽):Dean 總額 44110
- 點進去下鑽 Dean 之後,子分類加總只有 23260
- 到「消費品項排行」查「居仁-Dean」看到 10060,但這是另一個維度的數字,跟分類缺口對不上,也不該拿來湊

落差 44110 - 23260 = 20850,使用者無法得知 Dean 這個分類實際花了什麼錢。

## 二、原因

`stats.py` 的 `category-breakdown` API 用 Recursive CTE(`cat_tree`)做分類樹彙總,起點行為在頂層與下鑽兩種情境不一致:

- **頂層呼叫**(`parent_id=None`):CTE 起點是「所有頂層分類」,分類自己的 `id` 就是 `root_id`,所以直接掛在 Dean 本身(未再歸類到任何子分類)的交易,也會被算進 Dean 的彙總 → 這是 44110 的組成
- **下鑽呼叫**(`parent_id=Dean.id`):CTE 起點變成「Dean 的子分類們」,Dean 自己不在樹裡,直接掛在 Dean 本身的交易在下鑽畫面完全撈不到 → 這是只有 23260 的原因

前端 `CategoryBreakdownChart.vue` 忠實呈現後端回傳資料,問題完全在後端 SQL 邏輯,不是前端顯示錯誤。

## 三、修正內容

### 後端

- `app/routers/stats.py`
  - 新增 `_CATEGORY_SELF_DIRECT_SQL`:下鑽情境下,額外查一次「`category_id = 該分類本身`」的直接交易加總
  - `category_breakdown`:當 `parent_id` 不為 `None` 且直接交易加總 > 0 時,補一個 `is_self=true` 的項目進 `items`,`category_name` 顯示為「`<分類名稱>(直接歸類,未再細分)`」,`has_children` 固定 `false`
  - 補 `from app.models import Category` 取得分類名稱
  - 總額與百分比改為補完項目後統一重新計算,確保下鑽畫面加總 = 頂層總額
- `app/schemas_ledger.py`
  - `CategoryBreakdownItem` 新增 `is_self: bool = False`

### 前端

- `src/types/ledger.ts`:`CategoryBreakdownItem` interface 補上 `is_self: boolean`(update46.sh 漏改,導致 `vue-tsc` 型別檢查失敗、`deploy.sh` 中止在 `npm run build`,由 update47.sh 補上)
- `src/components/CategoryBreakdownChart.vue`:圖表 `backgroundColor` 依 `is_self` 判斷,固定用中性灰(`#9CA3AF`)呈現,與其他子分類的彩色區隔;`has_children` 為 `false`,沿用既有邏輯即不會誤觸下鑽

### 未變動

- 未修改 `models.py`,無需 Alembic migration
- `tag-breakdown`(消費品項排行)、`monthly-trend`(月收支趨勢)兩支 API 邏輯未受影響
- 消費品項與分類仍維持正交維度設計(見 `feature-tags.md`),本次修正**不涉及**用消費品項金額去湊分類缺口的做法

## 四、執行紀錄

| 腳本 | 內容 | 結果 |
|---|---|---|
| `update46.sh` | 完整覆寫 `stats.py`/`schemas_ledger.py`/`CategoryBreakdownChart.vue` | commit 成功;`deploy.sh` 卡在 `vue-tsc -b` 型別檢查,因 `ledger.ts` 漏改 |
| `update47.sh` | 精確字串比對補上 `ledger.ts` 的 `is_self: boolean` 欄位 | commit 成功,`deploy.sh` 完整跑完 |

`update46.sh` 部署中斷期間,`ledger-api` 服務仍為 `active`,未實際中斷服務。

## 五、目前狀態

- ✅ 下鑽任一有「子分類 + 直接掛帳交易」的分類,會多出灰色「XX(直接歸類,未再細分)」項目
- ✅ 下鑽畫面加總(子分類 + 本節點直接交易)= 頂層總額,不再有數字對不起來的問題
- ✅ 使用者實際測試 Dean 案例,結果正確
- ✅ 若下鑽分類沒有任何直接掛帳交易,灰色項目不出現(預期行為,非漏項)

## 六、後續可考慮事項

1. 若未來想進一步分析「Dean 這個分類到底花在哪些店家」,可考慮補一支「分類 × 消費品項」交叉統計 API(見 `feature-tags.md`/`feature-stats.md` 已知限制),但屬於較大工程,非本次範圍
2. 目前「直接歸類,未再細分」的命名是暫定文字,若使用者回饋看不懂,可再調整前端顯示文案(不需動後端邏輯)
