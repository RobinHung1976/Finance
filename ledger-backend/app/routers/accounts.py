from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.audit import log_action
from app.deps import get_current_user, require_admin
from app.models import Account, Category, EntryType, Transaction, User, UserRole
from app.schemas_ledger import AccountCreate, AccountOut, AccountUpdate

router = APIRouter(prefix="/accounts", tags=["accounts"])


def _get_owned_account(account_id: str, user: User, db: Session) -> Account:
    account = db.get(Account, account_id)
    if account is None or account.household_id != user.household_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="帳戶不存在")
    return account


def _get_or_create_adjustment_category(household_id: str, entry_type: EntryType, db: Session) -> Category:
    """帳戶餘額手動調整時,自動歸類到系統建立的「餘額調整」分類,使交易紀錄與帳戶餘額保持一致。"""
    category = (
        db.query(Category)
        .filter(
            Category.household_id == household_id,
            Category.name == "餘額調整",
            Category.type == entry_type,
        )
        .first()
    )
    if category is None:
        category = Category(household_id=household_id, name="餘額調整", parent_id=None, type=entry_type)
        db.add(category)
        db.flush()
    return category


@router.get("", response_model=list[AccountOut])
def list_accounts(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(Account).filter(Account.household_id == current_user.household_id).all()


@router.post("", response_model=AccountOut, status_code=status.HTTP_201_CREATED)
def create_account(
    payload: AccountCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if payload.is_default_expense:
        _clear_other_default_expense(current_user.household_id, db)

    account = Account(household_id=current_user.household_id, **payload.model_dump())
    db.add(account)
    db.flush()
    log_action(db, user=current_user, action="create", resource_type="account",
               resource_id=account.id, detail=f"新增帳戶：{account.name}")
    db.commit()
    db.refresh(account)
    return account


def _clear_other_default_expense(household_id: str, db: Session, exclude_id: str | None = None) -> None:
    """一個家庭同時只能有一個預設支出帳戶。"""
    query = db.query(Account).filter(
        Account.household_id == household_id, Account.is_default_expense.is_(True)
    )
    if exclude_id is not None:
        query = query.filter(Account.id != exclude_id)
    query.update({"is_default_expense": False})


@router.patch("/{account_id}", response_model=AccountOut)
def update_account(
    account_id: str,
    payload: AccountUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    account = _get_owned_account(account_id, current_user, db)
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

    for field, value in update_data.items():
        setattr(account, field, value)
    db.commit()
    db.refresh(account)
    return account


@router.delete("/{account_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_account(
    account_id: str,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    account = _get_owned_account(account_id, current_user, db)
    log_action(db, user=current_user, action="delete", resource_type="account",
               resource_id=account.id, detail=f"刪除帳戶：{account.name}")
    db.delete(account)
    db.commit()
