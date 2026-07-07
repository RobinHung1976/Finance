from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.audit import log_action
from app.deps import get_current_user
from app.models import Category, Transaction, User
from app.schemas_ledger import CategoryCreate, CategoryOut, CategoryUpdate

router = APIRouter(prefix="/categories", tags=["categories"])


def _get_owned_category(category_id: str, user: User, db: Session) -> Category:
    category = db.get(Category, category_id)
    if category is None or category.household_id != user.household_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="分類不存在")
    return category


@router.get("", response_model=list[CategoryOut])
def list_categories(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """回傳扁平列表(含 parent_id),前端自行組樹狀結構或用 Recursive CTE 查詢皆可。"""
    return db.query(Category).filter(Category.household_id == current_user.household_id).all()


@router.post("", response_model=CategoryOut, status_code=status.HTTP_201_CREATED)
def create_category(
    payload: CategoryCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if payload.parent_id is not None:
        _get_owned_category(payload.parent_id, current_user, db)  # 驗證 parent 屬於同家庭

    category = Category(household_id=current_user.household_id, **payload.model_dump())
    db.add(category)
    db.flush()
    log_action(db, user=current_user, action="create", resource_type="category",
               resource_id=category.id, detail=f"新增分類：{category.name}")
    db.commit()
    db.refresh(category)
    return category


@router.patch("/{category_id}", response_model=CategoryOut)
def update_category(
    category_id: str,
    payload: CategoryUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    category = _get_owned_category(category_id, current_user, db)

    update_data = payload.model_dump(exclude_unset=True)
    if "parent_id" in update_data and update_data["parent_id"] == category_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="分類不能設定自己為父分類")

    for field, value in update_data.items():
        setattr(category, field, value)
    log_action(db, user=current_user, action="update", resource_type="category",
               resource_id=category.id, detail=f"修改分類：{category.name}")
    db.commit()
    db.refresh(category)
    return category


@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_category(
    category_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    category = _get_owned_category(category_id, current_user, db)

    has_children = db.query(Category).filter(Category.parent_id == category_id).first() is not None
    if has_children:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="請先刪除或移動子分類")

    in_use = db.query(Transaction).filter(Transaction.category_id == category_id).first() is not None
    if in_use:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="此分類已有交易紀錄使用中,無法刪除")

    log_action(db, user=current_user, action="delete", resource_type="category",
               resource_id=category.id, detail=f"刪除分類：{category.name}")
    db.delete(category)
    db.commit()
