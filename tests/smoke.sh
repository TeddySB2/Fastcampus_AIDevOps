#!/usr/bin/env bash
# 사용자 여정 Smoke Test (배포 · 복구 · 승격 후 공통 판정)
#   상품 목록 → 상품 상세 → 장바구니 추가 → 장바구니 조회 → 장바구니 비우기
# 성공/실패는 exit code 로만 판정한다. (AI 의 "정상입니다" 는 판정 기준이 아니다)
#
# 사용법:
#   kubectl -n otel-demo-dev port-forward svc/frontend-proxy 8080:8080 &
#   BASE_URL=http://localhost:8080 ./tests/smoke.sh
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
SESSION_ID="smoke-$(date +%s)"
# productCatalogFailure 플래그가 실패시키는 상품. 이 플래그가 켜지면 이 검사가 실패한다
PRODUCT_IDS=(${PRODUCT_IDS:-OLJCESPC7Z 66VCHSJNUP})

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

http() { # method path [body]
  local method=$1 path=$2 body=${3:-}
  if [[ -n "$body" ]]; then
    curl -sS -o /tmp/smoke.out -w '%{http_code}' -X "$method" -H 'Content-Type: application/json' -d "$body" "$BASE_URL$path"
  else
    curl -sS -o /tmp/smoke.out -w '%{http_code}' -X "$method" "$BASE_URL$path"
  fi
}

code=$(http GET "/api/products?currencyCode=USD")
[[ "$code" == 200 ]] || fail "상품 목록 HTTP $code"
count=$(python3 -c 'import json;print(len(json.load(open("/tmp/smoke.out"))))')
[[ "$count" -gt 0 ]] || fail "상품 목록이 비어 있음"
pass "상품 목록 ${count}개"

for id in "${PRODUCT_IDS[@]}"; do
  code=$(http GET "/api/products/${id}?currencyCode=USD")
  [[ "$code" == 200 ]] || fail "상품 상세 ${id} HTTP $code"
  pass "상품 상세 ${id}"

  code=$(http POST "/api/cart" "{\"userId\":\"${SESSION_ID}\",\"item\":{\"productId\":\"${id}\",\"quantity\":1}}")
  [[ "$code" == 200 ]] || fail "장바구니 추가 ${id} HTTP $code"
  pass "장바구니 추가 ${id}"
done

code=$(http GET "/api/cart?sessionId=${SESSION_ID}&currencyCode=USD")
[[ "$code" == 200 ]] || fail "장바구니 조회 HTTP $code"
items=$(python3 -c 'import json;print(len(json.load(open("/tmp/smoke.out"))["items"]))')
[[ "$items" -eq "${#PRODUCT_IDS[@]}" ]] || fail "장바구니 항목 수 ${items} (기대 ${#PRODUCT_IDS[@]})"
pass "장바구니 조회 ${items}개"

code=$(http DELETE "/api/cart" "{\"userId\":\"${SESSION_ID}\"}")
[[ "$code" == 204 ]] || fail "장바구니 비우기 HTTP $code"
pass "장바구니 비우기"

echo "SMOKE OK (${BASE_URL}, session=${SESSION_ID})"
