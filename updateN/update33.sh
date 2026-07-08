#!/usr/bin/env bash
set -euo pipefail

BACKEND=ledger-backend
FRONTEND=ledger-frontend
[ -d "$BACKEND" ] && [ -d "$FRONTEND" ] || { echo "請在 repo 根目錄執行"; exit 1; }

# ---------- schemas_tag.py:完整覆寫(新增 last_used_date) ----------
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
    last_used_date: str | None = None

    class Config:
        from_attributes = True
EOF
echo "✅ schemas_tag.py 已覆寫"

# ---------- tags.py:完整覆寫(list/update 一併回傳 last_used_date) ----------
cat > "$BACKEND/app/routers/tags.py" << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models import Tag, Transaction, TransactionTag, User
from app.schemas_tag import TagCreate, TagUpdate, TagOut

router = APIRouter(prefix="/tags", tags=["tags"])


def _tag_stats(db: Session, tag_id: str) -> tuple[int, str | None]:
    """回傳 (usage_count, last_used_date) — last_used_date 取該品項所有交易 date 的最大值。"""
    count, last_date = (
        db.query(func.count(TransactionTag.transaction_id), func.max(Transaction.date))
        .select_from(TransactionTag)
        .join(Transaction, Transaction.id == TransactionTag.transaction_id)
        .filter(TransactionTag.tag_id == tag_id)
        .one()
    )
    return count or 0, last_date.isoformat() if last_date else None


@router.get("", response_model=list[TagOut])
def list_tags(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(
            Tag,
            func.count(TransactionTag.transaction_id).label("usage_count"),
            func.max(Transaction.date).label("last_used_date"),
        )
        .outerjoin(TransactionTag, TransactionTag.tag_id == Tag.id)
        .outerjoin(Transaction, Transaction.id == TransactionTag.transaction_id)
        .filter(Tag.household_id == current_user.household_id)
        .group_by(Tag.id)
        .order_by(func.count(TransactionTag.transaction_id).desc(), Tag.name)
        .all()
    )
    return [
        TagOut(
            id=tag.id,
            name=tag.name,
            usage_count=usage_count,
            last_used_date=last_used_date.isoformat() if last_used_date else None,
        )
        for tag, usage_count, last_used_date in rows
    ]


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
    return TagOut(id=tag.id, name=tag.name, usage_count=0, last_used_date=None)


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
    usage_count, last_used_date = _tag_stats(db, tag.id)
    return TagOut(id=tag.id, name=tag.name, usage_count=usage_count, last_used_date=last_used_date)


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

# ---------- types/ledger.ts:精確字串替換(TagOut interface 補 last_used_date) ----------
python3 << 'PYEOF'
path = "ledger-frontend/src/types/ledger.ts"
with open(path) as f:
    content = f.read()

old = """export interface TagOut {
  id: string
  name: string
  usage_count: number
}"""
new = """export interface TagOut {
  id: string
  name: string
  usage_count: number
  last_used_date: string | null
}"""

if old not in content:
    raise SystemExit("❌ TagOut interface 內容不符,請人工檢查 types/ledger.ts 目前內容(可能 update32.sh 尚未套用)")
content = content.replace(old, new)

with open(path, "w") as f:
    f.write(content)
print("✅ types/ledger.ts 已修正")
PYEOF

# ---------- TagPicker.vue:完整覆寫(新增「最近使用」分區) ----------
cat > "$FRONTEND/src/components/TagPicker.vue" << 'EOF'
<script setup lang="ts">
import { ref, computed } from 'vue'
import { createTag } from '@/api/ledger'
import type { TagOut } from '@/types/ledger'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const RECENT_LIMIT = 8

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

const isSearching = computed(() => searchQuery.value.trim().length > 0)

const filteredTags = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return props.tags
  return props.tags.filter((t) => t.name.toLowerCase().includes(q))
})

// 最近使用:依 last_used_date 由新到舊排序,取前 N 個(無交易紀錄的品項不列入)
const recentTags = computed(() => {
  return props.tags
    .filter((t) => t.last_used_date)
    .sort((a, b) => (b.last_used_date! < a.last_used_date! ? -1 : 1))
    .slice(0, RECENT_LIMIT)
})

const otherTags = computed(() => {
  const recentIds = new Set(recentTags.value.map((t) => t.id))
  return props.tags.filter((t) => !recentIds.has(t.id))
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
  const trimmedName = newTagName.value.trim()
  if (!trimmedName) {
    createError.value = '請輸入消費品項名稱'
    return
  }
  const isDuplicate = props.tags.some((t) => t.name.trim().toLowerCase() === trimmedName.toLowerCase())
  if (isDuplicate) {
    createError.value = '此消費品項名稱已存在,請直接選擇現有品項'
    return
  }
  isCreating.value = true
  try {
    const created = await createTag({ name: trimmedName })
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

    <template v-if="!isSearching">
      <div v-if="recentTags.length" class="tag-section-label">最近使用</div>
      <div v-if="recentTags.length" class="tag-grid">
        <button
          v-for="t in recentTags"
          :key="t.id"
          type="button"
          class="tag-btn"
          :class="{ selected: isSelected(t.id) }"
          @click="toggleTag(t.id)"
        >
          {{ t.name }}
        </button>
      </div>

      <div v-if="recentTags.length && otherTags.length" class="tag-section-label">全部品項</div>
      <div class="tag-grid">
        <button
          v-for="t in otherTags"
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
    </template>

    <template v-else>
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
    </template>

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
.tag-section-label {
  font-size: 11px;
  color: #8a948e;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  margin: 8px 0 4px;
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
echo "✅ TagPicker.vue 已覆寫"

echo "✅ 檔案已寫入完成"
git add -A
git commit -m "feat: 消費品項選擇器新增「最近使用」分區,依交易日期排序"
echo "✅ 已 commit,請執行 'git push origin main',再到 server 跑 ./deploy.sh"
