from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.schemas.orders import OrderCreate, OrderList, OrderRead
from app.services.orders import (
    OrderNotCancellableError,
    cancel_order,
    create_order,
    get_order,
    list_orders,
)

router = APIRouter(prefix="/orders", tags=["Orders"])


@router.post("", response_model=OrderRead, status_code=status.HTTP_201_CREATED)
def create_order_endpoint(
    request: OrderCreate,
    db: Annotated[Session, Depends(get_db)],
) -> OrderRead:
    return create_order(db, request)


@router.get("", response_model=OrderList)
def list_orders_endpoint(
    db: Annotated[Session, Depends(get_db)],
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> OrderList:
    orders = list_orders(db, limit=limit, offset=offset)
    return OrderList(items=orders, limit=limit, offset=offset)


@router.get("/{order_id}", response_model=OrderRead)
def get_order_endpoint(
    order_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> OrderRead:
    order = get_order(db, order_id)
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")

    return order


@router.patch("/{order_id}/cancel", response_model=OrderRead)
def cancel_order_endpoint(
    order_id: UUID,
    db: Annotated[Session, Depends(get_db)],
) -> OrderRead:
    order = get_order(db, order_id)
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")

    try:
        return cancel_order(db, order)
    except OrderNotCancellableError as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(error),
        ) from error
