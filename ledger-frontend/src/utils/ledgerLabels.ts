import type { AccountType, EntryType } from '@/types/ledger'

export const ACCOUNT_TYPE_LABEL: Record<AccountType, string> = {
  cash: '現金',
  credit_card: '信用卡',
  bank: '銀行',
}

export const ENTRY_TYPE_LABEL: Record<EntryType, string> = {
  income: '收入',
  expense: '支出',
}

export function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('zh-TW', { style: 'currency', currency: 'TWD', maximumFractionDigits: 0 }).format(
    amount
  )
}
