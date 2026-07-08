#!/usr/bin/env bash
set -euo pipefail

FRONTEND=ledger-frontend
[ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

python3 << 'PYEOF'
path = "ledger-frontend/src/api/importExport.ts"
with open(path) as f:
    content = f.read()

old = """export async function exportExcel(year: number): Promise<void> {
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
}"""

new = """export async function exportExcel(year: number): Promise<void> {
  const response = await apiClient.get('/transactions/export/excel', {
    params: { year },
    responseType: 'blob',
  })

  // 從後端 Content-Disposition 解析真實檔名(含帳本名稱),不再前端寫死
  const disposition = response.headers['content-disposition'] as string | undefined
  let filename = `${year}-記帳表.xlsx`
  if (disposition) {
    const utf8Match = disposition.match(/filename\\*=UTF-8''([^;]+)/)
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
}"""

if old not in content:
    raise SystemExit("❌ exportExcel 錨點不符,請人工檢查 importExport.ts 現況")
content = content.replace(old, new, 1)

with open(path, "w") as f:
    f.write(content)
print("✅ importExport.ts: exportExcel 改為讀取後端 Content-Disposition 檔名,不再前端寫死")
PYEOF

git add -A
git commit -m "fix: 前端下載檔名寫死為「記帳表」,忽略後端已正確回傳的帳本名稱,改為解析 Content-Disposition header"
echo "✅ 已 commit,請 push + deploy"