#!/usr/bin/env bash
set -euo pipefail

# ========================================
# update49.sh
# 修正:tag-breakdown 的 start_date/end_date 改為選填 + 預設今年區間,
#      與 monthly-trend / category-breakdown 兩支 API 行為一致
# 背景:目前必填,沒帶就 422,跟其他兩支「沒帶就用 _resolve_range() 預設今年」不一致。
#      現有前端 DashboardView.vue 一定會帶值,不受影響;純粹是 API 設計對齊。
# ========================================

# ---- 0. 自動歸檔(固定寫法,與功能改動分開 commit) ----
CURRENT=49
mkdir -p "update${CURRENT}"
for f in update*.sh; do
  [ "$f" = "update${CURRENT}.sh" ] && continue
  [ -f "$f" ] || continue
  git mv "$f" "update${CURRENT}/$f" 2>/dev/null || mv "$f" "update${CURRENT}/$f"
done
git add -A
if ! git diff --cached --quiet; then
  git commit -m "chore: 歸檔已執行的 updateN.sh 腳本"
fi

# ---- 1. 前置驗證:確認目前 stats.py 是 update47.sh 之後的版本(is_self 邏輯已存在) ----
if ! grep -q "is_self" ledger-backend/app/routers/stats.py; then
  echo "❌ ledger-backend/app/routers/stats.py 尚未包含 is_self 邏輯,請先確認 update46/47.sh 是否已套用" >&2
  exit 1
fi

# ---- 2. 精確字串比對修改 stats.py(改動範圍小,不用完整覆寫) ----
python3 << 'PYEOF'
import sys

path = "ledger-backend/app/routers/stats.py"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

old = '''def get_tag_breakdown(
    start_date: date,
    end_date: date,
    type: EntryType = EntryType.expense,
    limit: int = Query(15, ge=1, le=50),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if end_date < start_date:
        raise HTTPException(status_code=400, detail="end_date 不可早於 start_date")'''

new = '''def get_tag_breakdown(
    start_date: date | None = Query(default=None, description="預設今年 1/1"),
    end_date: date | None = Query(default=None, description="預設今天"),
    type: EntryType = EntryType.expense,
    limit: int = Query(15, ge=1, le=50),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    start_date, end_date = _resolve_range(start_date, end_date)'''

count = content.count(old)
if count != 1:
    print(f"❌ 比對字串出現 {count} 次(預期 1 次),中止,未寫入任何檔案", file=sys.stderr)
    sys.exit(1)

content = content.replace(old, new)
with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ stats.py 修改完成")
PYEOF

# ---- 3. commit(feat,與歸檔分開) ----
git add ledger-backend/app/routers/stats.py
git commit -m "feat: tag-breakdown start_date/end_date 改為選填+預設區間,與其他統計 API 一致"

# ---- 4. 確認 commit 真的產生(務必執行,不能只看終端機有無錯誤字樣) ----
echo "---- git log --oneline -1 ----"
git log --oneline -1
