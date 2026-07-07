from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.deps import get_current_user, get_db
from app.schemas_import_export import ImportPreviewResponse, ImportCommitResponse
from app.services.excel_transfer import process_import, build_export_workbook

router = APIRouter(prefix="/transactions", tags=["import-export"])

MAX_IMPORT_SIZE = 10 * 1024 * 1024  # 10MB


@router.post("/import/preview", response_model=ImportPreviewResponse)
async def import_preview(
    file: UploadFile = File(...),
    account_id: str = Form(...),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    content = await file.read()
    if len(content) > MAX_IMPORT_SIZE:
        raise HTTPException(413, "檔案過大")
    try:
        result = process_import(db, current_user.household_id, current_user.id, account_id, content, dry_run=True)
    except Exception as e:
        raise HTTPException(400, f"檔案解析失敗:{e}")
    return ImportPreviewResponse(**result)


@router.post("/import/commit", response_model=ImportCommitResponse)
async def import_commit(
    file: UploadFile = File(...),
    account_id: str = Form(...),
    force_rows: str = Form(""),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    content = await file.read()
    if len(content) > MAX_IMPORT_SIZE:
        raise HTTPException(413, "檔案過大")
    force_set = {r for r in force_rows.split(",") if r}
    result = process_import(
        db, current_user.household_id, current_user.id, account_id, content,
        dry_run=False, force_rows=force_set,
    )
    return ImportCommitResponse(
        imported=result["imported"],
        skipped_errors=result["skipped_errors"],
        skipped_duplicates=result["skipped_duplicates"],
        created_categories=result["created_categories"],
    )


@router.get("/export/excel")
async def export_excel(
    year: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    buf = build_export_workbook(db, current_user.household_id, year)
    filename = f"{year}-記帳表.xlsx"
    return StreamingResponse(
        buf,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
