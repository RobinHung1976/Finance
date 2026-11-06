# 2026-11-06 分類/品項選取顯示一致化

## 現象

在新增交易對話框選分類時,同一個分類用不同方式選取,畫面不一致:

- 用搜尋選「早餐」:停在原層,「早餐」按鍵亮綠,很明顯
- 直接點「早餐」:畫面跳到一個空的層級(麵包屑「全部 › 早餐」,下方沒有任何按鍵),只剩麵包屑文字與小字「已選擇:早餐」,很不明顯

## 原因

`CategoryPicker.vue`(與 `CategoryFilterPicker.vue`)的 `selectCategory()` 不論該分類有沒有子分類,一律 `path.push()` 進入下一層;沒有子分類的分類進去後是空的層級。搜尋選取則是停在父層(`path = 祖先鏈去掉自己`),所以兩者顯示不同。

## 修正(`update63.sh`)

**分類(`CategoryPicker.vue`、`CategoryFilterPicker.vue`)**

```ts
// 有子分類才進入下一層;沒有子分類只選取、停在原層,選取狀態直接顯示在按鍵上
function selectCategory(category: CategoryOut) {
  emit('update:modelValue', category.id)
  if (hasChildren(category.id)) path.value.push(category)
}
```

- 麵包屑中被選取的層級(點有子分類的大類時)也以品牌綠標示(`.crumb.selected`)
- `CategoryPicker` 的「已選擇」改為綠色標籤並顯示完整路徑(如「餐飲 › 晚餐」)

**副作用處理:在沒有細項的大類底下新增第一個細項**

原本靠「點進空層級 → 新增分類」達成,改版後點大類不再進入。改為:在**最上層**選取尚無細項的大類時,「新增分類」旁顯示兩個選項「加在『最上層』」「加在『早餐』底下」;選後者新增後自動進入該大類並選取新細項。

只限最上層:分類樹維持兩層(大類 › 細項,見 `features/feature-categories.md`),第三層已改用消費品項。舊版可點進細項再新增第三層,此次一併擋下。重複名稱檢查改以「實際要加入的父層」判斷。

**品項(`TagPicker.vue`)**

品項本來就是點選後原地亮綠、不跳層,沒有不一致。補強:新增「已選擇」綠色標籤列(點一下取消),搜尋時已選品項被篩掉也看得到;消費品項管理頁(`TagList.vue`)以 `hideSelectedHint` 隱藏。

## 驗證

- Playwright + 假資料:點葉節點/有子分類的大類/細項、在大類底下新增第一個細項(POST `parent_id` 為該大類)、品項搜尋中選取與取消;交易/品項回歸測試正常
- 部署後 `ledger-api` active、`/` 與 `/health` 皆 200;使用者實測(2026-11-06)全部正常
