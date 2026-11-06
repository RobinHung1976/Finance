// 日期工具：一律以瀏覽器本地時區組字串。
// 不可用 toISOString()（UTC），否則台北時間 00:00–07:59 會得到前一天。

function pad(n: number): string {
  return String(n).padStart(2, '0')
}

export function toLocalISODate(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

export function todayLocal(): string {
  return toLocalISODate(new Date())
}

export interface DateRange {
  start: string
  end: string
}

export type RangePreset = 'thisMonth' | 'lastMonth' | 'last3Months' | 'thisYear'

export function presetRange(preset: RangePreset, now: Date = new Date()): DateRange {
  const y = now.getFullYear()
  const m = now.getMonth()
  switch (preset) {
    case 'thisMonth':
      return { start: toLocalISODate(new Date(y, m, 1)), end: toLocalISODate(now) }
    case 'lastMonth':
      // new Date(y, m, 0) = 上個月最後一天（跨年由 Date 自動進位）
      return { start: toLocalISODate(new Date(y, m - 1, 1)), end: toLocalISODate(new Date(y, m, 0)) }
    case 'last3Months':
      // 含本月在內的三個月份：前兩個月 1 號 ~ 今天
      return { start: toLocalISODate(new Date(y, m - 2, 1)), end: toLocalISODate(now) }
    case 'thisYear':
      return { start: `${y}-01-01`, end: toLocalISODate(now) }
  }
}
