from datetime import UTC, datetime
from decimal import Decimal
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.models.orders import Order, OrderItem, OrderStatus
from app.schemas.orders import OrderCreate, OrderItemCreate, OrderRead


def test_order_create_accepts_valid_data() -> None:
    order = OrderCreate(
        customer_reference="  customer-123  ",
        items=[
            OrderItemCreate(
                product_sku="  coffee-beans  ",
                quantity=2,
                unit_price="12.50",
            )
        ],
    )

    assert order.customer_reference == "customer-123"
    assert order.items[0].product_sku == "coffee-beans"
    assert order.items[0].unit_price == Decimal("12.50")


@pytest.mark.parametrize(
    ("quantity", "unit_price"),
    [
        (0, "12.50"),
        (10_001, "12.50"),
        (1, "0"),
        (1, "12.345"),
    ],
)
def test_order_item_rejects_invalid_values(quantity: int, unit_price: str) -> None:
    with pytest.raises(ValidationError):
        OrderItemCreate(
            product_sku="coffee-beans",
            quantity=quantity,
            unit_price=unit_price,
        )


def test_order_create_requires_at_least_one_item() -> None:
    with pytest.raises(ValidationError):
        OrderCreate(items=[])


def test_order_read_serializes_an_order_model() -> None:
    now = datetime(2026, 11, 14, 13, 30, tzinfo=UTC)
    item = OrderItem(
        id=uuid4(),
        product_sku="coffee-beans",
        quantity=2,
        unit_price=Decimal("12.50"),
        line_total=Decimal("25.00"),
    )
    order = Order(
        id=uuid4(),
        customer_reference="customer-123",
        status=OrderStatus.PENDING,
        total_amount=Decimal("25.00"),
        created_at=now,
        updated_at=now,
        items=[item],
    )

    result = OrderRead.model_validate(order)

    assert result.id == order.id
    assert result.status == OrderStatus.PENDING
    assert result.items[0].product_sku == "coffee-beans"
    assert result.model_dump(mode="json")["total_amount"] == "25.00"
