import { apiClient } from './client'
import type { ImportPreviewResponse, ImportCommitResponse } from '@/types/importExport'

export function previewImport(file: File, accountId: string) {
  const form = new FormData()
  form.append('file', file)
  form.append('account_id', accountId)
  // apiClient 有全域固定 Content-Type: application/json,需顯式清除該欄位
  // 才能讓 axios 依 FormData 型別自動產生含 boundary 的 multipart header
  return apiClient
    .post<ImportPreviewResponse>('/transactions/import/preview', form, {
      headers: { 'Content-Type': undefined },
    })
    .then((r) => r.data)
}

export function commitImport(file: File, accountId: string, forceRows: string[] = []) {
  const form = new FormData()
  form.append('file', file)
  form.append('account_id', accountId)
  form.append('force_rows', forceRows.join(','))
  return apiClient
    .post<ImportCommitResponse>('/transactions/import/commit', form, {
      headers: { 'Content-Type': undefined },
    })
    .then((r) => r.data)
}

export async function exportExcel(year: number): Promise<void> {
  const { data } = await apiClient.get('/transactions/export/excel', {
    params: { year },
    responseType: 'blob',
  })
  const url = URL.createObjectURL(new Blob([data]))
  const a = document.createElement('a')
  a.href = url
  a.download = `${year}-記帳表.xlsx`
  a.click()
  URL.revokeObjectURL(url)
}
