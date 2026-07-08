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
