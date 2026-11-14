from decimal import Decimal
from unittest.mock import create_autospec
from uuid import uuid4

import pytest
from sqlalchemy.orm import Session

from app.models.orders import Order, OrderStatus
from app.schemas.orders import OrderCreate, OrderItemCreate
from app.services.orders import (
    OrderNotCancellableError,
    calculate_line_total,
    calculate_order_total,
    cancel_order,
    create_order,
    get_order,
    list_orders,
)


def test_calculate_line_total() -> None:
    item = OrderItemCreate(
        product_sku="coffee-beans",
        quantity=2,
        unit_price="12.50",
    )

    assert calculate_line_total(item) == Decimal("25.00")


def test_calculate_order_total() -> None:
    items = [
        OrderItemCreate(
            product_sku="coffee-beans",
            quantity=2,
            unit_price="12.50",
        ),
        OrderItemCreate(
            product_sku="tea",
            quantity=3,
            unit_price="1.75",
        ),
    ]

    assert calculate_order_total(items) == Decimal("30.25")


def test_create_order_calculates_totals_and_persists_order() -> None:
    db = create_autospec(Session, instance=True)
    request = OrderCreate(
        customer_reference="customer-123",
        items=[
            OrderItemCreate(
                product_sku="coffee-beans",
                quantity=2,
                unit_price="12.50",
            )
        ],
    )

    order = create_order(db, request)

    assert order.customer_reference == "customer-123"
    assert order.status == OrderStatus.PENDING
    assert order.total_amount == Decimal("25.00")
    assert len(order.items) == 1
    assert order.items[0].line_total == Decimal("25.00")
    db.add.assert_called_once_with(order)
    db.flush.assert_called_once_with()
    db.commit.assert_called_once_with()
    db.refresh.assert_called_once_with(order)


def test_cancel_order_changes_pending_order_to_cancelled() -> None:
    db = create_autospec(Session, instance=True)
    order = Order(status=OrderStatus.PENDING, total_amount=Decimal("10.00"))

    result = cancel_order(db, order)

    assert result is order
    assert order.status == OrderStatus.CANCELLED
    db.commit.assert_called_once_with()
    db.refresh.assert_called_once_with(order)


@pytest.mark.parametrize(
    "status",
    [OrderStatus.PROCESSING, OrderStatus.COMPLETED, OrderStatus.CANCELLED, OrderStatus.FAILED],
)
def test_cancel_order_rejects_non_pending_orders(status: OrderStatus) -> None:
    db = create_autospec(Session, instance=True)
    order = Order(status=status, total_amount=Decimal("10.00"))

    with pytest.raises(OrderNotCancellableError, match=status.value):
        cancel_order(db, order)


def test_list_orders_returns_orders_from_database() -> None:
    db = create_autospec(Session, instance=True)
    order = Order(status=OrderStatus.PENDING, total_amount=Decimal("10.00"))
    db.scalars.return_value.all.return_value = [order]

    result = list_orders(db, limit=20, offset=0)

    assert result == [order]
    db.scalars.assert_called_once()


def test_get_order_returns_order_or_none() -> None:
    db = create_autospec(Session, instance=True)
    order_id = uuid4()
    order = Order(id=order_id, status=OrderStatus.PENDING, total_amount=Decimal("10.00"))
    db.scalar.return_value = order

    assert get_order(db, order_id) is order
    db.scalar.assert_called_once()
