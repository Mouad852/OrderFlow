from collections.abc import Sequence
from decimal import Decimal
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models.orders import Order, OrderItem, OrderStatus
from app.schemas.orders import OrderCreate, OrderItemCreate


class OrderNotCancellableError(Exception):
    def __init__(self, status: OrderStatus) -> None:
        self.status = status
        super().__init__(f"Order in {status.value} state cannot be cancelled")


def calculate_line_total(item: OrderItemCreate) -> Decimal:
    return item.unit_price * item.quantity


def calculate_order_total(items: Sequence[OrderItemCreate]) -> Decimal:
    return sum((calculate_line_total(item) for item in items), Decimal("0"))


def create_order(db: Session, request: OrderCreate) -> Order:
    order = Order(
        customer_reference=request.customer_reference,
        status=OrderStatus.PENDING,
        total_amount=calculate_order_total(request.items),
        items=[
            OrderItem(
                product_sku=item.product_sku,
                quantity=item.quantity,
                unit_price=item.unit_price,
                line_total=calculate_line_total(item),
            )
            for item in request.items
        ],
    )

    db.add(order)
    db.flush()
    db.commit()
    db.refresh(order)

    return order


def list_orders(db: Session, *, limit: int, offset: int) -> list[Order]:
    statement = (
        select(Order)
        .options(selectinload(Order.items))
        .order_by(Order.created_at.desc())
        .limit(limit)
        .offset(offset)
    )

    return list(db.scalars(statement).all())


def get_order(db: Session, order_id: UUID) -> Order | None:
    statement = select(Order).options(selectinload(Order.items)).where(Order.id == order_id)

    return db.scalar(statement)


def cancel_order(db: Session, order: Order) -> Order:
    if order.status != OrderStatus.PENDING:
        raise OrderNotCancellableError(order.status)

    order.status = OrderStatus.CANCELLED
    db.commit()
    db.refresh(order)

    return order
