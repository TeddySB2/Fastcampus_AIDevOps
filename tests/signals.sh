#!/usr/bin/env bash
# 관측 신호 연결 검증 (1-3): "Pod 가 Running" 이 아니라 "세 신호가 도착하고 서로 이어진다" 를 확인한다.
#   1) 메트릭  — checkout 의 span metrics 가 Prometheus 에 있다
#   2) 로그    — checkout 로그가 Loki 에 있고, trace_id 가 붙어 있다
#   3) 트레이스 — 그 trace_id 로 Tempo 에서 트레이스를 찾는다
#   4) exemplar — 메트릭에서 트레이스로 가는 trace_id 가 있다
# 성공/실패는 exit code 로만 판정한다. 결과 표는 specs/observability.md 의 "관측 기준선" 에 붙인다.
#
# 사용법 (port-forward 없이 API 서버의 service proxy 로 조회한다. 읽기 전용):
#   ./tests/signals.sh
#   SERVICE=payment WINDOW=15m ./tests/signals.sh
# 로컬에서 직접 띄운 백엔드로 시험할 때: PROM_URL=http://localhost:9090 LOKI_URL=... TEMPO_URL=... ./tests/signals.sh
set -euo pipefail

NS="${NS:-observability}"
SERVICE="${SERVICE:-checkout}"
WINDOW="${WINDOW:-10m}"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
warn() { echo "WARN: $*"; }

urlenc() { python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=""))' "$1"; }

# get <backend> <path?query>  — backend: prom | loki | tempo
get() {
  local backend=$1 path=$2 base svc
  case $backend in
    prom)  base="${PROM_URL:-}";  svc="kps-prometheus:9090" ;;
    loki)  base="${LOKI_URL:-}";  svc="loki:3100" ;;
    tempo) base="${TEMPO_URL:-}"; svc="tempo:3200" ;;
  esac
  if [[ -n "$base" ]]; then
    curl -sSf "$base$path"
  else
    kubectl get --raw "/api/v1/namespaces/$NS/services/$svc/proxy$path"
  fi
}

json() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }

echo "== 대상: service_name=$SERVICE, 최근 $WINDOW"

# 1) 메트릭
q="sum(rate(traces_span_metrics_calls_total{service_name=\"$SERVICE\"}[5m]))"
val=$(get prom "/api/v1/query?query=$(urlenc "$q")" | json 'd["data"]["result"][0]["value"][1] if d["data"]["result"] else ""') || fail "Prometheus 조회 실패"
[[ -n "$val" ]] || fail "메트릭 없음: $q  (Collector exporter · Prometheus OTLP 수신 확인)"
python3 -c "import sys; sys.exit(0 if float('$val') > 0 else 1)" || fail "메트릭은 있으나 최근 5분 요청이 0: $q  (load-generator 가 돌고 있는지 확인)"
pass "메트릭 $q = $(printf '%.2f' "$val") req/s"

# 2) 로그 + trace_id
now=$(date +%s); start=$(( now - $(python3 -c "import re;m=re.match(r'(\d+)([mh])','$WINDOW');print(int(m[1])*(60 if m[2]=='m' else 3600))") ))
lq="{service_name=\"$SERVICE\"} | trace_id != \"\""
logs=$(get loki "/loki/api/v1/query_range?query=$(urlenc "$lq")&start=${start}000000000&end=${now}000000000&limit=20&direction=backward") || fail "Loki 조회 실패"
trace_id=$(echo "$logs" | python3 -c '
import json,sys
d=json.load(sys.stdin)
for s in d["data"]["result"]:
    tid=s["stream"].get("trace_id")
    if tid: print(tid); break
    for v in s["values"]:
        if len(v)>2 and v[2].get("trace_id"): print(v[2]["trace_id"]); sys.exit()
')
lines=$(echo "$logs" | json 'sum(len(s["values"]) for s in d["data"]["result"])')
[[ "$lines" -gt 0 ]] || fail "trace_id 가 붙은 로그 없음: $lq  (Collector logs pipeline · Loki OTLP 수신 확인)"
[[ -n "$trace_id" ]] || fail "로그는 있으나 trace_id 를 꺼내지 못함"
pass "로그 ${lines}줄, trace_id=$trace_id"

# 3) 같은 trace_id 의 트레이스
spans=$(get tempo "/api/traces/$trace_id" | python3 -c '
import json,sys
d=json.load(sys.stdin)
batches=d.get("batches") or d.get("resourceSpans") or (d.get("trace") or {}).get("resourceSpans") or []
n=0
for b in batches:
    for ss in b.get("scopeSpans", b.get("instrumentationLibrarySpans", [])):
        n+=len(ss.get("spans",[]))
print(n)') || fail "Tempo 에서 trace $trace_id 조회 실패"
[[ "$spans" -gt 0 ]] || fail "Tempo 에 trace $trace_id 의 span 이 없음"
pass "트레이스 $trace_id span ${spans}개"

# 4) exemplar (메트릭 → 트레이스). 없으면 경고만 한다
eq="traces_span_metrics_duration_milliseconds_bucket{service_name=\"$SERVICE\"}"
ex=$(get prom "/api/v1/query_exemplars?query=$(urlenc "$eq")&start=$start&end=$now" | json 'sum(len(s.get("exemplars",[])) for s in d["data"])' 2>/dev/null || echo 0)
if [[ "$ex" -gt 0 ]]; then pass "exemplar ${ex}개 ($eq)"; else warn "exemplar 없음 — span_metrics connector 의 exemplars 설정 확인"; fi

echo "OK: $SERVICE 의 메트릭 · 로그 · 트레이스가 trace_id 로 이어진다"
