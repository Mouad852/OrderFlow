from unittest.mock import Mock

from fastapi.testclient import TestClient

from app.core import auth
from app.core.config import get_settings
from app.main import app


def configure_entra_auth(monkeypatch) -> None:
    monkeypatch.setenv(
        "DATABASE_URL",
        "postgresql+psycopg://orderflow:orderflow@localhost:5432/orderflow",
    )
    monkeypatch.setenv("ENVIRONMENT", "test")
    monkeypatch.setenv("LOG_LEVEL", "INFO")

    monkeypatch.setenv("AUTH_ENABLED", "true")
    monkeypatch.setenv("ENTRA_TENANT_ID", "b0b08c91-f921-486d-9d9f-5aff2b86160a")
    monkeypatch.setenv(
        "ENTRA_API_CLIENT_ID",
        "c098978c-a5c8-4864-8ad7-ec5b2a1f74b8",
    )
    get_settings.cache_clear()


def test_orders_require_a_bearer_token_when_auth_is_enabled(monkeypatch) -> None:
    configure_entra_auth(monkeypatch)

    try:
        response = TestClient(app).get("/orders")

        assert response.status_code == 401
        assert response.headers["www-authenticate"] == "Bearer"
    finally:
        get_settings.cache_clear()


def test_orders_reject_a_token_without_the_required_role(monkeypatch) -> None:
    configure_entra_auth(monkeypatch)

    signing_key = Mock()
    signing_key.key = "unused"

    monkeypatch.setattr(
        auth,
        "get_jwks_client",
        lambda _: Mock(get_signing_key_from_jwt=lambda _: signing_key),
    )
    monkeypatch.setattr(auth.jwt, "decode", lambda *args, **kwargs: {"roles": []})

    try:
        response = TestClient(app).get(
            "/orders",
            headers={"Authorization": "Bearer test-token"},
        )

        assert response.status_code == 403
    finally:
        get_settings.cache_clear()
