from datetime import UTC, datetime
from decimal import Decimal
from unittest.mock import create_autospec
from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.main import app
from app.models.orders import Order, OrderItem, OrderStatus


def build_order(status: OrderStatus = OrderStatus.PENDING) -> Order:
    now = datetime(2026, 11, 14, 14, 0, tzinfo=UTC)
    return Order(
        id=uuid4(),
        customer_reference="customer-123",
        status=status,
        total_amount=Decimal("25.00"),
        created_at=now,
        updated_at=now,
        items=[
            OrderItem(
                id=uuid4(),
                product_sku="coffee-beans",
                quantity=2,
                unit_price=Decimal("12.50"),
                line_total=Decimal("25.00"),
            )
        ],
    )


def test_create_order_returns_created_order() -> None:
    db = create_autospec(Session, instance=True)

    def set_database_values(order: object) -> None:
        now = datetime(2026, 11, 14, 14, 0, tzinfo=UTC)
        order.id = uuid4()  # type: ignore[attr-defined]
        order.created_at = now  # type: ignore[attr-defined]
        order.updated_at = now  # type: ignore[attr-defined]
        for item in order.items:  # type: ignore[attr-defined]
            item.id = uuid4()

    db.refresh.side_effect = set_database_values

    def override_get_db() -> Session:
        return db

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    try:
        response = client.post(
            "/orders",
            json={
                "customer_reference": "customer-123",
                "items": [
                    {
                        "product_sku": "coffee-beans",
                        "quantity": 2,
                        "unit_price": "12.50",
                    }
                ],
            },
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 201
    assert response.json()["customer_reference"] == "customer-123"
    assert response.json()["status"] == "PENDING"
    assert response.json()["total_amount"] == "25.00"
    assert response.json()["items"][0]["line_total"] == "25.00"
    db.add.assert_called_once()
    db.flush.assert_called_once_with()
    db.commit.assert_called_once_with()
    db.refresh.assert_called_once()


def test_create_order_rejects_invalid_request() -> None:
    db = create_autospec(Session, instance=True)

    def override_get_db() -> Session:
        return db

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    try:
        response = client.post("/orders", json={"items": []})
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 422


def test_list_orders_returns_paginated_orders() -> None:
    db = create_autospec(Session, instance=True)
    db.scalars.return_value.all.return_value = [build_order()]

    def override_get_db() -> Session:
        return db

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    try:
        response = client.get("/orders?limit=10&offset=0")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["limit"] == 10
    assert response.json()["offset"] == 0
    assert len(response.json()["items"]) == 1
    assert response.json()["items"][0]["status"] == "PENDING"


def test_list_orders_rejects_invalid_pagination() -> None:
    db = create_autospec(Session, instance=True)

    def override_get_db() -> Session:
        return db

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    try:
        response = client.get("/orders?limit=101")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 422


def test_get_order_returns_order() -> None:
    db = create_autospec(Session, instance=True)
    order = build_order()
    db.scalar.return_value = order

    def override_get_db() -> Session:
        return db

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    try:
        response = client.get(f"/orders/{order.id}")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["id"] == str(order.id)


def test_get_order_returns_not_found_for_missing_order() -> None:
    db = create_autospec(Session, instance=True)
    db.scalar.return_value = None

    def override_get_db() -> Session:
        return db

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    try:
        response = client.get(f"/orders/{uuid4()}")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 404
    assert response.json() == {"detail": "Order not found"}


def test_cancel_order_returns_cancelled_order() -> None:
    db = create_autospec(Session, instance=True)
    order = build_order()
    db.scalar.return_value = order

    def override_get_db() -> Session:
        return db

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    try:
        response = client.patch(f"/orders/{order.id}/cancel")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["status"] == "CANCELLED"
    db.commit.assert_called_once_with()


def test_cancel_order_returns_conflict_when_order_is_not_pending() -> None:
    db = create_autospec(Session, instance=True)
    order = build_order(OrderStatus.COMPLETED)
    db.scalar.return_value = order

    def override_get_db() -> Session:
        return db

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    try:
        response = client.patch(f"/orders/{order.id}/cancel")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 409
    assert response.json() == {"detail": "Order in COMPLETED state cannot be cancelled"}


def test_cancel_order_returns_not_found_for_missing_order() -> None:
    db = create_autospec(Session, instance=True)
    db.scalar.return_value = None

    def override_get_db() -> Session:
        return db

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    try:
        response = client.patch(f"/orders/{uuid4()}/cancel")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 404
    assert response.json() == {"detail": "Order not found"}
