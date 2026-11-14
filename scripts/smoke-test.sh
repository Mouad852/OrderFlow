#!/usr/bin/env bash
set -euo pipefail

base_url="${1:-http://localhost:8000}"

curl --fail-with-body --silent --show-error "${base_url}/health" | jq -e '.status == "ok"'
curl --fail-with-body --silent --show-error "${base_url}/ready" | jq -e '.status == "ready"'

order_id="$(
  curl --fail-with-body --silent --show-error \
    --request POST "${base_url}/orders" \
    --header 'Content-Type: application/json' \
    --data '{"customer_reference":"smoke-test","items":[{"product_sku":"coffee-beans","quantity":2,"unit_price":"12.50"}]}' \
    | jq --raw-output '.id'
)"

curl --fail-with-body --silent --show-error "${base_url}/orders/${order_id}" \
  | jq -e '.status == "PENDING" and .total_amount == "25.00"'
curl --fail-with-body --silent --show-error "${base_url}/orders?limit=20&offset=0" \
  | jq -e '.items | length >= 1'
curl --fail-with-body --silent --show-error --request PATCH "${base_url}/orders/${order_id}/cancel" \
  | jq -e '.status == "CANCELLED"'

echo "Smoke test passed for ${base_url}"
