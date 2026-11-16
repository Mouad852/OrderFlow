#!/usr/bin/env bash
set -euo pipefail

base_url="${1:-http://localhost:8000}"
expected_build_sha="${2:-}"

curl --fail-with-body --silent --show-error "${base_url}/health" | jq -e '.status == "ok"'
curl --fail-with-body --silent --show-error "${base_url}/ready" | jq -e '.status == "ready"'

info_response="$(
  curl --fail-with-body --silent --show-error "${base_url}/info"
)"

jq -e \
  '.service == "orderflow-api" and (.environment | length > 0) and (.build_sha | length > 0)' \
  <<<"${info_response}"

if [ -n "${expected_build_sha}" ]; then
  jq -e --arg expected_build_sha "${expected_build_sha}" \
    '.build_sha == $expected_build_sha' \
    <<<"${info_response}"
fi

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
