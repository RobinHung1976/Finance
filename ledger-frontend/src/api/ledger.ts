import { apiClient } from './client'
import type { AccountOut, AccountCreatePayload, CategoryOut, CategoryCreatePayload, TagOut, TagCreatePayload, TransactionOut, TransactionCreatePayload, TransactionFilters, MonthlyTrendOut, CategoryBreakdownOut, EntryType, TagBreakdownOut } from '@/types/ledger'
export function fetchAccounts() {
  return apiClient.get<AccountOut[]>('/accounts').then((r) => r.data)
}

export function createAccount(payload: AccountCreatePayload) {
  return apiClient.post<AccountOut>('/accounts', payload).then((r) => r.data)
}

export function updateAccount(id: string, payload: Partial<AccountCreatePayload>) {
  return apiClient.patch<AccountOut>(`/accounts/${id}`, payload).then((r) => r.data)
}

export function deleteAccount(id: string) {
  return apiClient.delete(`/accounts/${id}`)
}

export function fetchCategories() {
  return apiClient.get<CategoryOut[]>('/categories').then((r) => r.data)
}

export function createCategory(payload: CategoryCreatePayload) {
  return apiClient.post<CategoryOut>('/categories', payload).then((r) => r.data)
}

export function updateCategory(id: string, payload: Partial<CategoryCreatePayload>) {
  return apiClient.patch<CategoryOut>(`/categories/${id}`, payload).then((r) => r.data)
}
export function deleteCategory(id: string) {
  return apiClient.delete(`/categories/${id}`)
}
export function fetchTags() {
  return apiClient.get<TagOut[]>('/tags').then((r) => r.data)
}
export function createTag(payload: TagCreatePayload) {
  return apiClient.post<TagOut>('/tags', payload).then((r) => r.data)
}
export function updateTag(id: string, payload: TagCreatePayload) {
  return apiClient.patch<TagOut>(`/tags/${id}`, payload).then((r) => r.data)
}
export function deleteTag(id: string) {
  return apiClient.delete(`/tags/${id}`)
}

export function fetchTransactions(filters: TransactionFilters = {}) {
  return apiClient.get<TransactionOut[]>('/transactions', { params: filters }).then((r) => r.data)
}

export function createTransaction(payload: TransactionCreatePayload) {
  return apiClient.post<TransactionOut>('/transactions', payload).then((r) => r.data)
}

export function updateTransaction(id: string, payload: Partial<TransactionCreatePayload>) {
  return apiClient.patch<TransactionOut>(`/transactions/${id}`, payload).then((r) => r.data)
}

export function deleteTransaction(id: string) {
  return apiClient.delete(`/transactions/${id}`)
}

export function fetchMonthlyTrend(startDate?: string, endDate?: string) {
  return apiClient
    .get<MonthlyTrendOut>('/stats/monthly-trend', {
      params: { start_date: startDate, end_date: endDate },
    })
    .then((r) => r.data)
}

export function fetchCategoryBreakdown(
  type: EntryType = 'expense',
  startDate?: string,
  endDate?: string,
  parentId: string | null = null,
) {
  return apiClient
    .get<CategoryBreakdownOut>('/stats/category-breakdown', {
      params: { type, start_date: startDate, end_date: endDate, parent_id: parentId },
    })
    .then((r) => r.data)
}


export async function fetchTagBreakdown(
  startDate: string,
  endDate: string,
  type: 'income' | 'expense' = 'expense',
  limit = 15,
): Promise<TagBreakdownOut> {
  const { data } = await apiClient.get<TagBreakdownOut>('/stats/tag-breakdown', {
    params: { start_date: startDate, end_date: endDate, type, limit },
  })
  return data
}
