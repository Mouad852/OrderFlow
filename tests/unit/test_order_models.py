from app.database.base import Base
from app.models.orders import Order, OrderItem, OrderStatus


def test_order_status_values() -> None:
    assert [status.value for status in OrderStatus] == [
        "PENDING",
        "PROCESSING",
        "COMPLETED",
        "CANCELLED",
        "FAILED",
    ]


def test_order_models_define_expected_tables() -> None:
    orders = Base.metadata.tables["orders"]
    order_items = Base.metadata.tables["order_items"]

    assert Order.__tablename__ == "orders"
    assert OrderItem.__tablename__ == "order_items"
    assert orders.c.id.primary_key
    assert order_items.c.id.primary_key
    assert len(order_items.foreign_keys) == 1
    assert next(iter(order_items.foreign_keys)).target_fullname == "orders.id"
    assert {
        constraint.name for constraint in orders.constraints if constraint.name is not None
    } >= {"ck_orders_total_amount_non_negative"}
