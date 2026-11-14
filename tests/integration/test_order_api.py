from collections.abc import Generator
from uuid import uuid4

import pytest
from alembic.config import Config
from fastapi.testclient import TestClient
from testcontainers.community.postgres import PostgresContainer

from alembic import command
from app.core.config import get_settings
from app.database.session import get_engine, get_session_factory
from app.main import app

POSTGRES_IMAGE = (
    "postgres:17.2-alpine@sha256:7e5df973a74872482e320dcbdeb055e178d6f42de0558b083892c50cda833c96"
)


@pytest.fixture
def migrated_database(monkeypatch: pytest.MonkeyPatch) -> Generator[None, None, None]:
    with PostgresContainer(POSTGRES_IMAGE, driver="psycopg") as postgres:
        monkeypatch.setenv("DATABASE_URL", postgres.get_connection_url())
        monkeypatch.setenv("ENVIRONMENT", "test")
        monkeypatch.setenv("LOG_LEVEL", "INFO")

        get_settings.cache_clear()
        get_engine.cache_clear()
        get_session_factory.cache_clear()

        engine = get_engine()

        try:
            command.upgrade(Config("alembic.ini"), "head")
            yield
        finally:
            get_session_factory.cache_clear()
            engine.dispose()
            get_engine.cache_clear()
            get_settings.cache_clear()


def test_order_lifecycle_uses_real_postgres(
    migrated_database: None,
) -> None:
    client = TestClient(app)

    assert client.get("/health").json() == {"status": "ok"}
    assert client.get("/ready").json() == {"status": "ready"}

    create_response = client.post(
        "/orders",
        json={
            "customer_reference": "customer-456",
            "items": [
                {
                    "product_sku": "coffee-beans",
                    "quantity": 2,
                    "unit_price": "12.50",
                }
            ],
        },
    )

    assert create_response.status_code == 201
    created_order = create_response.json()
    order_id = created_order["id"]
    assert created_order["status"] == "PENDING"
    assert created_order["total_amount"] == "25.00"

    get_response = client.get(f"/orders/{order_id}")

    assert get_response.status_code == 200
    assert get_response.json()["customer_reference"] == "customer-456"

    list_response = client.get("/orders?limit=10&offset=0")

    assert list_response.status_code == 200
    assert len(list_response.json()["items"]) == 1

    cancel_response = client.patch(f"/orders/{order_id}/cancel")

    assert cancel_response.status_code == 200
    assert cancel_response.json()["status"] == "CANCELLED"

    repeat_cancel_response = client.patch(f"/orders/{order_id}/cancel")

    assert repeat_cancel_response.status_code == 409

    missing_response = client.get(f"/orders/{uuid4()}")

    assert missing_response.status_code == 404
