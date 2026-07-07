#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
FRONTEND=ledger-frontend
[ -d "$BACKEND" ] && [ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

# ---------- config.py:延長 token 效期 ----------
python3 << 'PYEOF'
path = "ledger-backend/app/config.py"
with open(path) as f:
    content = f.read()
old = "    access_token_expire_minutes: int = 1440"
new = "    access_token_expire_minutes: int = 43200  # 30 天"
if old not in content:
    raise SystemExit("❌ config.py 不符")
content = content.replace(old, new)
with open(path, "w") as f:
    f.write(content)
print("✅ config.py 已修正")
PYEOF

# ---------- models.py:新增 AuditLog ----------
python3 << 'PYEOF'
path = "ledger-backend/app/models.py"
with open(path) as f:
    content = f.read()
old = '''class PasswordResetToken(Base):'''
new = '''class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    household_id: Mapped[str] = mapped_column(ForeignKey("households.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    action: Mapped[str] = mapped_column(String(20), nullable=False)
    resource_type: Mapped[str] = mapped_column(String(30), nullable=False)
    resource_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    detail: Mapped[str | None] = mapped_column(String(500), nullable=True)
    actor_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)


class PasswordResetToken(Base):'''
if old not in content:
    raise SystemExit("❌ models.py 不符")
content = content.replace(old, new)
with open(path, "w") as f:
    f.write(content)
print("✅ models.py 已修正")
PYEOF

# ---------- audit.py:新檔 ----------
cat > "$BACKEND/app/audit.py" << 'EOF'
from sqlalchemy.orm import Session
from app.models import AuditLog, User


def log_action(
    db: Session,
    *,
    user: User,
    action: str,
    resource_type: str,
    resource_id: str | None = None,
    detail: str | None = None,
) -> None:
    """僅 db.add,不 commit — 與呼叫端業務操作同一交易,失敗一併 rollback。"""
    db.add(
        AuditLog(
            household_id=user.household_id,
            user_id=user.id,
            actor_name=user.name,
            action=action,
            resource_type=resource_type,
            resource_id=resource_id,
            detail=detail,
        )
    )
EOF
echo "✅ audit.py 已建立"

# ---------- schemas.py:新增 AuditLogOut / AuditLogPage ----------
python3 << 'PYEOF'
path = "ledger-backend/app/schemas.py"
with open(path) as f:
    content = f.read()
old = "class TokenResponse(BaseModel):"
new = '''class AuditLogOut(BaseModel):
    id: str
    actor_name: str | None
    action: str
    resource_type: str
    resource_id: str | None
    detail: str | None
    created_at: datetime

    class Config:
        from_attributes = True


class AuditLogPage(BaseModel):
    items: list[AuditLogOut]
    total: int
    limit: int
    offset: int


class TokenResponse(BaseModel):'''
if old not in content:
    raise SystemExit("❌ schemas.py 不符")
content = content.replace(old, new)
with open(path, "w") as f:
    f.write(content)
print("✅ schemas.py 已修正")
PYEOF

# ---------- auth.py:login 補寫 audit log ----------
python3 << 'PYEOF'
path = "ledger-backend/app/routers/auth.py"
with open(path) as f:
    content = f.read()

old_import = "from app.email import send_email"
new_import = "from app.audit import log_action\nfrom app.email import send_email"
if old_import not in content:
    raise SystemExit("❌ auth.py import 不符")
content = content.replace(old_import, new_import)

old = '''    token = create_access_token(
        {"sub": user.id, "household_id": user.household_id, "role": user.role.value}
    )
    return TokenResponse(access_token=token)


RESET_TOKEN_TTL_MINUTES = 30'''
new = '''    log_action(db, user=user, action="login", resource_type="user", resource_id=user.id)
    db.commit()
    token = create_access_token(
        {"sub": user.id, "household_id": user.household_id, "role": user.role.value}
    )
    return TokenResponse(access_token=token)


RESET_TOKEN_TTL_MINUTES = 30'''
if old not in content:
    raise SystemExit("❌ auth.py login 區塊不符")
content = content.replace(old, new)

with open(path, "w") as f:
    f.write(content)
print("✅ auth.py 已修正")
PYEOF

# ---------- households.py:完整覆寫(刪除成員 + audit + 分頁查詢) ----------
cat > "$BACKEND/app/routers/households.py" << 'EOF'
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.audit import log_action
from app.database import get_db
from app.deps import get_current_user, require_admin
from app.models import AuditLog, User, UserRole
from app.schemas import AuditLogPage, HouseholdOut, UserCreate, UserOut
from app.security import hash_password

router = APIRouter(prefix="/households", tags=["households"])


@router.get("/me", response_model=HouseholdOut)
def get_my_household(current_user: User = Depends(get_current_user)):
    return current_user.household


@router.get("/me/members", response_model=list[UserOut])
def list_members(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(User).filter(User.household_id == current_user.household_id).all()


@router.post("/me/members", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def add_member(
    payload: UserCreate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    new_user = User(
        household_id=current_user.household_id,
        name=payload.name,
        username=payload.username,
        email=payload.email.lower(),
        password_hash=hash_password(payload.password),
        role=payload.role,
    )
    db.add(new_user)
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="帳號已被使用")

    log_action(db, user=current_user, action="create", resource_type="member",
               resource_id=new_user.id, detail=f"新增成員：{new_user.name}（{new_user.role.value}）")
    db.commit()
    db.refresh(new_user)
    return new_user


@router.delete("/me/members/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_member(
    user_id: str,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    if user_id == current_user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="不可刪除自己的帳號")

    member = db.get(User, user_id)
    if member is None or member.household_id != current_user.household_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="成員不存在")

    if member.role == UserRole.admin:
        other_admin = (
            db.query(User)
            .filter(User.household_id == current_user.household_id, User.role == UserRole.admin, User.id != user_id)
            .first()
        )
        if other_admin is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="家庭至少需保留一位管理者")

    log_action(db, user=current_user, action="delete", resource_type="member",
               resource_id=member.id, detail=f"刪除成員：{member.name}")
    db.delete(member)
    db.commit()


@router.get("/me/audit-logs", response_model=AuditLogPage)
def list_audit_logs(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    action: str | None = Query(default=None),
    resource_type: str | None = Query(default=None),
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    query = db.query(AuditLog).filter(AuditLog.household_id == current_user.household_id)

    if action is not None:
        query = query.filter(AuditLog.action == action)
    if resource_type is not None:
        query = query.filter(AuditLog.resource_type == resource_type)
    if start_date is not None:
        query = query.filter(AuditLog.created_at >= start_date)
    if end_date is not None:
        query = query.filter(AuditLog.created_at < (end_date + timedelta(days=1)))

    total = query.count()
    items = query.order_by(AuditLog.created_at.desc()).offset(offset).limit(limit).all()
    return AuditLogPage(items=items, total=total, limit=limit, offset=offset)
EOF
echo "✅ households.py 已覆寫"

# ---------- accounts.py:admin-only 餘額/刪除 + audit log ----------
python3 << 'PYEOF'
path = "ledger-backend/app/routers/accounts.py"
with open(path) as f:
    content = f.read()

old_import = '''from app.deps import get_current_user
from app.models import Account, Category, EntryType, Transaction, User'''
new_import = '''from app.audit import log_action
from app.deps import get_current_user, require_admin
from app.models import Account, Category, EntryType, Transaction, User, UserRole'''
if old_import not in content:
    raise SystemExit("❌ accounts.py import 不符")
content = content.replace(old_import, new_import)

old_create = '''    account = Account(household_id=current_user.household_id, **payload.model_dump())
    db.add(account)
    db.commit()
    db.refresh(account)
    return account


def _clear_other_default_expense'''
new_create = '''    account = Account(household_id=current_user.household_id, **payload.model_dump())
    db.add(account)
    db.flush()
    log_action(db, user=current_user, action="create", resource_type="account",
               resource_id=account.id, detail=f"新增帳戶：{account.name}")
    db.commit()
    db.refresh(account)
    return account


def _clear_other_default_expense'''
if old_create not in content:
    raise SystemExit("❌ accounts.py create_account 不符")
content = content.replace(old_create, new_create)

old_update = '''    account = _get_owned_account(account_id, current_user, db)
    update_data = payload.model_dump(exclude_unset=True)

    if update_data.get("is_default_expense") is True:
        _clear_other_default_expense(current_user.household_id, db, exclude_id=account.id)

    if "balance" in update_data:
        delta = update_data["balance"] - float(account.balance)
        if delta != 0:
            entry_type = EntryType.income if delta > 0 else EntryType.expense
            category = _get_or_create_adjustment_category(current_user.household_id, entry_type, db)
            db.add(
                Transaction(
                    household_id=current_user.household_id,
                    user_id=current_user.id,
                    account_id=account.id,
                    category_id=category.id,
                    amount=abs(delta),
                    type=entry_type,
                    date=date.today(),
                    note="帳戶餘額手動調整",
                )
            )

    for field, value in update_data.items():'''
new_update = '''    account = _get_owned_account(account_id, current_user, db)
    update_data = payload.model_dump(exclude_unset=True)

    if "balance" in update_data and current_user.role != UserRole.admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="僅管理者可調整帳戶餘額")

    if update_data.get("is_default_expense") is True:
        _clear_other_default_expense(current_user.household_id, db, exclude_id=account.id)

    if "balance" in update_data:
        delta = update_data["balance"] - float(account.balance)
        if delta != 0:
            entry_type = EntryType.income if delta > 0 else EntryType.expense
            category = _get_or_create_adjustment_category(current_user.household_id, entry_type, db)
            db.add(
                Transaction(
                    household_id=current_user.household_id,
                    user_id=current_user.id,
                    account_id=account.id,
                    category_id=category.id,
                    amount=abs(delta),
                    type=entry_type,
                    date=date.today(),
                    note="帳戶餘額手動調整",
                )
            )
            log_action(db, user=current_user, action="update", resource_type="account",
                       resource_id=account.id,
                       detail=f"調整帳戶餘額：{account.name}（{'+' if delta > 0 else ''}{delta}）")

    for field, value in update_data.items():'''
if old_update not in content:
    raise SystemExit("❌ accounts.py update_account 不符")
content = content.replace(old_update, new_update)

old_delete = '''@router.delete("/{account_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_account(
    account_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    account = _get_owned_account(account_id, current_user, db)
    db.delete(account)
    db.commit()'''
new_delete = '''@router.delete("/{account_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_account(
    account_id: str,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    account = _get_owned_account(account_id, current_user, db)
    log_action(db, user=current_user, action="delete", resource_type="account",
               resource_id=account.id, detail=f"刪除帳戶：{account.name}")
    db.delete(account)
    db.commit()'''
if old_delete not in content:
    raise SystemExit("❌ accounts.py delete_account 不符")
content = content.replace(old_delete, new_delete)

with open(path, "w") as f:
    f.write(content)
print("✅ accounts.py 已修正")
PYEOF

# ---------- categories.py:audit log ----------
python3 << 'PYEOF'
path = "ledger-backend/app/routers/categories.py"
with open(path) as f:
    content = f.read()

old_import = '''from app.deps import get_current_user
from app.models import Category, Transaction, User'''
new_import = '''from app.audit import log_action
from app.deps import get_current_user
from app.models import Category, Transaction, User'''
if old_import not in content:
    raise SystemExit("❌ categories.py import 不符")
content = content.replace(old_import, new_import)

old_create = '''    category = Category(household_id=current_user.household_id, **payload.model_dump())
    db.add(category)
    db.commit()
    db.refresh(category)
    return category'''
new_create = '''    category = Category(household_id=current_user.household_id, **payload.model_dump())
    db.add(category)
    db.flush()
    log_action(db, user=current_user, action="create", resource_type="category",
               resource_id=category.id, detail=f"新增分類：{category.name}")
    db.commit()
    db.refresh(category)
    return category'''
if old_create not in content:
    raise SystemExit("❌ categories.py create_category 不符")
content = content.replace(old_create, new_create)

old_update = '''    for field, value in update_data.items():
        setattr(category, field, value)
    db.commit()
    db.refresh(category)
    return category'''
new_update = '''    for field, value in update_data.items():
        setattr(category, field, value)
    log_action(db, user=current_user, action="update", resource_type="category",
               resource_id=category.id, detail=f"修改分類：{category.name}")
    db.commit()
    db.refresh(category)
    return category'''
if old_update not in content:
    raise SystemExit("❌ categories.py update_category 不符")
content = content.replace(old_update, new_update)

old_delete = '''    db.delete(category)
    db.commit()'''
new_delete = '''    log_action(db, user=current_user, action="delete", resource_type="category",
               resource_id=category.id, detail=f"刪除分類：{category.name}")
    db.delete(category)
    db.commit()'''
if old_delete not in content:
    raise SystemExit("❌ categories.py delete_category 不符")
content = content.replace(old_delete, new_delete)

with open(path, "w") as f:
    f.write(content)
print("✅ categories.py 已修正")
PYEOF

# ---------- transactions.py:audit log ----------
python3 << 'PYEOF'
path = "ledger-backend/app/routers/transactions.py"
with open(path) as f:
    content = f.read()

old_import = '''from app.deps import get_current_user
from app.models import Account, Category, Transaction, User'''
new_import = '''from app.audit import log_action
from app.deps import get_current_user
from app.models import Account, Category, Transaction, User'''
if old_import not in content:
    raise SystemExit("❌ transactions.py import 不符")
content = content.replace(old_import, new_import)

old_create = '''    db.commit()
    db.refresh(tx)
    return tx


@router.patch("/{transaction_id}", response_model=TransactionOut)'''
new_create = '''    log_action(db, user=current_user, action="create", resource_type="transaction",
               resource_id=tx.id, detail=f"新增交易：{tx.amount}")
    db.commit()
    db.refresh(tx)
    return tx


@router.patch("/{transaction_id}", response_model=TransactionOut)'''
if old_create not in content:
    raise SystemExit("❌ transactions.py create_transaction 不符")
content = content.replace(old_create, new_create)

old_update = '''    db.commit()
    db.refresh(tx)
    return tx


@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)'''
new_update = '''    log_action(db, user=current_user, action="update", resource_type="transaction",
               resource_id=tx.id, detail=f"修改交易：{transaction_id}")
    db.commit()
    db.refresh(tx)
    return tx


@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)'''
if old_update not in content:
    raise SystemExit("❌ transactions.py update_transaction 不符")
content = content.replace(old_update, new_update)

old_delete = '''    db.delete(tx)
    db.commit()'''
new_delete = '''    log_action(db, user=current_user, action="delete", resource_type="transaction",
               resource_id=tx.id, detail=f"刪除交易：{tx.amount}")
    db.delete(tx)
    db.commit()'''
if old_delete not in content:
    raise SystemExit("❌ transactions.py delete_transaction 不符")
content = content.replace(old_delete, new_delete)

with open(path, "w") as f:
    f.write(content)
print("✅ transactions.py 已修正")
PYEOF

# ---------- 前端 router/index.ts ----------
python3 << 'PYEOF'
path = "ledger-frontend/src/router/index.ts"
with open(path) as f:
    content = f.read()

old = '''    {
      path: '/members',
      name: 'members',
      component: () => import('@/views/MembersView.vue'),
    },
  ],
})'''
new = '''    {
      path: '/members',
      name: 'members',
      component: () => import('@/views/MembersView.vue'),
    },
    {
      path: '/audit-logs',
      name: 'audit-logs',
      component: () => import('@/views/AuditLogView.vue'),
      meta: { requiresAdmin: true },
    },
  ],
})'''
if old not in content:
    raise SystemExit("❌ router/index.ts routes 不符")
content = content.replace(old, new)

old_guard = '''  if (to.meta.public && auth.isAuthenticated()) {
    return { name: 'dashboard' }
  }
  return true
})'''
new_guard = '''  if (to.meta.public && auth.isAuthenticated()) {
    return { name: 'dashboard' }
  }
  if (to.meta.requiresAdmin && auth.role !== 'admin') {
    return { name: 'dashboard' }
  }
  return true
})'''
if old_guard not in content:
    raise SystemExit("❌ router/index.ts guard 不符")
content = content.replace(old_guard, new_guard)

with open(path, "w") as f:
    f.write(content)
print("✅ router/index.ts 已修正")
PYEOF

# ---------- 前端 api/auth.ts ----------
python3 << 'PYEOF'
path = "ledger-frontend/src/api/auth.ts"
with open(path) as f:
    content = f.read()

old_import = "import type { TokenResponse, HouseholdOut, UserOut, UserRole } from '@/types/api'"
new_import = "import type { TokenResponse, HouseholdOut, UserOut, UserRole, AuditLogPage, AuditLogFilters } from '@/types/api'"
if old_import not in content:
    raise SystemExit("❌ auth.ts import 不符")
content = content.replace(old_import, new_import)

old_tail = '''export function forgotPassword(email: string) {'''
new_tail = '''export function deleteMember(userId: string) {
  return apiClient.delete(`/households/me/members/${userId}`)
}

export function fetchAuditLogs(limit: number, offset: number, filters: AuditLogFilters = {}) {
  return apiClient
    .get<AuditLogPage>('/households/me/audit-logs', { params: { limit, offset, ...filters } })
    .then((r) => r.data)
}

export function forgotPassword(email: string) {'''
if old_tail not in content:
    raise SystemExit("❌ auth.ts 尾端不符")
content = content.replace(old_tail, new_tail)

with open(path, "w") as f:
    f.write(content)
print("✅ auth.ts 已修正")
PYEOF

# ---------- 前端 types/api.ts:附加新型別(append,不需比對舊內容) ----------
cat >> "$FRONTEND/src/types/api.ts" << 'EOF'

export interface AuditLogOut {
  id: string
  actor_name: string | null
  action: 'login' | 'create' | 'update' | 'delete'
  resource_type: string
  resource_id: string | null
  detail: string | null
  created_at: string
}

export interface AuditLogPage {
  items: AuditLogOut[]
  total: number
  limit: number
  offset: number
}

export interface AuditLogFilters {
  action?: string
  resource_type?: string
  start_date?: string
  end_date?: string
}
EOF
echo "✅ types/api.ts 已附加"

# ---------- AuditLogView.vue:新檔 ----------
cat > "$FRONTEND/src/views/AuditLogView.vue" << 'EOF'
<script setup lang="ts">
import { onMounted, ref, computed, watch } from 'vue'
import { fetchAuditLogs } from '@/api/auth'
import type { AuditLogOut } from '@/types/api'

const logs = ref<AuditLogOut[]>([])
const total = ref(0)
const limit = 20
const offset = ref(0)
const isLoading = ref(true)
const loadError = ref('')

const filterAction = ref('')
const filterResourceType = ref('')
const filterStartDate = ref('')
const filterEndDate = ref('')

const actionOptions = [
  { value: '', label: '全部動作' },
  { value: 'login', label: '登入' },
  { value: 'create', label: '新增' },
  { value: 'update', label: '修改' },
  { value: 'delete', label: '刪除' },
]
const resourceOptions = [
  { value: '', label: '全部對象' },
  { value: 'account', label: '帳戶' },
  { value: 'category', label: '分類' },
  { value: 'transaction', label: '交易' },
  { value: 'member', label: '成員' },
  { value: 'user', label: '使用者' },
]
const actionLabel: Record<string, string> = { login: '登入', create: '新增', update: '修改', delete: '刪除' }
const resourceLabel: Record<string, string> = {
  account: '帳戶', category: '分類', transaction: '交易', member: '成員', user: '使用者',
}

const currentPage = computed(() => Math.floor(offset.value / limit) + 1)
const totalPages = computed(() => Math.max(1, Math.ceil(total.value / limit)))

function formatTime(iso: string) {
  return new Date(iso).toLocaleString('zh-TW', { hour12: false })
}

async function loadLogs() {
  isLoading.value = true
  try {
    const page = await fetchAuditLogs(limit, offset.value, {
      action: filterAction.value || undefined,
      resource_type: filterResourceType.value || undefined,
      start_date: filterStartDate.value || undefined,
      end_date: filterEndDate.value || undefined,
    })
    logs.value = page.items
    total.value = page.total
  } catch {
    loadError.value = '載入操作紀錄失敗'
  } finally {
    isLoading.value = false
  }
}

function goToPage(page: number) {
  if (page < 1 || page > totalPages.value) return
  offset.value = (page - 1) * limit
  loadLogs()
}

watch([filterAction, filterResourceType, filterStartDate, filterEndDate], () => {
  offset.value = 0
  loadLogs()
})

onMounted(loadLogs)
</script>

<template>
  <div style="max-width: 800px; margin: 0 auto; padding: 32px 24px">
    <header style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px">
      <h1 style="font-size: 20px; margin: 0">操作紀錄</h1>
      <router-link to="/" style="font-size: 13px; color: var(--color-primary); text-decoration: none">
        返回理財首頁
      </router-link>
    </header>

    <div style="display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 16px; font-size: 13px">
      <select v-model="filterAction" style="padding: 6px 8px">
        <option v-for="opt in actionOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
      </select>
      <select v-model="filterResourceType" style="padding: 6px 8px">
        <option v-for="opt in resourceOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
      </select>
      <input v-model="filterStartDate" type="date" style="padding: 6px 8px" />
      <span style="align-self: center">～</span>
      <input v-model="filterEndDate" type="date" style="padding: 6px 8px" />
    </div>

    <div v-if="loadError" class="error-banner">{{ loadError }}</div>

    <table v-if="!isLoading && logs.length" style="width: 100%; border-collapse: collapse; font-size: 13px">
      <thead>
        <tr style="text-align: left; color: #6b7a74; border-bottom: 1px solid var(--color-border)">
          <th style="padding: 8px">時間</th>
          <th style="padding: 8px">操作人</th>
          <th style="padding: 8px">動作</th>
          <th style="padding: 8px">對象</th>
          <th style="padding: 8px">說明</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="log in logs" :key="log.id" style="border-bottom: 1px solid var(--color-border)">
          <td style="padding: 8px; white-space: nowrap">{{ formatTime(log.created_at) }}</td>
          <td style="padding: 8px">{{ log.actor_name ?? '（已刪除成員）' }}</td>
          <td style="padding: 8px">{{ actionLabel[log.action] ?? log.action }}</td>
          <td style="padding: 8px">{{ resourceLabel[log.resource_type] ?? log.resource_type }}</td>
          <td style="padding: 8px">{{ log.detail ?? '-' }}</td>
        </tr>
      </tbody>
    </table>

    <p v-else-if="!isLoading" style="color: #6b7a74; font-size: 13px">查無符合條件的紀錄</p>

    <div v-if="!isLoading && total > 0" style="display: flex; justify-content: center; align-items: center; gap: 12px; margin-top: 16px; font-size: 13px">
      <button :disabled="currentPage === 1" @click="goToPage(currentPage - 1)" style="padding: 4px 10px; cursor: pointer">上一頁</button>
      <span>{{ currentPage }} / {{ totalPages }}（共 {{ total }} 筆）</span>
      <button :disabled="currentPage === totalPages" @click="goToPage(currentPage + 1)" style="padding: 4px 10px; cursor: pointer">下一頁</button>
    </div>
  </div>
</template>
EOF
echo "✅ AuditLogView.vue 已建立"

# ---------- MembersView.vue:加入刪除成員按鈕 ----------
python3 << 'PYEOF'
path = "ledger-frontend/src/views/MembersView.vue"
with open(path) as f:
    content = f.read()

old_import = "import { fetchMyHousehold, fetchMembers, addMember } from '@/api/auth'"
new_import = "import { fetchMyHousehold, fetchMembers, addMember, deleteMember } from '@/api/auth'"
if old_import not in content:
    raise SystemExit("❌ MembersView.vue import 不符")
content = content.replace(old_import, new_import)

old_fn = '''function resetAddForm() {'''
new_fn = '''async function handleDeleteMember(member: UserOut) {
  if (!confirm(`確定要刪除成員「${member.name}」嗎?此操作無法復原。`)) return
  try {
    await deleteMember(member.id)
    await loadData()
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    loadError.value = axiosErr.response?.data?.detail ?? '刪除成員失敗'
  }
}

function resetAddForm() {'''
if old_fn not in content:
    raise SystemExit("❌ MembersView.vue resetAddForm 不符")
content = content.replace(old_fn, new_fn)

old_li = '''          <span>{{ member.name }}</span>
          <span style="color: #6b7a74; font-size: 13px">{{ member.role === 'admin' ? '管理者' : '使用者' }}</span>
        </li>'''
new_li = '''          <span>{{ member.name }}</span>
          <div style="display: flex; align-items: center; gap: 12px">
            <span style="color: #6b7a74; font-size: 13px">{{ member.role === 'admin' ? '管理者' : '使用者' }}</span>
            <button
              v-if="auth.role === 'admin' && member.id !== auth.userId"
              style="padding: 4px 10px; font-size: 12px; background: #dc2626; color: #fff; border: none; border-radius: 6px; cursor: pointer"
              @click="handleDeleteMember(member)"
            >
              刪除
            </button>
          </div>
        </li>'''
if old_li not in content:
    raise SystemExit("❌ MembersView.vue 成員 li 不符")
content = content.replace(old_li, new_li)

with open(path, "w") as f:
    f.write(content)
print("✅ MembersView.vue 已修正")
PYEOF

echo "✅ 所有檔案已寫入完成"
git add -A
git commit -m "feat: 延長登入效期、成員刪除功能、帳戶餘額/刪除限管理者、新增操作紀錄(audit log)含篩選分頁"
echo "✅ 已 commit,請執行以下步驟:"
echo "  1. cd $BACKEND && source venv/bin/activate"
echo "  2. alembic revision --autogenerate -m 'add audit_logs table'"
echo "  3. 檢查 alembic/versions/*.py 內容無誤後: git add -A && git commit -m 'chore: add audit_logs migration'"
echo "  4. git push origin main"
echo "  5. server: cd /root/apps && ./deploy.sh"