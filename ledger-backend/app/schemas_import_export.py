from datetime import date
from pydantic import BaseModel


class ImportRowPreview(BaseModel):
    sheet: str
    row: int
    date: date
    category_top: str
    item: str | None
    amount: float
    type: str  # income / expense
    will_create_category: bool
    is_duplicate: bool = False
    error: str | None = None


class ImportPreviewResponse(BaseModel):
    total_rows: int
    valid_rows: int
    new_categories: list[str]
    errors: list[str]
    rows: list[ImportRowPreview]


class ImportCommitResponse(BaseModel):
    imported: int
    skipped_errors: int
    skipped_duplicates: int
    created_categories: int
