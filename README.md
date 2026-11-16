# OrderFlow

A FastAPI order service with PostgreSQL, versioned schema migrations, and a reproducible local Docker runtime.

## Run locally

From WSL in the repository root:

```bash
docker compose up --build -d
docker compose ps
bash scripts/smoke-test.sh
```

The API is then available at:

- Interactive OpenAPI documentation: <http://localhost:8000/docs>
- Liveness check: <http://localhost:8000/health>
- Database readiness check: <http://localhost:8000/ready>

Stop the containers while keeping local database data:

```bash
docker compose down
```

To also erase the local PostgreSQL data volume, run `docker compose down -v`. This deletes local order data.

## API

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/orders` | Create a `PENDING` order. |
| `GET` | `/orders?limit=&offset=` | List orders with pagination. |
| `GET` | `/orders/{order_id}` | Retrieve one order. |
| `PATCH` | `/orders/{order_id}/cancel` | Cancel a `PENDING` order. |
| `GET` | `/health` | Check that the API process is alive. |
| `GET` | `/ready` | Check that PostgreSQL is reachable. |
| `GET` | `/info` | Report the service, environment, and deployed Git commit. |

Example request:

```bash
curl --request POST http://localhost:8000/orders \
  --header 'Content-Type: application/json' \
  --data '{
    "customer_reference": "customer-123",
    "items": [
      {
        "product_sku": "coffee-beans",
        "quantity": 2,
        "unit_price": "12.50"
      }
    ]
  }'
```

Money values are decimal strings. New orders are `PENDING`; only `PENDING` orders can be cancelled.

## Quality checks

```bash
uv run ruff format --check .
uv run ruff check .
uv run pytest tests/unit -q
```

## Local architecture

Docker Compose starts three services in sequence:

1. `database` — PostgreSQL 17 with a persistent local volume.
2. `migrate` — runs Alembic migrations once after PostgreSQL becomes healthy.
3. `api` — starts only after migrations succeed, as a non-root user on port 8000.

The Compose PostgreSQL credentials are intentionally local-development values. They must never be used in staging or production; Azure Key Vault will provide environment-specific credentials later in the project.
