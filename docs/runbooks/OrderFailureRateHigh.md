# Runbook: OrderFailureRateHigh (주문 실패율)

> 알람: `OrderFailureRateHigh` — `gitops/manifests/observability/order-failure-alert.yaml` 의 `annotations.runbook_url` 이 이 파일을 가리킨다.
> 대상: `otel-demo-dev` 만. 사람과 Claude 가 같은 순서로 따라 한다. 고칠 때는 PR 로 한다.
> 근거: `docs/requirements/incident.md`(역할 · 심각도 · 시간), `specs/observability.md`(SLI 9장 · 기준선 10장 · 호출 경로 8장), `CLAUDE.md` "장애 대응".
> 쿼리는 2026-11-24 22:22 KST 에 Grafana MCP 로 실행해 결과가 나오는 것을 확인했다(Prometheus · Tempo). Loki 쿼리는 `tests/signals.sh` 가 쓰는 것과 같다.

## 0. 누가 무엇을 하나

| | 한다 | 하지 않는다 |
| --- | --- | --- |
| 장애 지휘자(IC) — 그날 당번. dev 는 @TeddySB2 | 장애 선언, 심각도 확정, 복구 승인 · 실행, 공지, 종료 선언 | |
| Claude | 읽기 전용 조회, 영향 범위 · 심각도 **제안**, 원인 후보 표, 복구 후보 정리 | 장애 선언, 심각도 확정, 복구 실행(클러스터 변경 · 플래그 변경 · revert merge), 공지 |

시간: 알람 뒤 **5분 안에 첫 보고**(8장 형식), 이후 **10분마다** 같은 형식으로 갱신. **30분**이 지나도 원인 서비스를 못 좁히면 IC 에게 알리고 다음을 묻는다.
5분 안에 3장의 1 ~ 3 단계(수집 · 영향 범위 · 어디서)까지만 끝내고 보고한다. 트레이스 · 로그(4 · 5 단계)는 첫 보고 뒤에 이어 간다.

## 1. 이 알람이 뜻하는 것

checkout 의 `oteldemo.CheckoutService/PlaceOrder` 서버 span 중 ERROR 로 끝난 비율(주문 실패율)이 SLO(99%, 30일)의 오류 예산을 너무 빨리 쓰고 있다.
burn rate = 실패율 / 1%. 한 알람 이름에 세 단계가 있고 라벨 `burn_rate` 로 구분한다. 각 단계는 긴 창과 짧은 창이 **둘 다** 임계를 넘고 2분 지속되면 firing 한다.

| `burn_rate` | 임계 실패율 | 긴 창 + 짧은 창 | 뜻 | 원인이 사라진 뒤 해제까지 |
| --- | --- | --- | --- | --- |
| `14.4` | 14.4% | 1h + 5m | 큰 장애. 지금 많이 실패한다 | 약 5분 |
| `6` | 6% | 6h + 30m | 중간 크기 실패가 몇 시간 이어졌다 | 최대 30분 |
| `2` | 2% | 1d + 2h | 낮은 실패율이 오래 이어지는 느린 누수 | 최대 2시간 |

- 기준선은 실패율 0% 다(`specs/observability.md` 10장). 실패가 조금이라도 계속되면 평소와 다른 것이다.
- **firing 인 단계만으로 지금 실패율을 말하지 않는다.** 6배 · 2배 단계는 원인이 사라진 뒤에도 한동안 남는다. 지금 값은 3장 2 단계의 5분 실패율로 본다.
- 수신처가 없다. 사람을 깨우지 않으며 Prometheus Alerts 화면 · Grafana 에서 상태만 보인다.

## 2. 먼저 여는 화면

- Grafana 대시보드 "결제 여정 (dev)" (uid `payment-journey`). 접속은 port-forward 로만 한다.
- Claude 는 Grafana MCP 로 아래 쿼리를 그대로 실행한다. 데이터소스 uid: `prometheus` · `tempo` · `loki`.
- 모든 수치에 쿼리 · 시간 범위(KST 절대 시각) · 데이터소스를 붙인다. 조회 범위는 기본 1시간, 최대 24시간.

## 3. 볼 것 (이 순서대로)

### 1 단계 — 수집부터 확인한다 (데이터가 없는 것과 장애를 가른다)

```promql
# 알람의 지금 상태 (단계 · pending/firing)
sum by (burn_rate, alertstate) (ALERTS{alertname="OrderFailureRateHigh"})

# 마지막 주문 메트릭이 몇 초 전인가
time() - max(timestamp(traces_span_metrics_calls_total{service_name="checkout", span_name="oteldemo.CheckoutService/PlaceOrder", span_kind="SPAN_KIND_SERVER"}))

# 죽은 수집 대상
count by (job) (up == 0)

# Collector 가 최근 10분에 못 보낸 것
sum by (exporter) (increase({__name__=~"otelcol_exporter_(send|enqueue)_failed_(spans|metric_points|log_records)_total"}[10m]))

# Prometheus 가 뜬 지 몇 초인가
time() - max(process_start_time_seconds{job="kube-prometheus-stack-prometheus"})
```

| 결과 | 읽는 법 |
| --- | --- |
| 마지막 주문 메트릭이 120초 안, `up == 0` 비어 있음, Collector 실패 비어 있음 · 0 | 수집 정상. 2 단계로 |
| 마지막 주문 메트릭이 5분 넘게 전이거나 빈 결과 | 실패율을 믿지 않는다. "데이터 없음" 으로 보고하고 6장 "데이터 없음" 을 먼저 푼다 |
| Collector 실패가 0 보다 큼 (`otlp_grpc/tempo` · `otlp_http/prometheus` · `otlp_http/loki`) | 그 신호의 수치가 실제보다 적을 수 있다고 보고에 적는다 |
| Prometheus 가동 시간이 긴 창(1h · 6h · 1d)보다 짧음 | 그 단계는 실제보다 민감하다(이력이 짧다). 세 단계가 한꺼번에 뜬 이유일 수 있다 |

### 2 단계 — 영향 범위: 지금 얼마나 · 언제부터

```promql
# 5분 주문 실패율 (SLI-1 의 1 − 값). ERROR 시계열이 없으면 0 으로 본다
(sum(rate(traces_span_metrics_calls_total{service_name="checkout", span_name="oteldemo.CheckoutService/PlaceOrder", span_kind="SPAN_KIND_SERVER", status_code="STATUS_CODE_ERROR"}[5m])) or vector(0)) / sum(rate(traces_span_metrics_calls_total{service_name="checkout", span_name="oteldemo.CheckoutService/PlaceOrder", span_kind="SPAN_KIND_SERVER"}[5m]))

# 5분 주문 건수 (분모). 실패율과 함께 적는다
sum(increase(traces_span_metrics_calls_total{service_name="checkout", span_name="oteldemo.CheckoutService/PlaceOrder", span_kind="SPAN_KIND_SERVER"}[5m]))

# 주문 p95 (ms)
histogram_quantile(0.95, sum by (le) (rate(traces_span_metrics_duration_milliseconds_bucket{service_name="checkout", span_name="oteldemo.CheckoutService/PlaceOrder", span_kind="SPAN_KIND_SERVER"}[5m])))

# frontend 쪽에서 본 주문 실패 (/분): frontend 가 checkout 을 부른 client span 의 ERROR
sum(rate(traces_span_metrics_calls_total{service_name="frontend", span_name="oteldemo.CheckoutService/PlaceOrder", span_kind="SPAN_KIND_CLIENT", status_code="STATUS_CODE_ERROR"}[5m])) * 60 or vector(0)

# 보조: frontend POST /api/checkout 서버 span 의 ERROR(=5xx) (/분)
sum(rate(traces_span_metrics_calls_total{service_name="frontend", span_name="POST /api/checkout", span_kind="SPAN_KIND_SERVER", status_code="STATUS_CODE_ERROR"}[5m])) * 60 or vector(0)
```

- 마지막 쿼리(서버 span 5xx)는 **0 이어도 주문 실패가 없다는 뜻이 아니다.** 2026-11-24 22:24 KST 에 주문이 실패하는 동안 frontend 의 client span ERROR 는 0.75건/분이었는데 서버 span ERROR 는 0 이었다(Prometheus, 5분 창). 영향 범위는 checkout PlaceOrder 실패율과 client span 으로 말하고, 서버 span 은 참고로만 적는다.
- **언제부터**: 첫째 쿼리를 range 조회(최근 1시간, step 60초)로 실행해 0 에서 벗어난 시각을 찾는다. span 메트릭은 1 ~ 2분 늦게 보이므로 정확한 시각은 4 단계 트레이스로 확인한다.
- 주문 건수가 0 이거나 실패율이 빈 결과면 "실패율 0%" 가 아니라 **"주문 없음"** 이다. 주문이 전혀 처리되지 않는 경우이므로 SEV1 후보로 IC 에게 바로 알린다.
- 이 값으로 4장의 심각도를 제안한다.

### 3 단계 — 어디서 깨졌는가

```promql
# checkout 의 ERROR span 을 이름별로 (/분). 어느 하위 호출에서 실패했는지 가장 빨리 보인다
sum by (span_name, span_kind) (rate(traces_span_metrics_calls_total{service_name="checkout", status_code="STATUS_CODE_ERROR"}[5m])) * 60

# 하위 서비스의 서버 span ERROR 비율 (대시보드 A3 과 같은 쿼리)
(sum by (service_name) (rate(traces_span_metrics_calls_total{service_name=~"payment|cart|product-catalog|currency|shipping|email", span_kind="SPAN_KIND_SERVER", status_code="STATUS_CODE_ERROR"}[5m])) or (sum by (service_name) (rate(traces_span_metrics_calls_total{service_name=~"payment|cart|product-catalog|currency|shipping|email", span_kind="SPAN_KIND_SERVER"}[5m])) * 0)) / sum by (service_name) (rate(traces_span_metrics_calls_total{service_name=~"payment|cart|product-catalog|currency|shipping|email", span_kind="SPAN_KIND_SERVER"}[5m]))

# 하위 서비스 p95 (ms)
histogram_quantile(0.95, sum by (le, service_name) (rate(traces_span_metrics_duration_milliseconds_bucket{service_name=~"payment|cart|product-catalog|currency|shipping|email", span_kind="SPAN_KIND_SERVER"}[5m])))

# kafka 적재 (checkout 의 producer span) ERROR 비율
(sum(rate(traces_span_metrics_calls_total{service_name="checkout", span_name="publish orders", span_kind="SPAN_KIND_PRODUCER", status_code="STATUS_CODE_ERROR"}[5m])) or vector(0)) / sum(rate(traces_span_metrics_calls_total{service_name="checkout", span_name="publish orders", span_kind="SPAN_KIND_PRODUCER"}[5m]))
```

- 둘째 쿼리에서 값이 `NaN` 이거나 서비스가 결과에 없으면 "ERROR 0%" 가 아니라 **그 서비스의 서버 span 이 5분간 없다**는 뜻이다(호출이 안 갔거나 서비스가 죽었다). 따로 적는다.
- 하위 서비스의 수치는 그 서비스의 서버 span 전체다. 주문이 아닌 호출도 들어 있다. 주문 실패와 묶으려면 4 단계 트레이스로 확인한다.

### 4 단계 — 트레이스 (Tempo): 처음 실패한 span

```traceql
{ resource.service.name = "checkout" && name = "oteldemo.CheckoutService/PlaceOrder" && status = error }
```

- 실패한 트레이스를 **세 건 이상** 열어 같은 곳에서 깨지는지 본다. 한 건으로 단정하지 않는다.
- 트레이스마다 적는다: 처음 ERROR 가 난 span(서비스 · span 이름), 그 뒤에 실행되지 않은 단계(8장 호출 경로와 비교), 시작 시각(KST).
- 3 단계에서 의심한 서비스로 좁힐 때: `{ resource.service.name = "payment" && status = error }` 처럼 서비스 이름만 바꾼다.
- 성공한 주문 한 건(`status != error`)과 나란히 놓고 어디서 갈리는지 본다.

### 5 단계 — 로그 (Loki): 왜

```logql
{service_name=~"checkout|payment"} | trace_id="<4 단계의 trace_id>"
```

- `service_name` 은 4 단계에서 좁힌 서비스로 바꾼다. 서비스 라벨 없이 조회하지 않는다.
- 이메일 · 카드 번호가 보이면 인용하지 않고 "민감 정보 있음" 으로만 적는다.

### 6 단계 — 같은 시각의 다른 문제 (원인인지 따로 가린다)

```promql
# 최근 1시간에 재시작한 컨테이너
sum by (namespace, pod, container) (increase(kube_pod_container_status_restarts_total{namespace="otel-demo-dev"}[1h])) > 0

# 지금 CrashLoop 인 컨테이너 (최근 10분)
sum by (namespace, pod, container) (max_over_time(kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"}[10m])) > 0

# 이 알람 말고 지금 firing 인 알람
sum by (alertname, namespace) (ALERTS{alertstate="firing", alertname!~"Watchdog|OrderFailureRateHigh"})
```

여기서 나온 것은 **후보일 뿐**이다. 원인으로 올리기 전에 5장의 "동시에 일어난 다른 문제" 검사를 통과해야 한다.

### 7 단계 — 직전에 무엇이 바뀌었나

```bash
kubectl config current-context          # 스펙의 클러스터(ai-devops-lab-dev)인지 먼저 확인
argocd app history otel-demo-dev
kubectl -n otel-demo-dev rollout history deploy/<서비스>
kubectl -n otel-demo-dev get events --sort-by=.lastTimestamp
```

- 2 단계의 시작 시각 직전에 배포 · 재시작 · 노드 변화가 있었는지 본다.
- **플래그 상태는 Claude 가 볼 수 없다.** 사람이 `scenarios/flag.sh --list` 를 실행해 결과를 알려 준다(7장 "멈추고 물을 곳").

## 4. 판단 기준

### 심각도 (Claude 는 제안, IC 가 확정)

기준은 `CLAUDE.md` "장애 대응" 의 표와 같다. 다르면 `CLAUDE.md` 가 맞다. 처음 매긴 값은 임시이며 영향 범위가 확인되면 IC 가 바꾼다.

| 심각도 | 기준 (3장 2 단계의 5분 주문 실패율) | 대응 |
| --- | --- | --- |
| SEV1 | 50% 이상, 또는 주문이 전혀 처리되지 않음(주문 건수 0) | IC 즉시 · 장애 선언 |
| SEV2 | `OrderFailureRateHigh` firing, 또는 5% 이상 | IC 즉시 |
| SEV3 | 주문은 정상, 다른 기능 일부 오류(상품 · 광고 · 추천) | 업무 시간 · Issue |
| SEV4 | 사용자 영향 없음 (재시작 후 정상 · 알람만) | 기록 |

- 이 알람이 firing 이면 **최소 SEV2** 로 제안한다. 5분 실패율이 50% 이상이거나 주문 건수가 0 이면 SEV1 로 제안한다.
- 알람은 firing 인데 5분 실패율이 이미 0% 면(6배 · 2배 단계가 남아 있는 경우) 그 사실을 적고, 내릴지는 IC 가 정한다.

### 이 값이면 이쪽

| 3 · 4 단계에서 본 것 | 먼저 의심할 곳 | 확인 (반증부터) |
| --- | --- | --- |
| checkout 의 ERROR span 에 client `oteldemo.PaymentService/Charge` 가 있고, payment 서버 span ERROR 비율이 주문 실패율과 비슷함 | payment 가 요청을 받고 실패로 답한다 (플래그 `paymentFailure`, payment 배포) | 실패 트레이스의 첫 ERROR 가 payment `Charge` 인가. payment 로그의 사유. 플래그는 사람이 확인 |
| checkout 의 client `Charge` 는 ERROR 인데 payment 서버 span 이 없음(`NaN` · 결과에 없음) | payment 에 닿지 못한다 (플래그 `paymentUnreachable`, payment Pod 죽음 · 재시작) | payment Pod 상태(6 단계), 트레이스에 payment span 이 아예 없는가 |
| product-catalog ERROR 비율이 오르고 실패 트레이스의 첫 ERROR 가 `GetProduct` | product-catalog (플래그 `productCatalogFailure`, 직전 product-catalog 배포) | 특정 상품만 실패하는가. 7 단계의 배포 이력 |
| shipping p95 가 크게 오르고 주문 p95 도 함께 오름. ERROR 는 타임아웃 | shipping 지연 (플래그 `intlShippingSlowdown`) | 실패 트레이스에서 가장 긴 span 이 shipping 인가 |
| cart · currency ERROR 비율이 오름 | 그 서비스 | 첫 ERROR span, 그 서비스 Pod 상태 |
| `publish orders` ERROR 비율이 오름 | kafka (플래그 `kafkaQueueProblems`) | PlaceOrder 가 실제로 ERROR 로 끝나는가. kafka 이후는 비동기라 주문 실패와 무관할 수 있다 |
| 하위 서비스는 모두 0% 인데 PlaceOrder 만 ERROR | checkout 자체 (배포 · 설정 · 자원) | checkout 재시작 · 배포 이력, checkout 로그 |
| 모든 서비스가 함께 나빠짐 | 노드 · 네트워크 · 수집 | 1 단계 다시, 노드 상태, `/deploy-triage` |
| 실패율이 낮고(2 ~ 6%) `burn_rate="2"` 만 firing | 느린 누수 | 24시간 범위로 넓혀(이유를 먼저 말한다) 언제부터인지, 특정 상품 · 사용자만인지 |

플래그 이름은 `specs/observability.md` 8장의 호출 경로에 있는 것이다. 위 표의 "먼저 의심할 곳" 은 가설이다. 트레이스 · 로그로 확인하기 전에는 원인이라고 쓰지 않는다.

## 5. 흔한 함정

### 동시에 일어난 다른 문제

지난 장애 연습에서 결제가 실패하는 동안 email Pod 도 재시작하고 있었고, 두 사람이 email 을 원인으로 보고 20분을 썼다(`docs/requirements/incident.md` 배경).
6 단계에서 나온 재시작 · CrashLoop · 다른 알람은 아래 세 가지를 **모두** 통과해야 원인 후보로 올린다. 하나라도 어긋나면 "관련 없음" 으로 적고 그 근거를 남긴다.

1. **시각**: 그 문제가 시작된 시각이 주문 실패가 시작된 시각(2 단계)과 맞는가. 주문 실패보다 먼저 시작해 그동안 주문이 정상이었다면 원인이 아니다.
2. **경로**: 실패한 트레이스(4 단계)에서 **처음 ERROR 가 난 span** 이 그 서비스인가. 그 서비스의 span 이 실패 지점보다 뒤에 있거나 트레이스에 아예 없으면 원인이 아니다.
3. **비율**: 그 서비스의 ERROR 비율 · 재시작 횟수가 주문 실패율과 함께 움직이는가. 주문은 50% 실패하는데 그 서비스는 100% 죽어 있다면 설명이 맞지 않는다.

- 원인 후보는 **최소 두 개** 낸다. 지지하는 근거보다 반증을 먼저 찾는다.
- "관련 없음" 으로 적은 문제도 사라지는 것은 아니다. 주문 장애와 별개로 SEV3 · SEV4 로 따로 제안한다.

### 데이터 없음

- **빈 결과는 0 이 아니다.** 한 번도 실패하지 않은 `status_code="STATUS_CODE_ERROR"` 시계열은 아예 없다. 그래서 실패율 쿼리에 `or vector(0)` 이 있다. 분모까지 비면 "주문 없음 · 데이터 없음" 이다.
- **`NaN`** 은 분모가 0 이라는 뜻이다(그 서비스 호출이 없다). "에러 없음" 으로 읽지 않는다.
- **주문이 없으면 알람은 꺼진다.** 분모가 0 이면 알람 식이 비어 firing 하지 않는다. 알람이 해제됐다고 복구된 것이 아닐 수 있다. 해제 뒤에도 2 단계의 주문 건수를 본다.
- **Prometheus 재시작 직후**(저장이 emptyDir 라 이력이 사라진다)에는 긴 창이 짧은 이력만 봐서 세 단계가 몇 분 안에 함께 뜬다(`tests/alerts` 시나리오 ④).
- 메트릭 · 라벨 이름은 추측하지 않는다. 빈 결과가 나오면 `list_prometheus_metric_names` · `list_prometheus_label_values` 로 이름부터 확인한다.
- 조회 실패(연결 · 권한 · 타임아웃)는 "확인 필요" 다. "이상 없음" 으로 쓰지 않는다.

### 수치를 읽을 때

- **주문이 적다.** 기준선 처리량은 분당 약 3.5건이라 5분 창에 15건 안팎이다(`specs/observability.md` 10장). 실패 1건이 약 6% 다. 실패율은 항상 건수와 함께 적는다("12건 중 6건").
- span 메트릭은 1 ~ 2분 늦다. 방금 바뀐 것은 트레이스로 확인한다.
- p95 는 히스토그램 버킷 보간값이다. 버킷 경계(50 · 100 · 200 · 400 · 800 · 1000ms …)를 넘었는지로 읽는다.
- 연결을 열어 두는 스트림 span(flagd `EventStream` 등)은 지연 · 에러로 세지 않는다.

## 6. 복구 후보 (실행은 사람)

Claude 는 후보와 근거, 예상 영향, 되돌리는 방법을 정리해 보이기만 한다. **어느 것도 실행하지 않는다.** 복구 실행 경로와 승인 체계는 아직 정하지 않았다(다음 작업). 그때까지 실행과 승인은 모두 IC 가 한다.

| 원인 | 복구 후보 | 누가 실행 | 되돌리기 |
| --- | --- | --- | --- |
| 장애 주입 플래그가 켜져 있음 | `scenarios/flag.sh <플래그> off` | IC (사람) | 같은 명령으로 다시 켠다 |
| 플래그 파일이 꼬임 | `kubectl -n otel-demo-dev rollout restart deploy/flagd` (플래그 전체 초기화) | IC (사람) | 필요한 플래그를 다시 켠다 |
| 직전 배포 (values · 이미지) | revert PR. IC 가 요청하면 Claude 가 PR 을 만들고, 리뷰 · merge 는 사람이 한다. dev 는 merge 되면 Argo CD 가 자동 Sync 한다 | PR 작성: Claude(요청 시) · merge: 사람 | revert 를 다시 revert |
| 특정 Pod 가 죽어 있음 | `kubectl -n otel-demo-dev rollout restart deploy/<서비스>` | IC (사람) | — (원인이 남아 있으면 다시 죽는다. 원인을 먼저 본다) |
| 데이터 없음 (수집 파이프라인) | 주문 장애와 구분해 보고. Collector · 백엔드 상태는 `/deploy-triage` | IC (사람) | — |

복구 뒤 확인 (IC 가 종료를 선언하기 전에):

- 3장 2 단계의 5분 실패율이 기준선(0%)으로 돌아왔고 주문 건수가 0 이 아니다.
- 알람 해제: 14.4배 단계는 약 5분, 6배는 최대 30분, 2배는 최대 2시간 뒤. 남아 있는 단계는 짧은 창이 내려오는 중인지 확인한다.
- `tests/smoke.sh` · `tests/signals.sh` 통과 (사람이 실행).

## 7. 멈추고 IC 에게 물을 곳

Claude 는 아래에서 조사를 멈추고 "IC 가 정할 것" 목록으로 보인다. 답을 기다리는 동안에도 읽기 전용 조회는 계속한다.

- **장애 선언과 심각도 확정** — 첫 보고에서 제안만 한다.
- **플래그 상태** — "`scenarios/flag.sh --list` 결과를 알려 달라" 고 요청한다. 추측으로 "플래그가 켜져 있다" 고 쓰지 않는다.
- **복구 실행** — 6장의 후보 중 무엇을 할지. revert PR 이 필요하면 만들라는 요청을 받은 뒤에 만든다.
- **조회 범위를 24시간 넘게 넓혀야 할 때**, 또는 **대상 밖**(`otel-demo-prod`, 클러스터 밖)을 봐야 할 때.
- **30분이 지나도 원인 서비스를 못 좁혔을 때** — 지금까지 본 것 · 배제한 것 · 모르는 것을 정리하고 다음에 무엇을 볼지 묻는다.
- **증거가 서로 어긋날 때** — 단정하지 않고 "모름" 과 확인 방법을 적는다.
- **공지 · 종료 선언** — Claude 는 하지 않는다.

## 8. 보고 형식 (첫 보고와 10분마다의 갱신)

```
[OrderFailureRateHigh] 첫 보고 | 갱신 N — <KST 절대 시각>

영향 범위: 5분 주문 실패율 X% (N건 중 M건), <시작 시각 KST> 부터. p95 Yms. frontend 에서 본 주문 실패 Z건/분
심각도 제안: SEVn (임시) — <기준 한 줄>
알람 상태: burn_rate 14.4 / 6 / 2 = firing | pending | 없음
수집 상태: 정상 | <데이터 없음 · 전송 실패 · Prometheus 재시작>

원인 후보 (최소 두 개)
| 후보 | 근거 | 반증 · 아직 확인 못 한 것 | 확신 (높음 · 중간 · 낮음) |

같은 시각의 다른 문제
| 문제 | 관련 여부 | 근거 (시각 · 경로 · 비율) |

복구 후보 (실행하지 않음)
| 후보 | 예상 영향 | 되돌리기 | 누가 |

IC 가 정할 것
- <장애 선언 · 심각도 확정 · 플래그 확인 · 복구 선택 …>

모르는 것과 확인 방법
- <빈 결과 · 조회 실패 · 가정>

실행한 쿼리 (원문 · 시간 범위 KST · 데이터소스)
```

갱신할 때는 지난 보고에서 **바뀐 것**(새 증거, 배제한 후보, 바뀐 확신)을 맨 위에 적는다.

## 9. 장애가 끝난 뒤

- 이번에 막힌 곳(없던 쿼리, 틀린 판단 기준, 속은 함정)을 이 파일에 PR 로 반영한다.
- 타임라인 · 포스트모템의 형식과 위치는 아직 정하지 않았다(`docs/requirements/incident.md` 미정).
