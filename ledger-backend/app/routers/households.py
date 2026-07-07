from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user, require_admin
from app.models import User
from app.schemas import HouseholdOut, UserCreate, UserOut
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
    """僅管理者可新增家庭成員。"""
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
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="帳號已被使用")
    db.refresh(new_user)
    return new_user
