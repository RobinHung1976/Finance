export type AccountType = 'cash' | 'credit_card' | 'bank'
export type EntryType = 'income' | 'expense'

export interface AccountOut {
  id: string
  name: string
  type: AccountType
  balance: number
  is_default_expense: boolean
}

export interface CategoryOut {
  id: string
  name: string
  parent_id: string | null
  type: EntryType
}

export interface TagOut {
  id: string
  name: string
}
export interface TagCreatePayload {
  name: string
}
export interface TransactionOut {
  id: string
  account_id: string
  category_id: string
  amount: number
  type: EntryType
  date: string
  note: string | null
  user_id: string | null
  tags: TagOut[]
}

export interface AccountCreatePayload {
  name: string
  type: AccountType
  balance: number
  is_default_expense: boolean
}

export interface CategoryCreatePayload {
  name: string
  parent_id: string | null
  type: EntryType
}

export interface TransactionCreatePayload {
  account_id: string
  category_id: string
  amount: number
  type: EntryType
  date: string
  note: string | null
  tag_ids?: string[]
}

export interface TransactionFilters {
  start_date?: string
  end_date?: string
  account_id?: string
  category_id?: string
  min_amount?: number
  max_amount?: number
}

export interface MonthlySummary {
  month: string
  income: number
  expense: number
  balance: number
}

export interface MonthlyTrendOut {
  months: MonthlySummary[]
  total_income: number
  total_expense: number
  total_balance: number
}

export interface CategoryBreakdownItem {
  category_id: string
  category_name: string
  amount: number
  percentage: number
  has_children: boolean
}

export interface CategoryBreakdownOut {
  type: EntryType
  total: number
  items: CategoryBreakdownItem[]
}
