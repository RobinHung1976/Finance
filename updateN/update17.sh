#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
FRONTEND=ledger-frontend
[ -d "$BACKEND" ] && [ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

# ========== Backend: 新增檔案 ==========
cat > "$BACKEND/app/schemas_tag.py" << 'EOF'
from pydantic import BaseModel, Field


class TagCreate(BaseModel):
    name: str = Field(min_length=1, max_length=50)


class TagUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=50)


class TagOut(BaseModel):
    id: str
    name: str

    class Config:
        from_attributes = True
EOF

cat > "$BACKEND/app/routers/tags.py" << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models import Tag, User
from app.schemas_tag import TagCreate, TagUpdate, TagOut

router = APIRouter(prefix="/tags", tags=["tags"])


@router.get("", response_model=list[TagOut])
def list_tags(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(Tag)
        .filter(Tag.household_id == current_user.household_id)
        .order_by(Tag.name)
        .all()
    )


@router.post("", response_model=TagOut, status_code=status.HTTP_201_CREATED)
def create_tag(
    payload: TagCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    tag = Tag(household_id=current_user.household_id, name=payload.name.strip())
    db.add(tag)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="此消費品項名稱已存在")
    db.refresh(tag)
    return tag


@router.patch("/{tag_id}", response_model=TagOut)
def update_tag(
    tag_id: str,
    payload: TagUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    tag = db.get(Tag, tag_id)
    if tag is None or tag.household_id != current_user.household_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="消費品項不存在")
    tag.name = payload.name.strip()
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="此消費品項名稱已存在")
    db.refresh(tag)
    return tag


@router.delete("/{tag_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_tag(
    tag_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    tag = db.get(Tag, tag_id)
    if tag is None or tag.household_id != current_user.household_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="消費品項不存在")
    db.delete(tag)  # TransactionTag 為 ondelete=CASCADE,關聯會一併清除,交易本身不受影響
    db.commit()
EOF

# ========== Backend: models.py 加 Transaction.tags relationship(僅讀取用) ==========
python3 << 'PYEOF'
path = "ledger-backend/app/models.py"
with open(path) as f:
    content = f.read()

old = '''    note: Mapped[str | None] = mapped_column(String(500), nullable=True)


class Budget(Base):'''

new = '''    note: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # 消費品項(店家/商家),多對多,透過既有 transaction_tags join table。
    # 寫入一律由 router 手動操作 TransactionTag,這裡只做讀取(viewonly),
    # 避免像 Category.children 那樣因 cascade 設定誤判孤兒物件。
    tags: Mapped[list["Tag"]] = relationship(
        "Tag", secondary="transaction_tags", viewonly=True, lazy="selectin"
    )


class Budget(Base):'''

if old not in content:
    raise SystemExit("❌ models.py 錨點不符,請人工檢查")
content = content.replace(old, new, 1)
with open(path, "w") as f:
    f.write(content)
print("✅ models.py: Transaction.tags relationship 已加入")
PYEOF

# ========== Backend: schemas_ledger.py ==========
python3 << 'PYEOF'
path = "ledger-backend/app/schemas_ledger.py"
with open(path) as f:
    content = f.read()

old_import = "from app.models import AccountType, EntryType"
new_import = "from app.models import AccountType, EntryType\nfrom app.schemas_tag import TagOut"
if old_import not in content:
    raise SystemExit("❌ import 錨點不符")
content = content.replace(old_import, new_import, 1)

old_create = '''class TransactionCreate(BaseModel):
    account_id: str
    category_id: str
    amount: float = Field(gt=0)
    type: EntryType
    date: date_type
    note: str | None = Field(default=None, max_length=500)

    @field_validator("amount")'''
new_create = '''class TransactionCreate(BaseModel):
    account_id: str
    category_id: str
    amount: float = Field(gt=0)
    type: EntryType
    date: date_type
    note: str | None = Field(default=None, max_length=500)
    tag_ids: list[str] = Field(default_factory=list)

    @field_validator("amount")'''
if old_create not in content:
    raise SystemExit("❌ TransactionCreate 錨點不符")
content = content.replace(old_create, new_create, 1)

old_update = '''class TransactionUpdate(BaseModel):
    account_id: str | None = None
    category_id: str | None = None
    amount: float | None = Field(default=None, gt=0)
    type: EntryType | None = None
    date: date_type | None = None
    note: str | None = Field(default=None, max_length=500)'''
new_update = '''class TransactionUpdate(BaseModel):
    account_id: str | None = None
    category_id: str | None = None
    amount: float | None = Field(default=None, gt=0)
    type: EntryType | None = None
    date: date_type | None = None
    note: str | None = Field(default=None, max_length=500)
    tag_ids: list[str] | None = None  # None=不變動,[]=清空所有品項'''
if old_update not in content:
    raise SystemExit("❌ TransactionUpdate 錨點不符")
content = content.replace(old_update, new_update, 1)

old_out = '''class TransactionOut(BaseModel):
    id: str
    account_id: str
    category_id: str
    amount: float
    type: EntryType
    date: date_type
    note: str | None
    user_id: str | None

    class Config:
        from_attributes = True'''
new_out = '''class TransactionOut(BaseModel):
    id: str
    account_id: str
    category_id: str
    amount: float
    type: EntryType
    date: date_type
    note: str | None
    user_id: str | None
    tags: list[TagOut] = []

    class Config:
        from_attributes = True'''
if old_out not in content:
    raise SystemExit("❌ TransactionOut 錨點不符")
content = content.replace(old_out, new_out, 1)

with open(path, "w") as f:
    f.write(content)
print("✅ schemas_ledger.py 已加入 tag_ids/tags")
PYEOF

# ========== Backend: transactions.py ==========
python3 << 'PYEOF'
path = "ledger-backend/app/routers/transactions.py"
with open(path) as f:
    content = f.read()

old_import = '''from app.models import Account, Category, Transaction, User
from app.schemas_ledger import TransactionCreate, TransactionOut, TransactionUpdate'''
new_import = '''from app.models import Account, Category, Tag, Transaction, TransactionTag, User
from app.schemas_ledger import TransactionCreate, TransactionOut, TransactionUpdate'''
if old_import not in content:
    raise SystemExit("❌ import 錨點不符")
content = content.replace(old_import, new_import, 1)

old_helper = '''def _validate_account_and_category(payload_dict: dict, household_id: str, db: Session) -> None:
    if "account_id" in payload_dict:
        account = db.get(Account, payload_dict["account_id"])
        if account is None or account.household_id != household_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="帳戶不存在")
    if "category_id" in payload_dict:
        category = db.get(Category, payload_dict["category_id"])
        if category is None or category.household_id != household_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="分類不存在")'''
new_helper = '''def _validate_account_and_category(payload_dict: dict, household_id: str, db: Session) -> None:
    if "account_id" in payload_dict:
        account = db.get(Account, payload_dict["account_id"])
        if account is None or account.household_id != household_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="帳戶不存在")
    if "category_id" in payload_dict:
        category = db.get(Category, payload_dict["category_id"])
        if category is None or category.household_id != household_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="分類不存在")


def _validate_tag_ids(tag_ids: list[str], household_id: str, db: Session) -> None:
    if not tag_ids:
        return
    unique_ids = set(tag_ids)
    count = db.query(Tag).filter(Tag.household_id == household_id, Tag.id.in_(unique_ids)).count()
    if count != len(unique_ids):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="消費品項不存在")


def _set_transaction_tags(tx_id: str, tag_ids: list[str], db: Session) -> None:
    db.query(TransactionTag).filter(TransactionTag.transaction_id == tx_id).delete()
    for tag_id in set(tag_ids):
        db.add(TransactionTag(transaction_id=tx_id, tag_id=tag_id))'''
if old_helper not in content:
    raise SystemExit("❌ helper 錨點不符")
content = content.replace(old_helper, new_helper, 1)

old_create = '''    payload_dict = payload.model_dump()
    _validate_account_and_category(payload_dict, current_user.household_id, db)

    tx = Transaction(
        household_id=current_user.household_id,
        user_id=current_user.id,
        **payload_dict,
    )
    db.add(tx)

    # 更新帳戶餘額:收入加、支出減'''
new_create = '''    payload_dict = payload.model_dump()
    tag_ids = payload_dict.pop("tag_ids")
    _validate_account_and_category(payload_dict, current_user.household_id, db)
    _validate_tag_ids(tag_ids, current_user.household_id, db)

    tx = Transaction(
        household_id=current_user.household_id,
        user_id=current_user.id,
        **payload_dict,
    )
    db.add(tx)
    db.flush()  # 取得 tx.id 供 TransactionTag 使用
    _set_transaction_tags(tx.id, tag_ids, db)

    # 更新帳戶餘額:收入加、支出減'''
if old_create not in content:
    raise SystemExit("❌ create_transaction 錨點不符")
content = content.replace(old_create, new_create, 1)

old_update = '''    tx = _get_owned_transaction(transaction_id, current_user, db)
    update_data = payload.model_dump(exclude_unset=True)
    _validate_account_and_category(update_data, current_user.household_id, db)

    # 若金額/類型/帳戶有變動,先復原舊帳戶餘額,再套用新值
    old_account = db.get(Account, tx.account_id)
    if tx.type.value == "income":
        old_account.balance = float(old_account.balance) - float(tx.amount)
    else:
        old_account.balance = float(old_account.balance) + float(tx.amount)

    for field, value in update_data.items():
        setattr(tx, field, value)

    new_account = db.get(Account, tx.account_id)'''
new_update = '''    tx = _get_owned_transaction(transaction_id, current_user, db)
    update_data = payload.model_dump(exclude_unset=True)
    tag_ids = update_data.pop("tag_ids", None)  # None=不變動,[]=清空
    _validate_account_and_category(update_data, current_user.household_id, db)
    if tag_ids is not None:
        _validate_tag_ids(tag_ids, current_user.household_id, db)

    # 若金額/類型/帳戶有變動,先復原舊帳戶餘額,再套用新值
    old_account = db.get(Account, tx.account_id)
    if tx.type.value == "income":
        old_account.balance = float(old_account.balance) - float(tx.amount)
    else:
        old_account.balance = float(old_account.balance) + float(tx.amount)

    for field, value in update_data.items():
        setattr(tx, field, value)

    if tag_ids is not None:
        _set_transaction_tags(tx.id, tag_ids, db)

    new_account = db.get(Account, tx.account_id)'''
if old_update not in content:
    raise SystemExit("❌ update_transaction 錨點不符")
content = content.replace(old_update, new_update, 1)

with open(path, "w") as f:
    f.write(content)
print("✅ transactions.py 已加入 tag_ids 處理邏輯")
PYEOF

# ========== Backend: main.py 掛載 tags router ==========
python3 << 'PYEOF'
path = "ledger-backend/app/main.py"
with open(path) as f:
    content = f.read()

old_import = "from app.routers import auth, households, accounts, categories, transactions, transactions_transfer, stats"
new_import = "from app.routers import auth, households, accounts, categories, transactions, transactions_transfer, stats, tags"
if old_import not in content:
    raise SystemExit("❌ import 錨點不符")
content = content.replace(old_import, new_import, 1)

old_anchor = "app.include_router(stats.router)"
if old_anchor not in content:
    raise SystemExit("❌ include_router 錨點不符")
if "app.include_router(tags.router)" not in content:
    content = content.replace(old_anchor, old_anchor + "\napp.include_router(tags.router)", 1)

with open(path, "w") as f:
    f.write(content)
print("✅ main.py 已掛載 tags.router")
PYEOF

# ========== Frontend: types/ledger.ts ==========
python3 << 'PYEOF'
path = "ledger-frontend/src/types/ledger.ts"
with open(path) as f:
    content = f.read()

old_create_payload = '''export interface TransactionCreatePayload {
  account_id: string
  category_id: string
  amount: number
  type: EntryType
  date: string
  note: string | null
}'''
new_create_payload = '''export interface TransactionCreatePayload {
  account_id: string
  category_id: string
  amount: number
  type: EntryType
  date: string
  note: string | null
  tag_ids?: string[]
}'''
if old_create_payload not in content:
    raise SystemExit("❌ TransactionCreatePayload 錨點不符")
content = content.replace(old_create_payload, new_create_payload, 1)

old_out = '''export interface TransactionOut {
  id: string
  account_id: string
  category_id: string
  amount: number
  type: EntryType
  date: string
  note: string | null
  user_id: string | null
}'''
new_out = '''export interface TagOut {
  id: string
  name: string
}
export interface TagCreatePayload {
  name: string
}
export interface TransactionOut {
  id: string
  account_id: string
  category_id: string
  amount: number
  type: EntryType
  date: string
  note: string | null
  user_id: string | null
  tags: TagOut[]
}'''
if old_out not in content:
    raise SystemExit("❌ TransactionOut 錨點不符")
content = content.replace(old_out, new_out, 1)

with open(path, "w") as f:
    f.write(content)
print("✅ types/ledger.ts 已加入 TagOut/TagCreatePayload/tag_ids")
PYEOF

# ========== Frontend: api/ledger.ts ==========
python3 << 'PYEOF'
path = "ledger-frontend/src/api/ledger.ts"
with open(path) as f:
    content = f.read()

old_import = '''import type {
  AccountOut,
  AccountCreatePayload,
  CategoryOut,
  CategoryCreatePayload,
  TransactionOut,
  TransactionCreatePayload,
  TransactionFilters,
  MonthlyTrendOut,
  CategoryBreakdownOut,
  EntryType,
} from '@/types/ledger\''''
new_import = '''import type {
  AccountOut,
  AccountCreatePayload,
  CategoryOut,
  CategoryCreatePayload,
  TagOut,
  TagCreatePayload,
  TransactionOut,
  TransactionCreatePayload,
  TransactionFilters,
  MonthlyTrendOut,
  CategoryBreakdownOut,
  EntryType,
} from '@/types/ledger\''''
if old_import not in content:
    raise SystemExit("❌ import 錨點不符")
content = content.replace(old_import, new_import, 1)

old_anchor = '''export function deleteCategory(id: string) {
  return apiClient.delete(`/categories/${id}`)
}'''
new_anchor = '''export function deleteCategory(id: string) {
  return apiClient.delete(`/categories/${id}`)
}
export function fetchTags() {
  return apiClient.get<TagOut[]>('/tags').then((r) => r.data)
}
export function createTag(payload: TagCreatePayload) {
  return apiClient.post<TagOut>('/tags', payload).then((r) => r.data)
}
export function deleteTag(id: string) {
  return apiClient.delete(`/tags/${id}`)
}'''
if old_anchor not in content:
    raise SystemExit("❌ deleteCategory 錨點不符")
content = content.replace(old_anchor, new_anchor, 1)

with open(path, "w") as f:
    f.write(content)
print("✅ api/ledger.ts 已加入 fetchTags/createTag/deleteTag")
PYEOF

# ========== Frontend: 新增 TagPicker.vue ==========
cat > "$FRONTEND/src/components/TagPicker.vue" << 'EOF'
<script setup lang="ts">
import { ref, computed } from 'vue'
import { createTag } from '@/api/ledger'
import type { TagOut } from '@/types/ledger'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const props = defineProps<{
  modelValue: string[]
  tags: TagOut[]
}>()
const emit = defineEmits<{
  'update:modelValue': [value: string[]]
  created: [tag: TagOut]
}>()

const searchQuery = ref('')
const showCreateForm = ref(false)
const newTagName = ref('')
const createError = ref('')
const isCreating = ref(false)

const filteredTags = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return props.tags
  return props.tags.filter((t) => t.name.toLowerCase().includes(q))
})

function isSelected(id: string) {
  return props.modelValue.includes(id)
}

function toggleTag(id: string) {
  const next = isSelected(id) ? props.modelValue.filter((v) => v !== id) : [...props.modelValue, id]
  emit('update:modelValue', next)
}

async function handleCreate() {
  createError.value = ''
  if (!newTagName.value.trim()) {
    createError.value = '請輸入消費品項名稱'
    return
  }
  isCreating.value = true
  try {
    const created = await createTag({ name: newTagName.value.trim() })
    emit('created', created)
    emit('update:modelValue', [...props.modelValue, created.id])
    newTagName.value = ''
    showCreateForm.value = false
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    createError.value = axiosErr.response?.data?.detail ?? '新增失敗'
  } finally {
    isCreating.value = false
  }
}
</script>

<template>
  <div class="tag-picker">
    <input v-model="searchQuery" type="text" class="search-input" placeholder="搜尋消費品項…" />
    <div class="tag-grid">
      <button
        v-for="t in filteredTags"
        :key="t.id"
        type="button"
        class="tag-btn"
        :class="{ selected: isSelected(t.id) }"
        @click="toggleTag(t.id)"
      >
        {{ t.name }}
      </button>
      <button type="button" class="tag-btn add-btn" @click="showCreateForm = !showCreateForm">
        + 新增品項
      </button>
    </div>
    <form v-if="showCreateForm" class="create-form" @submit.prevent="handleCreate">
      <input v-model="newTagName" type="text" maxlength="50" placeholder="品項名稱（例如：三媽）" required />
      <button class="btn-primary" type="submit" style="width: auto; padding: 6px 14px" :disabled="isCreating">
        {{ isCreating ? '新增中…' : '確認' }}
      </button>
    </form>
    <div v-if="createError" class="error-banner" style="margin-top: 6px">{{ createError }}</div>
  </div>
</template>

<style scoped>
.tag-picker {
  border: 1px solid var(--color-border);
  border-radius: 8px;
  padding: 10px;
  background: var(--color-bg);
}
.search-input {
  width: 100%;
  padding: 6px 10px;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  font-size: 13px;
  margin-bottom: 8px;
  box-sizing: border-box;
}
.tag-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.tag-btn {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 999px;
  padding: 6px 14px;
  font-size: 13px;
  cursor: pointer;
}
.tag-btn.selected {
  border-color: var(--color-primary);
  background: var(--color-primary);
  color: #fff;
  font-weight: 600;
}
.add-btn {
  color: var(--color-primary);
  border-style: dashed;
  background: none;
}
.create-form {
  display: flex;
  gap: 8px;
  margin-top: 8px;
}
.create-form input {
  flex: 1;
  padding: 6px 10px;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  font-size: 13px;
}
</style>
EOF

# ========== Frontend: 新增 TagList.vue(消費品項管理頁) ==========
cat > "$FRONTEND/src/components/TagList.vue" << 'EOF'
<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { fetchTags, createTag, deleteTag } from '@/api/ledger'
import type { TagOut } from '@/types/ledger'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const emit = defineEmits<{ changed: [] }>()

const tags = ref<TagOut[]>([])
const isLoading = ref(true)
const loadError = ref('')
const newTagName = ref('')
const createError = ref('')
const isCreating = ref(false)

async function load() {
  isLoading.value = true
  loadError.value = ''
  try {
    tags.value = await fetchTags()
  } catch {
    loadError.value = '載入消費品項失敗'
  } finally {
    isLoading.value = false
  }
}

onMounted(load)

async function handleCreate() {
  createError.value = ''
  if (!newTagName.value.trim()) {
    createError.value = '請輸入名稱'
    return
  }
  isCreating.value = true
  try {
    const created = await createTag({ name: newTagName.value.trim() })
    tags.value.push(created)
    newTagName.value = ''
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    createError.value = axiosErr.response?.data?.detail ?? '新增失敗'
  } finally {
    isCreating.value = false
  }
}

async function handleDelete(id: string) {
  if (!confirm('確定刪除此消費品項？已使用此品項的交易將移除此標籤，交易本身不受影響。')) return
  try {
    await deleteTag(id)
    tags.value = tags.value.filter((t) => t.id !== id)
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    alert(axiosErr.response?.data?.detail ?? '刪除失敗')
  }
}
</script>

<template>
  <div>
    <h2 style="font-size: 15px; color: #6b7a74; text-transform: uppercase; letter-spacing: 0.04em; margin: 0 0 12px">
      消費品項管理
    </h2>
    <form class="inline-card" @submit.prevent="handleCreate" style="display: flex; gap: 8px; align-items: flex-start">
      <div style="flex: 1">
        <input
          v-model="newTagName"
          type="text"
          maxlength="50"
          placeholder="新增消費品項（例如：三媽）"
          style="width: 100%; padding: 8px 10px; border: 1px solid var(--color-border); border-radius: 6px; box-sizing: border-box"
        />
        <div v-if="createError" class="error-banner" style="margin-top: 6px">{{ createError }}</div>
      </div>
      <button class="btn-primary" type="submit" style="width: auto; padding: 8px 16px" :disabled="isCreating">
        {{ isCreating ? '新增中…' : '新增' }}
      </button>
    </form>

    <div v-if="loadError" class="error-banner">{{ loadError }}</div>
    <p v-if="!isLoading && tags.length === 0" style="color: #6b7a74; font-size: 13px">尚未建立任何消費品項。</p>

    <div v-for="t in tags" :key="t.id" class="row-card">
      <span>{{ t.name }}</span>
      <button class="btn-text-danger" @click="handleDelete(t.id)">刪除</button>
    </div>
  </div>
</template>
EOF

# ========== Frontend: TransactionList.vue 修改 ==========
python3 << 'PYEOF'
path = "ledger-frontend/src/components/TransactionList.vue"
with open(path) as f:
    content = f.read()

replacements = [
    ("""import { computed, onMounted, ref, watch } from 'vue'
import CategoryPicker from './CategoryPicker.vue'
import { fetchAccounts, fetchCategories, fetchTransactions, createTransaction, updateTransaction, deleteTransaction } from '@/api/ledger'
import { formatCurrency } from '@/utils/ledgerLabels'
import type { AccountOut, CategoryOut, EntryType, TransactionOut } from '@/types/ledger'""",
     """import { computed, onMounted, ref, watch } from 'vue'
import CategoryPicker from './CategoryPicker.vue'
import TagPicker from './TagPicker.vue'
import { fetchAccounts, fetchCategories, fetchTags, fetchTransactions, createTransaction, updateTransaction, deleteTransaction } from '@/api/ledger'
import { formatCurrency } from '@/utils/ledgerLabels'
import type { AccountOut, CategoryOut, EntryType, TagOut, TransactionOut } from '@/types/ledger'"""),

    ("""const accounts = ref<AccountOut[]>([])
const categories = ref<CategoryOut[]>([])
const transactions = ref<TransactionOut[]>([])""",
     """const accounts = ref<AccountOut[]>([])
const categories = ref<CategoryOut[]>([])
const tags = ref<TagOut[]>([])
const transactions = ref<TransactionOut[]>([])"""),

    ("""const formAmount = ref<number | null>(null)
const formDate = ref(todayLocalISODate())
const formNote = ref('')
const formError = ref('')
const isSubmitting = ref(false)""",
     """const formAmount = ref<number | null>(null)
const formDate = ref(todayLocalISODate())
const formNote = ref('')
const formTagIds = ref<string[]>([])
const formError = ref('')
const isSubmitting = ref(false)"""),

    ("""const editAmount = ref<number | null>(null)
const editType = ref<EntryType>('expense')
const editDate = ref('')
const editNote = ref('')
const editError = ref('')
const isSavingEdit = ref(false)""",
     """const editAmount = ref<number | null>(null)
const editType = ref<EntryType>('expense')
const editDate = ref('')
const editNote = ref('')
const editTagIds = ref<string[]>([])
const editError = ref('')
const isSavingEdit = ref(false)"""),

    ("""async function loadReferenceData() {
  const [accountsData, categoriesData] = await Promise.all([fetchAccounts(), fetchCategories()])
  accounts.value = accountsData
  categories.value = categoriesData
}""",
     """async function loadReferenceData() {
  const [accountsData, categoriesData, tagsData] = await Promise.all([fetchAccounts(), fetchCategories(), fetchTags()])
  accounts.value = accountsData
  categories.value = categoriesData
  tags.value = tagsData
}"""),

    ("""function handleCategoryCreated(category: CategoryOut) {
  categories.value.push(category)
}""",
     """function handleCategoryCreated(category: CategoryOut) {
  categories.value.push(category)
}

function handleTagCreated(tag: TagOut) {
  tags.value.push(tag)
}"""),

    ("""    await createTransaction({
      account_id: formAccountId.value,
      category_id: formCategoryId.value,
      amount: formAmount.value,
      type: formType.value,
      date: formDate.value,
      note: formNote.value.trim() || null,
    })
    formAmount.value = null
    formNote.value = ''
    showForm.value = false""",
     """    await createTransaction({
      account_id: formAccountId.value,
      category_id: formCategoryId.value,
      amount: formAmount.value,
      type: formType.value,
      date: formDate.value,
      note: formNote.value.trim() || null,
      tag_ids: formTagIds.value,
    })
    formAmount.value = null
    formNote.value = ''
    formTagIds.value = []
    showForm.value = false"""),

    ("""function startEdit(tx: TransactionOut) {
  editingId.value = tx.id
  editAccountId.value = tx.account_id
  editCategoryId.value = tx.category_id
  editAmount.value = tx.amount
  editType.value = tx.type
  editDate.value = tx.date
  editNote.value = tx.note ?? ''
  editError.value = ''
}""",
     """function startEdit(tx: TransactionOut) {
  editingId.value = tx.id
  editAccountId.value = tx.account_id
  editCategoryId.value = tx.category_id
  editAmount.value = tx.amount
  editType.value = tx.type
  editDate.value = tx.date
  editNote.value = tx.note ?? ''
  editTagIds.value = tx.tags.map((t) => t.id)
  editError.value = ''
}"""),

    ("""    await updateTransaction(id, {
      account_id: editAccountId.value,
      category_id: editCategoryId.value,
      amount: editAmount.value,
      type: editType.value,
      date: editDate.value,
      note: editNote.value.trim() || null,
    })""",
     """    await updateTransaction(id, {
      account_id: editAccountId.value,
      category_id: editCategoryId.value,
      amount: editAmount.value,
      type: editType.value,
      date: editDate.value,
      note: editNote.value.trim() || null,
      tag_ids: editTagIds.value,
    })"""),

    ("""      <div class="field">
        <label>分類</label>
        <CategoryPicker
          v-model="formCategoryId"
          :type="formType"
          :categories="categories"
          @created="handleCategoryCreated"
        />
      </div>
      <div class="field">
        <label for="tx-amount">金額</label>""",
     """      <div class="field">
        <label>分類</label>
        <CategoryPicker
          v-model="formCategoryId"
          :type="formType"
          :categories="categories"
          @created="handleCategoryCreated"
        />
      </div>
      <div class="field">
        <label>消費品項（選填）</label>
        <TagPicker v-model="formTagIds" :tags="tags" @created="handleTagCreated" />
      </div>
      <div class="field">
        <label for="tx-amount">金額</label>"""),

    ("""            <div class="tx-card-info">
              <strong class="tx-category">{{ categoryName(tx.category_id) }}</strong>
              <span class="tx-sub">{{ accountName(tx.account_id) }}<template v-if="tx.note"> · {{ tx.note }}</template></span>
            </div>""",
     """            <div class="tx-card-info">
              <strong class="tx-category">{{ categoryName(tx.category_id) }}</strong>
              <span class="tx-sub">
                {{ accountName(tx.account_id) }}<template v-if="tx.note"> · {{ tx.note }}</template>
                <template v-if="tx.tags.length"> · {{ tx.tags.map((t) => t.name).join('、') }}</template>
              </span>
            </div>"""),

    ("""          <div style="margin-top: 8px">
            <CategoryPicker
              v-model="editCategoryId"
              :type="editType"
              :categories="categories"
              @created="handleCategoryCreated"
            />
          </div>
          <div style="display: flex; gap: 8px; margin-top: 8px">""",
     """          <div style="margin-top: 8px">
            <CategoryPicker
              v-model="editCategoryId"
              :type="editType"
              :categories="categories"
              @created="handleCategoryCreated"
            />
          </div>
          <div style="margin-top: 8px">
            <TagPicker v-model="editTagIds" :tags="tags" @created="handleTagCreated" />
          </div>
          <div style="display: flex; gap: 8px; margin-top: 8px">"""),
]

for old, new in replacements:
    if old not in content:
        raise SystemExit(f"❌ 內容不符,請人工檢查以下錨點:\n{old[:80]}...")
    content = content.replace(old, new, 1)

with open(path, "w") as f:
    f.write(content)
print("✅ TransactionList.vue 已加入消費品項功能")
PYEOF

# ========== Frontend: DashboardView.vue 加「消費品項」tab ==========
python3 << 'PYEOF'
path = "ledger-frontend/src/views/DashboardView.vue"
with open(path) as f:
    content = f.read()

old_import = """import DateRangePicker from '@/components/DateRangePicker.vue'
import ExcelImportExport from '@/components/ExcelImportExport.vue'"""
new_import = """import DateRangePicker from '@/components/DateRangePicker.vue'
import ExcelImportExport from '@/components/ExcelImportExport.vue'
import TagList from '@/components/TagList.vue'"""
if old_import not in content:
    raise SystemExit("❌ import 錨點不符")
content = content.replace(old_import, new_import, 1)

old_type = "type Tab = 'stats' | 'transactions' | 'accounts' | 'categories' | 'transfer'"
new_type = "type Tab = 'stats' | 'transactions' | 'accounts' | 'categories' | 'transfer' | 'tags'"
if old_type not in content:
    raise SystemExit("❌ Tab type 錨點不符")
content = content.replace(old_type, new_type, 1)

old_nav = """      <button :class="{ active: activeTab === 'categories' }" @click="activeTab = 'categories'">分類</button>
      <button :class="{ active: activeTab === 'transfer' }" @click="activeTab = 'transfer'">匯入/匯出</button>
    </nav>"""
new_nav = """      <button :class="{ active: activeTab === 'categories' }" @click="activeTab = 'categories'">分類</button>
      <button :class="{ active: activeTab === 'tags' }" @click="activeTab = 'tags'">消費品項</button>
      <button :class="{ active: activeTab === 'transfer' }" @click="activeTab = 'transfer'">匯入/匯出</button>
    </nav>"""
if old_nav not in content:
    raise SystemExit("❌ nav 錨點不符")
content = content.replace(old_nav, new_nav, 1)

old_section = """      <CategoryList v-else-if="activeTab === 'categories'" @changed="handleReferenceDataChanged" />
      <ExcelImportExport v-else-if="activeTab === 'transfer'" />
    </section>"""
new_section = """      <CategoryList v-else-if="activeTab === 'categories'" @changed="handleReferenceDataChanged" />
      <TagList v-else-if="activeTab === 'tags'" @changed="handleReferenceDataChanged" />
      <ExcelImportExport v-else-if="activeTab === 'transfer'" />
    </section>"""
if old_section not in content:
    raise SystemExit("❌ section 錨點不符")
content = content.replace(old_section, new_section, 1)

with open(path, "w") as f:
    f.write(content)
print("✅ DashboardView.vue 已加入「消費品項」tab")
PYEOF

git add -A
git commit -m "feat: 新增消費品項功能(重用 Tag/TransactionTag),交易可掛多個消費品項,不影響既有分類樹結構"
echo "✅ 已 commit,請確認 tags/transaction_tags 資料表已存在後,再 push + deploy"