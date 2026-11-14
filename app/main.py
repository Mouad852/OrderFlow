from fastapi import FastAPI, HTTPException, status
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.api.orders import router as orders_router
from app.database.session import get_engine

app = FastAPI(title="OrderFlow API", version="0.1.0")
app.include_router(orders_router)


@app.get("/health", tags=["Operations"])
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/ready", tags=["Operations"])
def ready() -> dict[str, str]:
    try:
        with get_engine().connect() as connection:
            connection.execute(text("SELECT 1"))
    except SQLAlchemyError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database unavailable",
        ) from error

    return {"status": "ready"}
