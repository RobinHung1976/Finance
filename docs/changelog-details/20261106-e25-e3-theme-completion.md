# 2026-11-06 前端改版收尾:選擇器/統計元件/登入頁改用主題、圖表配色統一、移除相容層(E2.5 + E3)

## 背景

E2 五個功能頁完成後(`20261106-e2-pages-restyle.md`),仍有共用選擇器、兩個統計元件、登入類頁面在用舊樣式或 `style.css` 相容層;三張圖表各自寫死配色(趨勢圖 Finance 綠/紅、圓餅圖 Tailwind 靛藍色盤、長條圖 `#4a90d9` 藍),與主題不一致。

## 決策

| 項目 | 決定 | 理由 |
|---|---|---|
| 選擇器樣式 | 五個選擇器沿用原 class 名稱,樣式集中到 `theme.css` 的「選擇器」區段,刪除各自 scoped style | 五個元件結構幾乎相同,原本各寫一份 30~120 行 CSS;集中後只需維護一處 |
| 圖表配色 | 新增 `utils/chartTheme.ts`;收支色與 `theme.css` 的 `--c-income`/`--c-expense` 同值 | Chart.js 畫在 canvas 上讀不到 CSS 變數,需在 TS 端另存一份 |
| 分類色盤 | 10 色,色相分開、明度相近,刻意避開純紅/純綠 | 避免與收支色混淆;「本分類直接歸類」維持固定灰 `#9CA3AF` |
| 相容層 | 刪除 `src/style.css`;`.error-banner`、`.auth-*` 移入 `theme.css`;`.btn-primary` → `.btn.primary.block`、`.field` → `.form-field` | 程式碼已無任何地方使用舊 class 與舊變數 |

## 修改內容(`update60.sh`)

- `styles/theme.css`:新增選擇器共用樣式、`.error-banner`、登入卡片(`.auth-page`/`.auth-card`/`.auth-body`/`.stack-form`/`.btn.block`/`.auth-switch`)、`--c-income`/`--c-expense`
- 選擇器:`CategoryPicker`/`TagPicker`/`AccountFilterPicker`/`CategoryFilterPicker`/`TagFilterPicker.vue` 刪除 scoped style 與 inline style;選項為金屬鍵、選取為品牌綠
- 統計:
  - `MonthlyTrendChart.vue`:總收入/總支出/結餘改 `.stat` 卡片,折線用 `CHART_COLORS`
  - `CategoryBreakdownChart.vue`:層級導覽改 `.btn.sm`(目前層 `.on`)+ 提示「點圓餅區塊可查看子分類」,色盤改 `paletteColor()`
  - `TagBreakdownChart.vue`/`TopTransactionsList.vue`:支出/收入改 LED 小按鍵,長條依收支上色,名次改圓形徽章
- 新增 `utils/chartTheme.ts`:`CHART_COLORS`、`CATEGORY_PALETTE`、`paletteColor()`、`withAlpha()`,並設定 Chart.js 全域字型/文字色/格線色
- 登入/註冊/忘記密碼/重設密碼頁、`MembersView.vue`:改用上述 class
- `main.ts`:移除 `style.css` 載入;刪除 `src/style.css`

## 驗證

- Playwright + 假資料:登入/註冊/重設密碼頁、統計四分頁、交易對話框選擇器、進階篩選、成員新增截圖檢查;交易/帳戶/分類/品項/匯入匯出操作回歸測試,API payload 與改版前一致
- 部署後 `ledger-api` active、`/` 與 `/health` 皆 200;使用者實測(2026-11-06)全部正常
