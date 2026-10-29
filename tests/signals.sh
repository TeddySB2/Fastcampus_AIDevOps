#!/usr/bin/env bash
# 신호 검증 (specs/observability.md 5장 "신호 (관측된다)")
#   주문(checkout PlaceOrder)의 메트릭 · 트레이스 · 로그가 실제로 들어오고 trace_id 하나로 이어지는지 확인한다.
#   load-generator 가 계속 만드는 주문을 쓴다. 성공/실패는 exit code 로만 판정한다.
#
# 사용법 (port-forward 4개를 먼저 연다):
#   kubectl -n observability port-forward svc/kube-prometheus-stack-prometheus 9090:9090 &
#   kubectl -n observability port-forward svc/tempo 3200:3200 &
#   kubectl -n observability port-forward svc/loki 3100:3100 &
#   kubectl -n observability port-forward svc/kube-prometheus-stack-grafana 3000:80 &
#   ./tests/signals.sh
#
# 선택: GRAFANA_USER / GRAFANA_PASSWORD 를 환경 변수로 주면 로그인 뒤 대시보드 조회(5-b)까지 확인한다.
#       이 스크립트는 Secret 을 읽지 않는다 (팀 규칙 6).
set -euo pipefail

PROM_URL="${PROM_URL:-http://localhost:9090}"
TEMPO_URL="${TEMPO_URL:-http://localhost:3200}"
LOKI_URL="${LOKI_URL:-http://localhost:3100}"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
NS="${NS:-observability}"
DASHBOARD_UID="${DASHBOARD_UID:-payment-journey}"
TMP="${TMPDIR:-/tmp}/signals.$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
note() { echo "NOTE: $*"; }

# Prometheus instant query → 첫 결과의 값 (없으면 빈 문자열)
promq() {
  curl -sS -G "$PROM_URL/api/v1/query" --data-urlencode "query=$1" \
    | python3 -c 'import json,sys
d=json.load(sys.stdin)
r=d.get("data",{}).get("result",[])
print(r[0]["value"][1] if r else "")'
}

PLACE='service_name="checkout", span_name="oteldemo.CheckoutService/PlaceOrder", span_kind="SPAN_KIND_SERVER"'
CARD_RE='(^|[^0-9])[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{4}([^0-9]|$)|(^|[^0-9])[0-9]{16}([^0-9]|$)'

# ---------------------------------------------------------------------------
echo "== 1. 메트릭 (Prometheus: SLI-1 분모가 있고 5분 전보다 늘었나)"
now_total=$(promq "sum(traces_span_metrics_calls_total{${PLACE}})")
before_total=$(promq "sum(traces_span_metrics_calls_total{${PLACE}} offset 5m)")
[[ -n "$now_total" ]] || fail "traces_span_metrics_calls_total{checkout PlaceOrder} 가 Prometheus 에 없음 (${PROM_URL})"
[[ -n "$before_total" ]] || fail "5분 전 샘플이 없음 (수집 시작 5분 뒤 다시 실행)"
python3 -c "import sys; sys.exit(0 if float('$now_total') > float('$before_total') else 1)" \
  || fail "PlaceOrder 호출 수가 늘지 않음 (지금 $now_total, 5분 전 $before_total)"
pass "PlaceOrder 호출 수 $before_total → $now_total (5분)"

# ---------------------------------------------------------------------------
echo "== 2. 트레이스 (Tempo: 최근 15분 checkout PlaceOrder, frontend · checkout · payment 가 한 트레이스에)"
end=$(date +%s); start=$((end - 900))
curl -sS -G "$TEMPO_URL/api/search" \
  --data-urlencode 'q={ resource.service.name = "checkout" && name = "oteldemo.CheckoutService/PlaceOrder" }' \
  --data-urlencode "start=$start" --data-urlencode "end=$end" --data-urlencode "limit=20" > "$TMP/search.json"
mapfile -t trace_ids < <(python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
for t in d.get("traces",[]): print(t["traceID"])' "$TMP/search.json")
[[ ${#trace_ids[@]} -gt 0 ]] || fail "Tempo 검색 결과 0건 (${TEMPO_URL}, 최근 15분)"
pass "Tempo 검색 ${#trace_ids[@]}건"

# 트레이스 JSON(OTLP 형식: batches/resourceSpans)에서 서비스 · span · 속성을 뽑는다
TRACE_ID=""
for id in "${trace_ids[@]}"; do
  curl -sS -H 'Accept: application/json' "$TEMPO_URL/api/traces/$id" > "$TMP/trace.json" || continue
  if python3 - "$TMP/trace.json" "$TMP/attrs.txt" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
services, attrs = set(), []
def val(v):
    for k in ("stringValue", "intValue", "doubleValue", "boolValue"):
        if k in v: return str(v[k])
    return json.dumps(v)
def walk(o):
    if isinstance(o, dict):
        if "resource" in o and ("scopeSpans" in o or "instrumentationLibrarySpans" in o):
            svc = "?"
            for a in o["resource"].get("attributes", []):
                if a.get("key") == "service.name": svc = val(a["value"])
            services.add(svc)
            for ss in o.get("scopeSpans", o.get("instrumentationLibrarySpans", [])):
                for sp in ss.get("spans", []):
                    for a in sp.get("attributes", []):
                        attrs.append(f'{svc}\t{sp.get("name")}\t{a.get("key")}\t{val(a["value"])}')
        for v in o.values(): walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
walk(d)
open(sys.argv[2], "w").write("\n".join(attrs) + "\n")
need = {"frontend", "checkout", "payment"}
sys.exit(0 if need <= services else 1)
PY
  then TRACE_ID="$id"; break; fi
done
[[ -n "$TRACE_ID" ]] || fail "검색된 트레이스 중 frontend · checkout · payment 를 모두 포함한 것이 없음"
pass "trace_id=$TRACE_ID 에 frontend · checkout · payment span 포함"

# ---------------------------------------------------------------------------
echo "== 3. 로그 (Loki: 같은 trace_id 로 checkout 또는 payment 로그 1줄 이상)"
start_ns=$(( (end - 1800) * 1000000000 )); end_ns=$(( (end + 60) * 1000000000 ))
loki_lines() { # $1 = LogQL
  curl -sS -G "$LOKI_URL/loki/api/v1/query_range" --data-urlencode "query=$1" \
    --data-urlencode "start=$start_ns" --data-urlencode "end=$end_ns" --data-urlencode "limit=200" \
    | python3 -c 'import json,sys
d=json.load(sys.stdin)
for s in d.get("data",{}).get("result",[]):
    for _,line in s.get("values",[]): print(line)'
}
# trace_id 는 OTLP 로그의 structured metadata 로 들어온다. (혹시 본문에만 있으면 라인 필터로 한 번 더 찾는다)
LOGQL="{service_name=~\"checkout|payment\"} | trace_id=\"$TRACE_ID\""
loki_lines "$LOGQL" > "$TMP/logs.txt" || true
if [[ ! -s "$TMP/logs.txt" ]]; then
  LOGQL="{service_name=~\"checkout|payment\"} |= \"$TRACE_ID\""
  loki_lines "$LOGQL" > "$TMP/logs.txt" || true
fi
log_count=$(grep -c . "$TMP/logs.txt" || true)
[[ "$log_count" -gt 0 ]] || fail "Loki 에 trace_id=$TRACE_ID 로그가 없음 (쿼리: $LOGQL, ${LOKI_URL})"
pass "Loki ${log_count}줄 (쿼리: $LOGQL)"
pass "메트릭 → 트레이스 → 로그가 trace_id=$TRACE_ID 로 이어짐"

# ---------------------------------------------------------------------------
echo "== 4. 민감 정보 (트레이스 속성 · 로그에 카드번호 원문이 없나)"
if grep -P "$CARD_RE" "$TMP/attrs.txt" "$TMP/logs.txt" >/dev/null 2>&1 \
   || grep -E "$CARD_RE" "$TMP/attrs.txt" "$TMP/logs.txt" >/dev/null 2>&1; then
  fail "카드번호 형식(16자리)의 원문이 트레이스 또는 로그에 있음 — Collector 의 redact 처리기를 확인"
fi
card_attrs=$(awk -F'\t' '$3=="demo.payment.card_number"{print $4}' "$TMP/attrs.txt" | sort -u || true)
if [[ -n "$card_attrs" ]]; then
  while read -r v; do
    [[ "$v" == '****-****-****-'* ]] || fail "demo.payment.card_number 가 마스킹되지 않음: $v"
  done <<< "$card_attrs"
  pass "demo.payment.card_number 마스킹 확인 ($(echo "$card_attrs" | head -1))"
else
  pass "카드번호 원문 없음 (demo.payment.card_number 속성은 이 트레이스에 없음)"
fi

# ---------------------------------------------------------------------------
echo "== 5. Grafana (인증 없이 401, 대시보드가 Git 의 ConfigMap 에서 provisioning)"
code=$(curl -sS -o /dev/null -w '%{http_code}' "$GRAFANA_URL/api/dashboards/home")
[[ "$code" == 401 ]] || fail "인증 없는 GET /api/dashboards/home 이 $code (기대 401)"
pass "익명 접근 차단 (401)"
if command -v kubectl >/dev/null; then
  cms=$(kubectl -n "$NS" get cm -l grafana_dashboard=1 -o name 2>/dev/null || true)
  [[ -n "$cms" ]] || fail "$NS 에 grafana_dashboard=1 ConfigMap 이 없음"
  pass "대시보드 ConfigMap: $(echo "$cms" | tr '\n' ' ')"
else
  note "kubectl 이 없어 ConfigMap 존재 확인을 건너뜀"
fi
if [[ -n "${GRAFANA_USER:-}" && -n "${GRAFANA_PASSWORD:-}" ]]; then
  code=$(curl -sS -o "$TMP/dash.json" -w '%{http_code}' -u "$GRAFANA_USER:$GRAFANA_PASSWORD" "$GRAFANA_URL/api/dashboards/uid/$DASHBOARD_UID")
  [[ "$code" == 200 ]] || fail "로그인 뒤 대시보드 uid=$DASHBOARD_UID 조회가 $code"
  pass "로그인 뒤 대시보드 '$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["dashboard"]["title"])' "$TMP/dash.json")' 조회"
else
  note "GRAFANA_USER/GRAFANA_PASSWORD 가 없어 로그인 뒤 조회(5-b)는 건너뜀"
fi

# ---------------------------------------------------------------------------
echo "== 6. 파이프라인 (Collector exporter 전송 실패가 10분간 0)"
failed=$(curl -sS -G "$PROM_URL/api/v1/query" --data-urlencode \
  'query=sum by (exporter, __name__) (increase({__name__=~"otelcol_exporter_send_failed_(spans|metric_points|log_records)_total", exporter=~"otlp_grpc/tempo|otlp_http/prometheus|otlp_http/loki"}[10m]))' \
  | python3 -c 'import json,sys
d=json.load(sys.stdin)
for r in d.get("data",{}).get("result",[]):
    if float(r["value"][1]) > 0:
        print(r["metric"].get("__name__"), r["metric"].get("exporter"), r["value"][1])')
[[ -z "$failed" ]] || fail "exporter 전송 실패가 있음 (10분 increase):"$'\n'"$failed"
sent=$(promq 'sum(increase(otelcol_exporter_sent_spans_total{exporter="otlp_grpc/tempo"}[10m]))')
[[ -n "$sent" ]] || fail "otelcol_exporter_sent_spans_total{exporter=\"otlp_grpc/tempo\"} 가 없음 — Collector 자체 메트릭이 Prometheus 에 안 들어옴"
pass "exporter 전송 실패 0 (10분). Tempo 로 보낸 span $(printf '%.0f' "$sent")개"

echo "SIGNALS OK (trace_id=$TRACE_ID)"
