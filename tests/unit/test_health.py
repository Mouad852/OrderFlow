from unittest.mock import MagicMock

from fastapi.testclient import TestClient
from sqlalchemy.exc import SQLAlchemyError

from app.main import app


def test_health_returns_ok() -> None:
    response = TestClient(app).get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


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
