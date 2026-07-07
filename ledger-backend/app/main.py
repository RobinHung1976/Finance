from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers import auth, households, accounts, categories, transactions, transactions_transfer, stats

app = FastAPI(title="家庭理財網站 API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(households.router)
app.include_router(accounts.router)
app.include_router(categories.router)
app.include_router(transactions.router)
app.include_router(transactions_transfer.router)
app.include_router(stats.router)


@app.get("/health")
def health_check():
    return {"status": "ok"}
