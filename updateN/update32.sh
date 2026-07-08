#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
FRONTEND=ledger-frontend
[ -d "$BACKEND" ] && [ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

# ---------- 前置檢查:確認 TransactionTag 欄位名稱 ----------
echo "檢查 TransactionTag 欄位名稱(應包含 tag_id / transaction_id)..."
cd "$BACKEND"
[ -d venv ] || { echo "找不到 venv,請確認在正確目錄執行"; exit 1; }
source venv/bin/activate
python3 -c "
from app.models import TransactionTag
cols = TransactionTag.__table__.columns.keys()
print('欄位:', cols)
assert 'tag_id' in cols, '❌ 找不到 tag_id 欄位,請人工確認 models.py 實際命名並修改 tags.py'
assert 'transaction_id' in cols, '❌ 找不到 transaction_id 欄位,請人工確認 models.py 實際命名並修改 tags.py'
print('✅ 欄位名稱符合預期')
"
deactivate
cd ..

# ---------- schemas_tag.py:完整覆寫(新增 usage_count) ----------
cat > "$BACKEND/app/schemas_tag.py" << 'EOF'
from pydantic import BaseModel, Field


class TagCreate(BaseModel):
    name: str = Field(min_length=1, max_length=50)


class TagUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=50)


class TagOut(BaseModel):
    id: str
    name: str
    usage_count: int = 0

    class Config:
        from_attributes = True
EOF
echo "✅ schemas_tag.py 已覆寫"

# ---------- tags.py:完整覆寫(list 加 join 統計筆數、排序;create/update 補 usage_count) ----------
cat > "$BACKEND/app/routers/tags.py" << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models import Tag, TransactionTag, User
from app.schemas_tag import TagCreate, TagUpdate, TagOut

router = APIRouter(prefix="/tags", tags=["tags"])


def _usage_count(db: Session, tag_id: str) -> int:
    return (
        db.query(func.count(TransactionTag.transaction_id))
        .filter(TransactionTag.tag_id == tag_id)
        .scalar()
        or 0
    )


@router.get("", response_model=list[TagOut])
def list_tags(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(Tag, func.count(TransactionTag.transaction_id).label("usage_count"))
        .outerjoin(TransactionTag, TransactionTag.tag_id == Tag.id)
        .filter(Tag.household_id == current_user.household_id)
        .group_by(Tag.id)
        .order_by(func.count(TransactionTag.transaction_id).desc(), Tag.name)
        .all()
    )
    return [TagOut(id=tag.id, name=tag.name, usage_count=usage_count) for tag, usage_count in rows]


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
    return TagOut(id=tag.id, name=tag.name, usage_count=0)


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
    return TagOut(id=tag.id, name=tag.name, usage_count=_usage_count(db, tag.id))


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
echo "✅ tags.py 已覆寫"

# ---------- types/ledger.ts:精確字串替換(只動 TagOut interface) ----------
python3 << 'PYEOF'
path = "ledger-frontend/src/types/ledger.ts"
with open(path) as f:
    content = f.read()

old = """export interface TagOut {
  id: string
  name: string
}"""
new = """export interface TagOut {
  id: string
  name: string
  usage_count: number
}"""

if old not in content:
    raise SystemExit("❌ TagOut interface 內容不符,請人工檢查 types/ledger.ts 目前內容")
content = content.replace(old, new)

with open(path, "w") as f:
    f.write(content)
print("✅ types/ledger.ts 已修正")
PYEOF

# ---------- TagList.vue:完整覆寫(搜尋框 + 使用筆數顯示 + 刪除確認文字區分) ----------
cat > "$FRONTEND/src/components/TagList.vue" << 'EOF'
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { fetchTags, createTag, updateTag, deleteTag } from '@/api/ledger'
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
const searchQuery = ref('')

const editingId = ref<string | null>(null)
const editName = ref('')
const editError = ref('')
const isSavingEdit = ref(false)

const filteredTags = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return tags.value
  return tags.value.filter((t) => t.name.toLowerCase().includes(q))
})

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

function isDuplicateName(name: string, excludeId?: string): boolean {
  const lower = name.trim().toLowerCase()
  return tags.value.some((t) => t.id !== excludeId && t.name.trim().toLowerCase() === lower)
}

async function handleCreate() {
  createError.value = ''
  const trimmedName = newTagName.value.trim()
  if (!trimmedName) {
    createError.value = '請輸入名稱'
    return
  }
  if (isDuplicateName(trimmedName)) {
    createError.value = '此消費品項名稱已存在,請直接使用現有品項'
    return
  }
  isCreating.value = true
  try {
    const created = await createTag({ name: trimmedName })
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

function startEdit(tag: TagOut) {
  editingId.value = tag.id
  editName.value = tag.name
  editError.value = ''
}

function cancelEdit() {
  editingId.value = null
  editError.value = ''
}

async function saveEdit(id: string) {
  editError.value = ''
  const trimmedName = editName.value.trim()
  if (!trimmedName) {
    editError.value = '請輸入名稱'
    return
  }
  if (isDuplicateName(trimmedName, id)) {
    editError.value = '此消費品項名稱已存在,請直接使用現有品項'
    return
  }
  isSavingEdit.value = true
  try {
    const updated = await updateTag(id, { name: trimmedName })
    const idx = tags.value.findIndex((t) => t.id === id)
    if (idx !== -1) tags.value[idx] = updated
    editingId.value = null
    emit('changed')
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    editError.value = axiosErr.response?.data?.detail ?? '更新失敗'
  } finally {
    isSavingEdit.value = false
  }
}

async function handleDelete(tag: TagOut) {
  const message =
    tag.usage_count > 0
      ? `此消費品項已掛用於 ${tag.usage_count} 筆交易,刪除後這些交易將移除此標籤,交易本身不受影響。確定刪除？`
      : '確定刪除此消費品項？'
  if (!confirm(message)) return
  try {
    await deleteTag(tag.id)
    tags.value = tags.value.filter((t) => t.id !== tag.id)
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

    <input
      v-model="searchQuery"
      type="text"
      placeholder="搜尋消費品項"
      style="width: 100%; padding: 8px 10px; margin: 12px 0; border: 1px solid var(--color-border); border-radius: 6px; box-sizing: border-box"
    />

    <div v-if="loadError" class="error-banner">{{ loadError }}</div>
    <p v-if="!isLoading && tags.length === 0" style="color: #6b7a74; font-size: 13px">尚未建立任何消費品項。</p>
    <p v-if="!isLoading && tags.length > 0 && filteredTags.length === 0" style="color: #6b7a74; font-size: 13px">
      找不到符合「{{ searchQuery }}」的消費品項。
    </p>

    <div v-for="t in filteredTags" :key="t.id" class="row-card">
      <template v-if="editingId !== t.id">
        <span :style="{ color: t.usage_count === 0 ? '#a3aca7' : 'inherit' }">
          {{ t.name }} <span style="font-size: 12px">({{ t.usage_count }})</span>
        </span>
        <div style="display: flex; gap: 12px">
          <button class="btn-text" @click="startEdit(t)">改名</button>
          <button class="btn-text-danger" @click="handleDelete(t)">刪除</button>
        </div>
      </template>
      <form v-else style="display: flex; gap: 8px; align-items: center; width: 100%" @submit.prevent="saveEdit(t.id)">
        <input
          v-model="editName"
          type="text"
          maxlength="50"
          style="flex: 1; padding: 6px 10px; border: 1px solid var(--color-border); border-radius: 6px"
        />
        <button class="btn-primary" type="submit" style="width: auto; padding: 6px 14px" :disabled="isSavingEdit">
          {{ isSavingEdit ? '儲存中…' : '儲存' }}
        </button>
        <button type="button" class="btn-text" @click="cancelEdit">取消</button>
      </form>
      <div v-if="editingId === t.id && editError" class="error-banner" style="width: 100%; margin-top: 4px">
        {{ editError }}
      </div>
    </div>
  </div>
</template>
EOF
echo "✅ TagList.vue 已覆寫"

echo "✅ 檔案已寫入完成"
git add -A
git commit -m "feat: 消費品項頁新增搜尋、使用筆數顯示、依筆數排序，刪除確認文字依筆數區分"
echo "✅ 已 commit,請執行 'git push origin main',再到 server 跑 ./deploy.sh"
