#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
FRONTEND=ledger-frontend
[ -d "$BACKEND" ] && [ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

# ========== 1. 新增 app/validators.py(嚴格白名單) ==========
cat > "$BACKEND/app/validators.py" << 'EOF'
import re

# 白名單規則:只允許中文(CJK)、英文字母、數字、空白、底線、連字號
_ALLOWED_HOUSEHOLD_NAME_PATTERN = re.compile(r'^[\u4e00-\u9fffA-Za-z0-9 _-]+$')
_MAX_HOUSEHOLD_NAME_LENGTH = 50


def validate_household_name(v: str) -> str:
    """
    帳本名稱防呆規則:
    - 前後空白自動去除
    - 不可為空
    - 長度上限 50 字
    - 僅允許:中文、英文字母、數字、空白、底線(_)、連字號(-)
    """
    v = v.strip()
    if not v:
        raise ValueError("帳本名稱不可為空")
    if len(v) > _MAX_HOUSEHOLD_NAME_LENGTH:
        raise ValueError(f"帳本名稱長度不可超過 {_MAX_HOUSEHOLD_NAME_LENGTH} 字")
    if not _ALLOWED_HOUSEHOLD_NAME_PATTERN.match(v):
        raise ValueError("帳本名稱僅能包含中文、英文、數字、空白、底線(_)、連字號(-)")
    return v
EOF
echo "✅ app/validators.py 已建立(白名單規則)"

# ========== 2. models.py:Household 加 is_active ==========
python3 << 'PYEOF'
path = "ledger-backend/app/models.py"
with open(path, encoding="utf-8") as f:
    content = f.read()

old_household = '''class Household(Base):
    __tablename__ = "households"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    users: Mapped[list["User"]] = relationship(back_populates="household", cascade="all, delete-orphan")
    accounts: Mapped[list["Account"]] = relationship(back_populates="household", cascade="all, delete-orphan")
    categories: Mapped[list["Category"]] = relationship(back_populates="household", cascade="all, delete-orphan")'''

new_household = '''class Household(Base):
    __tablename__ = "households"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    is_active: Mapped[bool] = mapped_column(default=True, server_default="true", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    users: Mapped[list["User"]] = relationship(back_populates="household", cascade="all, delete-orphan")
    accounts: Mapped[list["Account"]] = relationship(back_populates="household", cascade="all, delete-orphan")
    categories: Mapped[list["Category"]] = relationship(back_populates="household", cascade="all, delete-orphan")'''

if old_household not in content:
    raise SystemExit("❌ models.py 的 Household class 內容不符,請人工檢查")
content = content.replace(old_household, new_household)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("✅ models.py 已修正(新增 is_active)")
PYEOF

# ========== 3. schemas.py:驗證器 + HouseholdOut.is_active + HouseholdUpdate ==========
python3 << 'PYEOF'
path = "ledger-backend/app/schemas.py"
with open(path, encoding="utf-8") as f:
    content = f.read()

old_import = """from datetime import datetime

from pydantic import BaseModel, EmailStr, Field

from app.models import UserRole"""
new_import = """from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, field_validator

from app.models import UserRole
from app.validators import validate_household_name"""
if old_import not in content:
    raise SystemExit("❌ schemas.py import 區塊內容不符,請人工檢查")
content = content.replace(old_import, new_import)

old_register = """class HouseholdRegister(BaseModel):
    household_name: str = Field(min_length=1, max_length=100)
    admin_name: str = Field(min_length=1, max_length=100)
    admin_username: str = Field(pattern=USERNAME_PATTERN)
    admin_email: EmailStr
    admin_password: str = Field(min_length=8, max_length=128)"""
new_register = """class HouseholdRegister(BaseModel):
    household_name: str = Field(min_length=1, max_length=50)
    admin_name: str = Field(min_length=1, max_length=100)
    admin_username: str = Field(pattern=USERNAME_PATTERN)
    admin_email: EmailStr
    admin_password: str = Field(min_length=8, max_length=128)

    _validate_household_name = field_validator("household_name")(validate_household_name)"""
if old_register not in content:
    raise SystemExit("❌ schemas.py HouseholdRegister 內容不符,請人工檢查")
content = content.replace(old_register, new_register)

old_household_out = """class HouseholdOut(BaseModel):
    id: str
    name: str
    created_at: datetime

    class Config:
        from_attributes = True"""
new_household_out = """class HouseholdOut(BaseModel):
    id: str
    name: str
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class HouseholdUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=50)

    _validate_name = field_validator("name")(validate_household_name)"""
if old_household_out not in content:
    raise SystemExit("❌ schemas.py HouseholdOut 內容不符,請人工檢查")
content = content.replace(old_household_out, new_household_out)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("✅ schemas.py 已修正")
PYEOF

# ========== 4. households.py:改名 + 封存 + 解封 endpoint ==========
python3 << 'PYEOF'
path = "ledger-backend/app/routers/households.py"
with open(path, encoding="utf-8") as f:
    content = f.read()

old_import = "from app.schemas import AuditLogPage, HouseholdOut, UserCreate, UserOut"
new_import = "from app.schemas import AuditLogPage, HouseholdOut, HouseholdUpdate, UserCreate, UserOut"
if old_import not in content:
    raise SystemExit("❌ households.py import 內容不符,請人工檢查")
content = content.replace(old_import, new_import)

old_get_me = '''@router.get("/me", response_model=HouseholdOut)
def get_my_household(current_user: User = Depends(get_current_user)):
    return current_user.household'''

new_get_me = old_get_me + '''


@router.patch("/me", response_model=HouseholdOut)
def update_household(
    payload: HouseholdUpdate,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    household = current_user.household
    old_name = household.name
    household.name = payload.name  # 特殊字元/長度已由 HouseholdUpdate 的 pydantic validator 擋掉

    log_action(db, user=current_user, action="update", resource_type="household",
               resource_id=household.id, detail=f"帳本名稱：「{old_name}」→「{household.name}」")
    db.commit()
    db.refresh(household)
    return household


@router.post("/me/archive", response_model=HouseholdOut)
def archive_household(
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    household = current_user.household
    if not household.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="帳本已封存")

    other_member_count = (
        db.query(User)
        .filter(User.household_id == current_user.household_id, User.id != current_user.id)
        .count()
    )
    if other_member_count > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="帳本內還有其他成員,只有最後一位成員時才能封存",
        )

    household.is_active = False
    log_action(db, user=current_user, action="update", resource_type="household",
               resource_id=household.id, detail="封存帳本")
    db.commit()
    db.refresh(household)
    return household


@router.post("/me/unarchive", response_model=HouseholdOut)
def unarchive_household(
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    household = current_user.household
    if household.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="帳本尚未封存")

    household.is_active = True
    log_action(db, user=current_user, action="update", resource_type="household",
               resource_id=household.id, detail="解封帳本")
    db.commit()
    db.refresh(household)
    return household'''

if old_get_me not in content:
    raise SystemExit("❌ households.py get_my_household 內容不符,請人工檢查")
content = content.replace(old_get_me, new_get_me)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("✅ households.py 已修正")
PYEOF

# ========== 5. 前端 utils/validators.ts ==========
mkdir -p "$FRONTEND/src/utils"
cat > "$FRONTEND/src/utils/validators.ts" << 'EOF'
const ALLOWED_HOUSEHOLD_NAME_PATTERN = /^[\u4e00-\u9fffA-Za-z0-9 _-]+$/
const MAX_HOUSEHOLD_NAME_LENGTH = 50

/** 回傳 null 代表通過驗證,否則回傳錯誤訊息(規則需與後端 app/validators.py 保持同步) */
export function validateHouseholdName(name: string): string | null {
  const trimmed = name.trim()
  if (!trimmed) return '帳本名稱不可為空'
  if (trimmed.length > MAX_HOUSEHOLD_NAME_LENGTH) return `帳本名稱長度不可超過 ${MAX_HOUSEHOLD_NAME_LENGTH} 字`
  if (!ALLOWED_HOUSEHOLD_NAME_PATTERN.test(trimmed)) {
    return '帳本名稱僅能包含中文、英文、數字、空白、底線(_)、連字號(-)'
  }
  return null
}
EOF
echo "✅ src/utils/validators.ts 已建立"

# ========== 6. types/api.ts:HouseholdOut 加 is_active ==========
python3 << 'PYEOF'
path = "ledger-frontend/src/types/api.ts"
with open(path, encoding="utf-8") as f:
    content = f.read()

old = """export interface HouseholdOut {
  id: string
  name: string
  created_at: string
}"""
new = """export interface HouseholdOut {
  id: string
  name: string
  is_active: boolean
  created_at: string
}"""
if old not in content:
    raise SystemExit("❌ types/api.ts HouseholdOut 內容不符,請人工檢查")
content = content.replace(old, new)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("✅ types/api.ts 已修正")
PYEOF

# ========== 7. api/auth.ts:新增 updateHousehold / archiveHousehold / unarchiveHousehold ==========
# 用 grep 檢查是否已存在,避免重複定義(這支檔案內容未知,採 append 而非精確比對)
AUTH_TS="$FRONTEND/src/api/auth.ts"
[ -f "$AUTH_TS" ] || { echo "❌ 找不到 $AUTH_TS,請確認路徑是否正確"; exit 1; }

if ! grep -q "export async function updateHousehold" "$AUTH_TS" && ! grep -q "export function updateHousehold" "$AUTH_TS"; then
cat >> "$AUTH_TS" << 'EOF'

export async function updateHousehold(name: string): Promise<HouseholdOut> {
  const { data } = await apiClient.patch<HouseholdOut>('/households/me', { name })
  return data
}
EOF
  echo "✅ auth.ts 新增 updateHousehold()"
else
  echo "ℹ️  auth.ts 已存在 updateHousehold(),略過"
fi

if ! grep -q "archiveHousehold" "$AUTH_TS"; then
cat >> "$AUTH_TS" << 'EOF'

export async function archiveHousehold(): Promise<HouseholdOut> {
  const { data } = await apiClient.post<HouseholdOut>('/households/me/archive')
  return data
}

export async function unarchiveHousehold(): Promise<HouseholdOut> {
  const { data } = await apiClient.post<HouseholdOut>('/households/me/unarchive')
  return data
}
EOF
  echo "✅ auth.ts 新增 archiveHousehold() / unarchiveHousehold()"
else
  echo "ℹ️  auth.ts 已存在 archiveHousehold(),略過"
fi

# ========== 8. MembersView.vue:改名 UI + 封存/解封 UI + 已封存畫面 ==========
python3 << 'PYEOF'
path = "ledger-frontend/src/views/MembersView.vue"
with open(path, encoding="utf-8") as f:
    content = f.read()

old_script = '''<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { fetchMyHousehold, fetchMembers, addMember, deleteMember } from '@/api/auth'
import { useAuthStore } from '@/stores/auth'
import type { HouseholdOut, UserOut } from '@/types/api'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const router = useRouter()
const auth = useAuthStore()

const household = ref<HouseholdOut | null>(null)
const members = ref<UserOut[]>([])
const isLoading = ref(true)
const loadError = ref('')

// 新增成員表單狀態
const showAddForm = ref(false)
const newName = ref('')
const newUsername = ref('')
const newEmail = ref('')
const newPassword = ref('')
const newRole = ref<'admin' | 'member'>('member')
const addError = ref('')
const isAdding = ref(false)

const USERNAME_PATTERN = /^[a-zA-Z0-9_.-]{3,50}$/

async function loadData() {
  try {
    const [householdData, membersData] = await Promise.all([fetchMyHousehold(), fetchMembers()])
    household.value = householdData
    members.value = membersData
  } catch {
    loadError.value = '載入資料失敗，請重新登入'
  } finally {
    isLoading.value = false
  }
}

onMounted(loadData)

function handleLogout() {
  auth.logout()
  router.push({ name: 'login' })
}

async function handleDeleteMember(member: UserOut) {
  if (!confirm(`確定要刪除成員「${member.name}」嗎?此操作無法復原。`)) return
  try {
    await deleteMember(member.id)
    await loadData()
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    loadError.value = axiosErr.response?.data?.detail ?? '刪除成員失敗'
  }
}

function resetAddForm() {
  newName.value = ''
  newUsername.value = ''
  newEmail.value = ''
  newPassword.value = ''
  newRole.value = 'member'
  addError.value = ''
}

async function handleAddMember() {
  addError.value = ''

  if (!USERNAME_PATTERN.test(newUsername.value)) {
    addError.value = '帳號需為 3-50 字元，僅限英數、底線、句點、連字號'
    return
  }
  if (newPassword.value.length < 8) {
    addError.value = '密碼至少需要 8 個字元'
    return
  }

  isAdding.value = true
  try {
    await addMember({
      name: newName.value,
      username: newUsername.value,
      email: newEmail.value,
      password: newPassword.value,
      role: newRole.value,
    })
    resetAddForm()
    showAddForm.value = false
    await loadData() // 重新載入成員列表
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    addError.value = axiosErr.response?.data?.detail ?? '新增成員失敗'
  } finally {
    isAdding.value = false
  }
}
</script>'''

new_script = '''<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import {
  fetchMyHousehold,
  fetchMembers,
  addMember,
  deleteMember,
  updateHousehold,
  archiveHousehold,
  unarchiveHousehold,
} from '@/api/auth'
import { useAuthStore } from '@/stores/auth'
import type { HouseholdOut, UserOut } from '@/types/api'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'
import { validateHouseholdName } from '@/utils/validators'

const router = useRouter()
const auth = useAuthStore()

const household = ref<HouseholdOut | null>(null)
const members = ref<UserOut[]>([])
const isLoading = ref(true)
const loadError = ref('')

// 帳本名稱編輯狀態(僅 admin 可編輯)
const editingName = ref(false)
const nameDraft = ref('')
const nameError = ref('')
const isSavingName = ref(false)

// 封存/解封狀態(僅 admin 可操作)
const isTogglingArchive = ref(false)

// 新增成員表單狀態
const showAddForm = ref(false)
const newName = ref('')
const newUsername = ref('')
const newEmail = ref('')
const newPassword = ref('')
const newRole = ref<'admin' | 'member'>('member')
const addError = ref('')
const isAdding = ref(false)

const USERNAME_PATTERN = /^[a-zA-Z0-9_.-]{3,50}$/

async function loadData() {
  try {
    const [householdData, membersData] = await Promise.all([fetchMyHousehold(), fetchMembers()])
    household.value = householdData
    members.value = membersData
  } catch {
    loadError.value = '載入資料失敗，請重新登入'
  } finally {
    isLoading.value = false
  }
}

onMounted(loadData)

function handleLogout() {
  auth.logout()
  router.push({ name: 'login' })
}

function startEditName() {
  if (!household.value) return
  nameDraft.value = household.value.name
  nameError.value = ''
  editingName.value = true
}

function cancelEditName() {
  editingName.value = false
  nameError.value = ''
}

async function saveHouseholdName() {
  const err = validateHouseholdName(nameDraft.value)
  if (err) {
    nameError.value = err
    return
  }
  isSavingName.value = true
  try {
    const updated = await updateHousehold(nameDraft.value.trim())
    household.value = updated
    editingName.value = false
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    nameError.value = axiosErr.response?.data?.detail ?? '更新帳本名稱失敗'
  } finally {
    isSavingName.value = false
  }
}

async function handleArchive() {
  const otherMemberCount = members.value.filter((m) => m.id !== auth.userId).length
  if (otherMemberCount > 0) {
    loadError.value = '帳本內還有其他成員,只有最後一位成員時才能封存'
    return
  }
  if (!confirm('確定要封存這個帳本嗎?封存後僅能檢視,需由管理者解封才能恢復使用。')) return

  isTogglingArchive.value = true
  try {
    household.value = await archiveHousehold()
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    loadError.value = axiosErr.response?.data?.detail ?? '封存帳本失敗'
  } finally {
    isTogglingArchive.value = false
  }
}

async function handleUnarchive() {
  isTogglingArchive.value = true
  try {
    household.value = await unarchiveHousehold()
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    loadError.value = axiosErr.response?.data?.detail ?? '解封帳本失敗'
  } finally {
    isTogglingArchive.value = false
  }
}

async function handleDeleteMember(member: UserOut) {
  if (!confirm(`確定要刪除成員「${member.name}」嗎?此操作無法復原。`)) return
  try {
    await deleteMember(member.id)
    await loadData()
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    loadError.value = axiosErr.response?.data?.detail ?? '刪除成員失敗'
  }
}

function resetAddForm() {
  newName.value = ''
  newUsername.value = ''
  newEmail.value = ''
  newPassword.value = ''
  newRole.value = 'member'
  addError.value = ''
}

async function handleAddMember() {
  addError.value = ''

  if (!USERNAME_PATTERN.test(newUsername.value)) {
    addError.value = '帳號需為 3-50 字元，僅限英數、底線、句點、連字號'
    return
  }
  if (newPassword.value.length < 8) {
    addError.value = '密碼至少需要 8 個字元'
    return
  }

  isAdding.value = true
  try {
    await addMember({
      name: newName.value,
      username: newUsername.value,
      email: newEmail.value,
      password: newPassword.value,
      role: newRole.value,
    })
    resetAddForm()
    showAddForm.value = false
    await loadData() // 重新載入成員列表
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    addError.value = axiosErr.response?.data?.detail ?? '新增成員失敗'
  } finally {
    isAdding.value = false
  }
}
</script>'''

if old_script not in content:
    raise SystemExit("❌ MembersView.vue <script> 內容不符,請人工檢查")
content = content.replace(old_script, new_script)

old_template = '''<template>
  <div style="max-width: 720px; margin: 0 auto; padding: 32px 24px">
    <header style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 32px">
      <h1 style="font-size: 20px; margin: 0">{{ household?.name ?? '載入中…' }}</h1>
      <div style="display: flex; gap: 12px; align-items: center">
        <router-link to="/" style="font-size: 13px; color: var(--color-primary); text-decoration: none">
          返回理財首頁
        </router-link>
        <button class="btn-primary" style="width: auto; padding: 8px 16px" @click="handleLogout">
          登出
        </button>
      </div>
    </header>

    <div v-if="loadError" class="error-banner">{{ loadError }}</div>

    <section v-if="!isLoading">
      <div style="display: flex; justify-content: space-between; align-items: center">
        <h2 style="font-size: 15px; color: #6b7a74; text-transform: uppercase; letter-spacing: 0.04em; margin: 0">
          成員
        </h2>
        <!-- 僅管理者可見:新增成員為 UX 便利,實際權限由後端 require_admin 把關 -->
        <button
          v-if="auth.role === 'admin'"
          class="btn-primary"
          style="width: auto; padding: 6px 14px; font-size: 13px"
          @click="showAddForm = !showAddForm"
        >
          {{ showAddForm ? '取消' : '+ 新增成員' }}
        </button>
      </div>'''

new_template_head = '''<template>
  <div
    v-if="household && !household.is_active"
    style="max-width: 480px; margin: 80px auto; padding: 32px 24px; text-align: center"
  >
    <h1 style="font-size: 20px; margin-bottom: 12px">{{ household.name }}</h1>
    <p style="color: #6b7a74; font-size: 14px; margin-bottom: 24px">
      此帳本已封存,目前僅能檢視,無法使用其他功能。
    </p>
    <div v-if="loadError" class="error-banner" style="margin-bottom: 16px">{{ loadError }}</div>
    <button
      v-if="auth.role === 'admin'"
      class="btn-primary"
      style="width: auto; padding: 8px 20px"
      :disabled="isTogglingArchive"
      @click="handleUnarchive"
    >
      {{ isTogglingArchive ? '解封中…' : '解封帳本' }}
    </button>
    <button
      class="btn-primary"
      style="width: auto; padding: 8px 20px; margin-left: 8px; background: #6b7a74"
      @click="handleLogout"
    >
      登出
    </button>
  </div>

  <div v-else style="max-width: 720px; margin: 0 auto; padding: 32px 24px">
    <header style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 32px">
      <div v-if="!editingName" style="display: flex; align-items: center; gap: 8px">
        <h1 style="font-size: 20px; margin: 0">{{ household?.name ?? '載入中…' }}</h1>
        <button
          v-if="auth.role === 'admin' && household"
          style="border: none; background: none; cursor: pointer; color: var(--color-primary); font-size: 13px; padding: 2px 6px"
          @click="startEditName"
        >
          編輯
        </button>
      </div>
      <div v-else style="display: flex; flex-direction: column; gap: 6px; max-width: 320px">
        <div style="display: flex; gap: 8px">
          <input
            v-model="nameDraft"
            type="text"
            maxlength="50"
            style="flex: 1; padding: 6px 10px; border: 1px solid var(--color-border); border-radius: 6px; font-size: 15px"
            @keyup.enter="saveHouseholdName"
          />
          <button
            class="btn-primary"
            style="width: auto; padding: 6px 12px; font-size: 13px"
            :disabled="isSavingName"
            @click="saveHouseholdName"
          >
            {{ isSavingName ? '儲存中…' : '儲存' }}
          </button>
          <button style="width: auto; padding: 6px 12px; font-size: 13px" @click="cancelEditName">取消</button>
        </div>
        <span v-if="nameError" style="color: #dc2626; font-size: 12px">{{ nameError }}</span>
      </div>

      <div style="display: flex; gap: 12px; align-items: center">
        <router-link to="/" style="font-size: 13px; color: var(--color-primary); text-decoration: none">
          返回理財首頁
        </router-link>
        <button class="btn-primary" style="width: auto; padding: 8px 16px" @click="handleLogout">
          登出
        </button>
      </div>
    </header>

    <div v-if="loadError" class="error-banner">{{ loadError }}</div>

    <section v-if="!isLoading">
      <div style="display: flex; justify-content: space-between; align-items: center">
        <h2 style="font-size: 15px; color: #6b7a74; text-transform: uppercase; letter-spacing: 0.04em; margin: 0">
          成員
        </h2>
        <!-- 僅管理者可見:新增成員為 UX 便利,實際權限由後端 require_admin 把關 -->
        <button
          v-if="auth.role === 'admin'"
          class="btn-primary"
          style="width: auto; padding: 6px 14px; font-size: 13px"
          @click="showAddForm = !showAddForm"
        >
          {{ showAddForm ? '取消' : '+ 新增成員' }}
        </button>
      </div>'''

if old_template not in content:
    raise SystemExit("❌ MembersView.vue <template> 開頭區塊內容不符,請人工檢查")
content = content.replace(old_template, new_template_head)

old_tail = '''    </section>

    <p style="color: #6b7a74; font-size: 13px; margin-top: 32px">
      交易紀錄、多帳戶與統計圖表功能將在下一步接續開發。
    </p>
  </div>
</template>'''

new_tail = '''    </section>

    <div
      v-if="auth.role === 'admin' && !isLoading"
      style="margin-top: 32px; padding-top: 16px; border-top: 1px solid var(--color-border)"
    >
      <button
        style="width: auto; padding: 6px 14px; font-size: 13px; background: #6b7a74; color: #fff; border: none; border-radius: 6px; cursor: pointer"
        :disabled="isTogglingArchive"
        @click="handleArchive"
      >
        {{ isTogglingArchive ? '封存中…' : '封存此帳本' }}
      </button>
      <span style="color: #6b7a74; font-size: 12px; margin-left: 8px">僅在帳本內只剩自己一位成員時可封存</span>
    </div>

    <p style="color: #6b7a74; font-size: 13px; margin-top: 32px">
      交易紀錄、多帳戶與統計圖表功能將在下一步接續開發。
    </p>
  </div>
</template>'''

if old_tail not in content:
    raise SystemExit("❌ MembersView.vue <template> 結尾區塊內容不符,請人工檢查")
content = content.replace(old_tail, new_tail)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("✅ MembersView.vue 已修正")
PYEOF

echo ""
echo "⚠️  is_active 是新欄位,請依 migration-sop-20260707.md 流程補 migration:"
echo "    cd ledger-backend && source venv/bin/activate"
echo "    alembic revision --autogenerate -m 'add household is_active'"
echo "    人工檢查產生的檔案:應只有 households 表新增 is_active 欄位(server_default true)"
echo "    確認無誤後: git add alembic/versions/*.py"
echo ""

git add -A
git commit -m "feat: 帳本改名 + 名稱白名單驗證 + 封存/解封帳本功能"
echo "✅ 已 commit。接下來:"
echo "   1) 到 server 上補 migration(見上方提示)並一併 commit"
echo "   2) git push origin main"
echo "   3) server 執行 ./deploy.sh"
