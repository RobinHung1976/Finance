import { Chart } from 'chart.js'

// 圖表配色:與 styles/theme.css 的 --c-income / --c-expense 同值(Chart.js 畫在 canvas 上,讀不到 CSS 變數)
export const CHART_COLORS = {
  income: '#1f8a4c',
  expense: '#b8391a',
  /** 「本分類直接交易(未再細分)」等中性項目 */
  neutral: '#9CA3AF',
  text: '#30363e',
  grid: 'rgba(30, 35, 45, 0.10)',
} as const

// 分類色盤:10 色,彼此色相分開、明度相近,在金屬灰底上皆可辨識;避開純紅綠以免與收支色混淆
export const CATEGORY_PALETTE = [
  '#2f7d68', '#3b6ea8', '#c8892e', '#8a5ab0', '#c0504d',
  '#4a9bb5', '#6f8f2e', '#b5657e', '#5c6f86', '#a0703c',
] as const

export function paletteColor(index: number): string {
  return CATEGORY_PALETTE[index % CATEGORY_PALETTE.length]
}

/** '#rrggbb' + 透明度(0~1)→ rgba() */
export function withAlpha(hex: string, alpha: number): string {
  const n = Number.parseInt(hex.slice(1), 16)
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${alpha})`
}

// 全域預設:字型、文字色、格線色(模組載入時套用一次)
Chart.defaults.font.family = '"Segoe UI", "Noto Sans TC", "Microsoft JhengHei", "PingFang TC", system-ui, sans-serif'
Chart.defaults.color = CHART_COLORS.text
Chart.defaults.borderColor = CHART_COLORS.grid
