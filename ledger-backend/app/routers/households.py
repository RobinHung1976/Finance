from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.audit import log_action
from app.database import get_db
from app.deps import get_current_user, require_admin
from app.models import AuditLog, User, UserRole
from app.schemas import AuditLogPage, HouseholdOut, HouseholdUpdate, UserCreate, UserOut
from app.security import hash_password

router = APIRouter(prefix="/households", tags=["households"])


@router.get("/me", response_model=HouseholdOut)
def get_my_household(current_user: User = Depends(get_current_user)):
    return current_user.household


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
    return household


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
