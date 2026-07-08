#!/usr/bin/env bash
set -euo pipefail
FRONTEND=ledger-frontend
[ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

python3 << 'PYEOF'
path = "ledger-frontend/src/api/importExport.ts"
with open(path) as f:
    content = f.read()

old = """export function previewImport(file: File, accountId: string) {
  const form = new FormData()
  form.append('file', file)
  form.append('account_id', accountId)
  // 不手動設定 Content-Type,交給 axios 自動帶正確 boundary
  return apiClient
    .post<ImportPreviewResponse>('/transactions/import/preview', form)
    .then((r) => r.data)
}

export function commitImport(file: File, accountId: string, forceRows: string[] = []) {
  const form = new FormData()
  form.append('file', file)
  form.append('account_id', accountId)
  form.append('force_rows', forceRows.join(','))
  return apiClient
    .post<ImportCommitResponse>('/transactions/import/commit', form)
    .then((r) => r.data)
}"""

new = """export function previewImport(file: File, accountId: string) {
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
}"""

if old not in content:
    raise SystemExit("❌ 內容不符,請人工檢查 importExport.ts 現況")
content = content.replace(old, new)
with open(path, "w") as f:
    f.write(content)
print("✅ importExport.ts 已修正(清除全域 Content-Type,避免 FormData boundary 遺失)")
PYEOF

git add -A
git commit -m "fix: apiClient 全域 Content-Type: application/json 蓋掉 FormData boundary,匯入預覽/送出改為顯式清除該 header"
echo "✅ 已 commit,請 push + deploy"