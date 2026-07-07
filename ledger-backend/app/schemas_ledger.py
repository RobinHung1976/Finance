from datetime import date as date_type, datetime

from pydantic import BaseModel, Field, field_validator

from app.models import AccountType, EntryType


# ---------- Account ----------
class AccountCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    type: AccountType
    balance: float = 0
    is_default_expense: bool = False


class AccountUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    type: AccountType | None = None
    balance: float | None = None
    is_default_expense: bool | None = None


class AccountOut(BaseModel):
    id: str
    name: str
    type: AccountType
    balance: float
    is_default_expense: bool

    class Config:
        from_attributes = True


# ---------- Category ----------
class CategoryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    parent_id: str | None = None
    type: EntryType


class CategoryUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    parent_id: str | None = None


class CategoryOut(BaseModel):
    id: str
    name: str
    parent_id: str | None
    type: EntryType

    class Config:
        from_attributes = True


# ---------- Transaction ----------
class TransactionCreate(BaseModel):
    account_id: str
    category_id: str
    amount: float = Field(gt=0)
    type: EntryType
    date: date_type
    note: str | None = Field(default=None, max_length=500)

    @field_validator("amount")
    @classmethod
    def amount_must_be_positive(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("金額必須大於 0")
        return round(v, 2)


class TransactionUpdate(BaseModel):
    account_id: str | None = None
    category_id: str | None = None
    amount: float | None = Field(default=None, gt=0)
    type: EntryType | None = None
    date: date_type | None = None
    note: str | None = Field(default=None, max_length=500)


class TransactionOut(BaseModel):
    id: str
    account_id: str
    category_id: str
    amount: float
    type: EntryType
    date: date_type
    note: str | None
    user_id: str | None

    class Config:
        from_attributes = True


# ---------- Stats: Monthly Trend ----------
class MonthlySummary(BaseModel):
    month: str
    income: float
    expense: float
    balance: float


class MonthlyTrendOut(BaseModel):
    months: list[MonthlySummary]
    total_income: float
    total_expense: float
    total_balance: float


# ---------- Stats: Category Breakdown (A3, 含下鑽) ----------
class CategoryBreakdownItem(BaseModel):
    category_id: str
    category_name: str
    amount: float
    percentage: float
    has_children: bool


class CategoryBreakdownOut(BaseModel):
    type: EntryType
    total: float
    items: list[CategoryBreakdownItem]
