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
  const response = await apiClient.get('/transactions/export/excel', {
    params: { year },
    responseType: 'blob',
  })

  // 從後端 Content-Disposition 解析真實檔名(含帳本名稱),不再前端寫死
  const disposition = response.headers['content-disposition'] as string | undefined
  let filename = `${year}-記帳表.xlsx`
  if (disposition) {
    const utf8Match = disposition.match(/filename\*=UTF-8''([^;]+)/)
    if (utf8Match) {
      filename = decodeURIComponent(utf8Match[1])
    } else {
      const asciiMatch = disposition.match(/filename="?([^";]+)"?/)
      if (asciiMatch) filename = asciiMatch[1]
    }
  }

  const url = URL.createObjectURL(new Blob([response.data]))
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}
