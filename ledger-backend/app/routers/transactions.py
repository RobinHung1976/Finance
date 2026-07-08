from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.audit import log_action
from app.deps import get_current_user
from app.models import Account, Category, Tag, Transaction, TransactionTag, User
from app.schemas_ledger import TransactionCreate, TransactionOut, TransactionUpdate

router = APIRouter(prefix="/transactions", tags=["transactions"])


def _get_owned_transaction(transaction_id: str, user: User, db: Session) -> Transaction:
    tx = db.get(Transaction, transaction_id)
    if tx is None or tx.household_id != user.household_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="交易紀錄不存在")
    return tx


def _validate_account_and_category(payload_dict: dict, household_id: str, db: Session) -> None:
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
        db.add(TransactionTag(transaction_id=tx_id, tag_id=tag_id))


@router.get("", response_model=list[TransactionOut])
def list_transactions(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    account_id: str | None = Query(default=None),
    category_id: str | None = Query(default=None),
    min_amount: float | None = Query(default=None, ge=0),
    max_amount: float | None = Query(default=None, ge=0),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if min_amount is not None and max_amount is not None and min_amount > max_amount:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="最低金額不能大於最高金額")

    query = db.query(Transaction).filter(Transaction.household_id == current_user.household_id)

    if start_date is not None:
        query = query.filter(Transaction.date >= start_date)
    if end_date is not None:
        query = query.filter(Transaction.date <= end_date)
    if account_id is not None:
        query = query.filter(Transaction.account_id == account_id)
    if category_id is not None:
        query = query.filter(Transaction.category_id == category_id)
    if min_amount is not None:
        query = query.filter(Transaction.amount >= min_amount)
    if max_amount is not None:
        query = query.filter(Transaction.amount <= max_amount)

    return query.order_by(Transaction.date.desc()).all()


@router.post("", response_model=TransactionOut, status_code=status.HTTP_201_CREATED)
def create_transaction(
    payload: TransactionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    payload_dict = payload.model_dump()
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

    # 更新帳戶餘額:收入加、支出減
    account = db.get(Account, payload.account_id)
    if payload.type.value == "income":
        account.balance = float(account.balance) + payload.amount
    else:
        account.balance = float(account.balance) - payload.amount

    log_action(db, user=current_user, action="create", resource_type="transaction",
               resource_id=tx.id, detail=f"新增交易：{tx.amount}")
    db.commit()
    db.refresh(tx)
    return tx


@router.patch("/{transaction_id}", response_model=TransactionOut)
def update_transaction(
    transaction_id: str,
    payload: TransactionUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    tx = _get_owned_transaction(transaction_id, current_user, db)
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

    new_account = db.get(Account, tx.account_id)
    if tx.type.value == "income":
        new_account.balance = float(new_account.balance) + float(tx.amount)
    else:
        new_account.balance = float(new_account.balance) - float(tx.amount)

    log_action(db, user=current_user, action="update", resource_type="transaction",
               resource_id=tx.id, detail=f"修改交易：{transaction_id}")
    db.commit()
    db.refresh(tx)
    return tx


@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_transaction(
    transaction_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    tx = _get_owned_transaction(transaction_id, current_user, db)

    account = db.get(Account, tx.account_id)
    if tx.type.value == "income":
        account.balance = float(account.balance) - float(tx.amount)
    else:
        account.balance = float(account.balance) + float(tx.amount)

    log_action(db, user=current_user, action="delete", resource_type="transaction",
               resource_id=tx.id, detail=f"刪除交易：{tx.amount}")
    db.delete(tx)
    db.commit()
