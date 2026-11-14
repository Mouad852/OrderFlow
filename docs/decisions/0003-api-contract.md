# ADR 0003: Order API contract

- Status: Accepted
- Date: 2026-11-14

## Conventions
- Base path: /
- IDs are UUIDs and timestamps are UTC ISO-8601 values.
- Money is decimal text such as 19.99; binary floating point is not used.
- Errors use the shape: {"detail": "message"}.

## States
PENDING, PROCESSING, COMPLETED, CANCELLED, FAILED
New orders are PENDING. The core build allows only PENDING to CANCELLED.

## Endpoints
- POST /orders creates an order and returns 201.
- GET /orders accepts limit (1-100, default 20) and offset (minimum 0).
- GET /orders/{id} returns 200 or 404.
- PATCH /orders/{id}/cancel returns 200, 404, or 409 when not PENDING.
- GET /health checks only whether the API process is alive.
- GET /ready checks PostgreSQL and returns 503 when it is unavailable.

## Order input and output
- An order has optional customer_reference and one or more items.
- Each item has product_sku, quantity (1-10000), and positive unit_price.
- total_amount and each line_total are calculated using Decimal.
- Order responses include ID, status, totals, UTC timestamps, and items.
