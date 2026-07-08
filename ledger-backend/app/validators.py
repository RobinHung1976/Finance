import re

# 白名單規則:只允許中文(CJK)、英文字母、數字、空白、底線、連字號
_ALLOWED_HOUSEHOLD_NAME_PATTERN = re.compile(r'^[\u4e00-\u9fffA-Za-z0-9 _-]+$')
_MAX_HOUSEHOLD_NAME_LENGTH = 50


def validate_household_name(v: str) -> str:
    """
    帳本名稱防呆規則:
    - 前後空白自動去除
    - 不可為空
    - 長度上限 50 字
    - 僅允許:中文、英文字母、數字、空白、底線(_)、連字號(-)
    """
    v = v.strip()
    if not v:
        raise ValueError("帳本名稱不可為空")
    if len(v) > _MAX_HOUSEHOLD_NAME_LENGTH:
        raise ValueError(f"帳本名稱長度不可超過 {_MAX_HOUSEHOLD_NAME_LENGTH} 字")
    if not _ALLOWED_HOUSEHOLD_NAME_PATTERN.match(v):
        raise ValueError("帳本名稱僅能包含中文、英文、數字、空白、底線(_)、連字號(-)")
    return v
