# Alembic Migration 產生 SOP

建立日期:2026-07-07

## 一、背景

`models.py` 新增/修改 ORM model 後(如本次新增 `AuditLog`),需產生對應 migration 檔案才能同步到 DB schema。依 `github-feature-20260707.md` 教訓,migration 檔案遺失或未進版控會導致部署失敗或 schema 不同步,故訂定固定流程。

## 二、執行步驟

```bash
# 1. 進入 backend 目錄,啟動 venv
cd ledger-backend
source venv/bin/activate

# 2. 產生 migration(自動比對 models.py 與目前 DB schema 差異)
alembic revision --autogenerate -m "add audit_logs table"

# 3. 找出剛產生的檔案
ls -t alembic/versions/*.py | head -1

# 4. 人工檢查內容
cat $(ls -t alembic/versions/*.py | head -1)
```

**第 4 步檢查重點**:
- 檔案內容應只包含本次異動相關的 `op.create_table` / `op.add_column` 等,以本次為例應只有 `audit_logs` 資料表建立與對應 index/FK
- 若出現非預期的 `op.drop_column`、`op.alter_column`,代表目前 DB 實際 schema 與 `models.py` 已不同步(過去可能手動改過 DB,或漏跑某次 migration),**須先排查根本原因,不可直接 commit**,否則會把非預期的 DB 異動一併套用到正式環境

```bash
# 5. 確認無誤後才進版控
git add alembic/versions/*.py
git commit -m "chore: add audit_logs migration"

# 6. deactivate + push
deactivate
git push origin main
```

## 三、環境要求

- `alembic revision --autogenerate` 需要能連上實際 DB(讀取 `.env` 的 `DATABASE_URL`)進行 schema 比對
- **若本機沒有 DB 連線**,必須在 **server** 上執行整個流程(步驟 1–6),執行完成後**立刻 commit + push**,避免落入「server 端手動改動未進版控,被下次 `deploy.sh` 的 `git reset --hard` 蓋掉」的既有教訓(見 `bug-fix-20260707.md`)

## 四、常見錯誤與排查

| 現象 | 原因 | 對策 |
|---|---|---|
| autogenerate 產生大量非預期 `op.alter_column`/`op.drop_column` | DB 實際 schema 與 `models.py` 不同步 | 停止,人工比對差異來源,確認是否有過去未進版控的手動 DB 異動 |
| `alembic revision --autogenerate` 報連線錯誤 | 本機無法連上 DB,或 `.env` 的 `DATABASE_URL` 未設定/不正確 | 改在 server 上執行,或確認 `.env` 內容 |
| migration 檔案產生後忘記 commit | 依賴記憶,未確實執行步驟 5 | 每次執行完步驟 4 檢查無誤後,固定接續步驟 5–6,不可跳過 |

## 五、SOP 總結

1. 修改 `models.py` 後,一律先產生 migration 再部署,不可依賴 `alembic upgrade head` 自動補足缺失的 revision
2. autogenerate 產出的檔案**必須人工檢查**,確認只含預期異動
3. migration 檔案與程式碼異動一律同一次 commit 或緊接 commit,不可分開延遲進版控
4. 無 DB 連線環境下,一律在 server 上執行完整流程並立即 commit + push,不留未進版控的異動
