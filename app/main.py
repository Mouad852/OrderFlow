# ruff: noqa: E402
import fastapi

from app.core.telemetry import configure_telemetry

configure_telemetry()

from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.api.orders import router as orders_router
from app.core.config import get_settings
from app.database.session import get_engine

app = fastapi.FastAPI(title="OrderFlow API", version="0.1.0")
app.include_router(orders_router)


@app.get("/health", tags=["Operations"])
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/info", tags=["Operations"])
def info() -> dict[str, str]:
    settings = get_settings()

    return {
        "service": "orderflow-api",
        "environment": settings.environment,
        "build_sha": settings.build_sha,
    }


@app.get("/ready", tags=["Operations"])
def ready() -> dict[str, str]:
    try:
        with get_engine().connect() as connection:
            connection.execute(text("SELECT 1"))
    except SQLAlchemyError as error:
        raise fastapi.HTTPException(
            status_code=fastapi.status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database unavailable",
        ) from error

    return {"status": "ready"}
