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
  return apiClient
    .post<ImportPreviewResponse>('/transactions/import/preview', form, {
      headers: { 'Content-Type': 'multipart/form-data' },
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
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    .then((r) => r.data)
}"""

new = """export function previewImport(file: File, accountId: string) {
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

if old not in content:
    raise SystemExit("❌ 內容不符,請人工檢查 importExport.ts 現況")
content = content.replace(old, new)

with open(path, "w") as f:
    f.write(content)
print("✅ importExport.ts 已修正(移除手動 Content-Type header)")
PYEOF

git add -A
git commit -m "fix: 移除 multipart 手動 Content-Type header,修正 boundary 遺失導致匯入預覽失敗"
echo "✅ 已 commit,請執行 'git push origin main',再到 server 跑 ./deploy.sh"