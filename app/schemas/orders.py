from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.orders import OrderStatus


class OrderItemCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    product_sku: str = Field(min_length=1, max_length=100)
    quantity: int = Field(ge=1, le=10_000)
    unit_price: Decimal = Field(gt=Decimal("0"), max_digits=12, decimal_places=2)


class OrderCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    customer_reference: str | None = Field(default=None, min_length=1, max_length=100)
    items: list[OrderItemCreate] = Field(min_length=1)


class OrderItemRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    product_sku: str
    quantity: int
    unit_price: Decimal
    line_total: Decimal


class OrderRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    customer_reference: str | None
    status: OrderStatus
    total_amount: Decimal
    created_at: datetime
    updated_at: datetime
    items: list[OrderItemRead]


class OrderList(BaseModel):
    items: list[OrderRead]
    limit: int
    offset: int
