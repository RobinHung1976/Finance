from datetime import datetime

from pydantic import BaseModel, EmailStr, Field

from app.models import UserRole

# 帳號規則:英數、底線、句點、連字號,3-50字元
USERNAME_PATTERN = r"^[a-zA-Z0-9_.-]{3,50}$"


class HouseholdRegister(BaseModel):
    household_name: str = Field(min_length=1, max_length=100)
    admin_name: str = Field(min_length=1, max_length=100)
    admin_username: str = Field(pattern=USERNAME_PATTERN)
    admin_email: EmailStr
    admin_password: str = Field(min_length=8, max_length=128)


class UserCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    username: str = Field(pattern=USERNAME_PATTERN)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    role: UserRole = UserRole.member


class UserOut(BaseModel):
    id: str
    name: str
    username: str
    email: EmailStr
    role: UserRole
    created_at: datetime

    class Config:
        from_attributes = True


class HouseholdOut(BaseModel):
    id: str
    name: str
    created_at: datetime

    class Config:
        from_attributes = True


class LoginRequest(BaseModel):
    username: str
    password: str


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str = Field(min_length=8, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
