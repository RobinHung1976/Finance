from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.audit import log_action
from app.email import send_email
from app.config import settings
from app.models import Household, PasswordResetToken, User, UserRole
from app.schemas import (
    ForgotPasswordRequest,
    HouseholdRegister,
    LoginRequest,
    ResetPasswordRequest,
    TokenResponse,
)
from app.security import (
    create_access_token,
    generate_reset_token,
    hash_password,
    hash_reset_token,
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register_household(payload: HouseholdRegister, db: Session = Depends(get_db)):
    """建立新家庭帳本 + 第一個管理者帳號。"""
    household = Household(name=payload.household_name)
    db.add(household)
    db.flush()  # 取得 household.id

    admin_user = User(
        household_id=household.id,
        name=payload.admin_name,
        username=payload.admin_username,
        email=payload.admin_email.lower(),
        password_hash=hash_password(payload.admin_password),
        role=UserRole.admin,
    )
    db.add(admin_user)

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="帳號已被使用")

    db.refresh(admin_user)
    token = create_access_token(
        {"sub": admin_user.id, "household_id": household.id, "role": admin_user.role.value}
    )
    return TokenResponse(access_token=token)


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == payload.username).first()
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="帳號或密碼錯誤",
            headers={"WWW-Authenticate": "Bearer"},
        )
    log_action(db, user=user, action="login", resource_type="user", resource_id=user.id)
    db.commit()
    token = create_access_token(
        {"sub": user.id, "household_id": user.household_id, "role": user.role.value}
    )
    return TokenResponse(access_token=token)


RESET_TOKEN_TTL_MINUTES = 30


@router.post("/forgot-password", status_code=status.HTTP_200_OK)
def forgot_password(
    payload: ForgotPasswordRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    """
    寄送重設密碼信。email 可能對應多個帳號(家庭共用信箱),
    信中列出所有相關帳號,各自附獨立重設連結。

    無論 email 是否存在都回傳相同訊息,避免帳號列舉攻擊。
    """
    generic_response = {"message": "若該 email 有對應帳號，重設信件已寄出"}

    users = db.query(User).filter(User.email == payload.email.lower()).all()
    if not users:
        return generic_response

    reset_links: list[str] = []
    for user in users:
        raw_token, token_hash = generate_reset_token()
        reset_record = PasswordResetToken(
            user_id=user.id,
            token_hash=token_hash,
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=RESET_TOKEN_TTL_MINUTES),
        )
        db.add(reset_record)
        reset_links.append(f"帳號「{user.username}」：{settings.frontend_base_url}/reset-password?token={raw_token}")

    db.commit()

    body = (
        "您收到這封信是因為有人為以下帳號申請重設密碼：\n\n"
        + "\n".join(reset_links)
        + f"\n\n連結將於 {RESET_TOKEN_TTL_MINUTES} 分鐘後失效。若非本人操作，請忽略此信。"
    )
    background_tasks.add_task(send_email, payload.email, "重設密碼通知", body)

    return generic_response


@router.post("/reset-password", status_code=status.HTTP_200_OK)
def reset_password(payload: ResetPasswordRequest, db: Session = Depends(get_db)):
    token_hash = hash_reset_token(payload.token)
    reset_record = (
        db.query(PasswordResetToken)
        .filter(PasswordResetToken.token_hash == token_hash)
        .first()
    )

    now = datetime.now(timezone.utc)
    if (
        reset_record is None
        or reset_record.used_at is not None
        or reset_record.expires_at.replace(tzinfo=timezone.utc) < now
    ):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="重設連結無效或已過期")

    user = db.get(User, reset_record.user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="重設連結無效或已過期")

    user.password_hash = hash_password(payload.new_password)
    reset_record.used_at = now
    db.commit()

    return {"message": "密碼已重設，請重新登入"}
