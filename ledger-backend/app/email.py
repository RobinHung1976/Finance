import logging
import smtplib
from email.message import EmailMessage

from app.config import settings

logger = logging.getLogger(__name__)


def send_email(to_address: str, subject: str, body: str) -> bool:
    """透過本機 Postfix relay 寄信。失敗時記 log,不拋例外(避免洩漏帳號是否存在的時序差異)。"""
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = settings.smtp_from
    msg["To"] = to_address
    msg.set_content(body)

    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as smtp:
            smtp.send_message(msg)
        return True
    except Exception:
        logger.exception("寄送 email 失敗: to=%s", to_address)
        return False
