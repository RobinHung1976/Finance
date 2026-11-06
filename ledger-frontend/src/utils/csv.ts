// CSV 匯出(前端產生):UTF-8 BOM 讓 Excel 正確辨識中文;每格以雙引號包住並跳脫內含雙引號。
// 文字格開頭若為 = + - @ Tab CR,前面補單引號,避免在 Excel 開啟時被當成公式執行(CSV injection)。

export type CsvCell = string | number

const FORMULA_PREFIX = /^[=+\-@\t\r]/

function escapeCell(value: CsvCell): string {
  let text = typeof value === 'number' ? String(value) : value
  if (typeof value === 'string' && FORMULA_PREFIX.test(text)) text = `'${text}`
  return `"${text.replace(/"/g, '""')}"`
}

export function toCsv(header: string[], rows: CsvCell[][]): string {
  return [header, ...rows].map((row) => row.map(escapeCell).join(',')).join('\r\n')
}

export function downloadCsv(filename: string, csv: string): void {
  const blob = new Blob(['﻿', csv], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  a.remove()
  // 延後釋放,避免部分瀏覽器在下載開始前就失效
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}
