from sqlalchemy.orm import Session
from app.models import AuditLog, User


def log_action(
    db: Session,
    *,
    user: User,
    action: str,
    resource_type: str,
    resource_id: str | None = None,
    detail: str | None = None,
) -> None:
    """僅 db.add,不 commit — 與呼叫端業務操作同一交易,失敗一併 rollback。"""
    db.add(
        AuditLog(
            household_id=user.household_id,
            user_id=user.id,
            actor_name=user.name,
            action=action,
            resource_type=resource_type,
            resource_id=resource_id,
            detail=detail,
        )
    )
