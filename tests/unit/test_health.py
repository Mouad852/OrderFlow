from unittest.mock import MagicMock

from fastapi.testclient import TestClient
from sqlalchemy.exc import SQLAlchemyError

from app.core.config import get_settings
from app.main import app


def test_health_returns_ok() -> None:
    response = TestClient(app).get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_info_returns_deployment_identity(monkeypatch) -> None:
    monkeypatch.setenv(
        "DATABASE_URL",
        "postgresql+psycopg://orderflow:orderflow@localhost:5432/orderflow",
    )
    monkeypatch.setenv("ENVIRONMENT", "test")
    monkeypatch.setenv("LOG_LEVEL", "INFO")
    monkeypatch.setenv("BUILD_SHA", "abc123")
    get_settings.cache_clear()

    response = TestClient(app).get("/info")

    assert response.status_code == 200
    assert response.json() == {
        "service": "orderflow-api",
        "environment": "test",
        "build_sha": "abc123",
    }
    get_settings.cache_clear()


def test_ready_returns_ready_when_database_is_reachable(monkeypatch) -> None:
    engine = MagicMock()
    monkeypatch.setattr("app.main.get_engine", lambda: engine)

    response = TestClient(app).get("/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


def test_ready_returns_service_unavailable_when_database_is_down(monkeypatch) -> None:
    engine = MagicMock()
    engine.connect.side_effect = SQLAlchemyError("database is down")
    monkeypatch.setattr("app.main.get_engine", lambda: engine)

    response = TestClient(app).get("/ready")

    assert response.status_code == 503
    assert response.json() == {"detail": "Database unavailable"}
