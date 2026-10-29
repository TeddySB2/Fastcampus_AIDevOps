# 작업 스펙: 결제 여정 관측 체계 (dev)

> 상태: 진행 중  (현재 작업이면 CLAUDE.md 에서 import 한다. 끝나면 "완료" 로 바꾸고 지우지 않는다)

> AI 에게 맡길 작업의 목적·범위·제약·완료 기준을 팀이 검토할 수 있게 적은 문서.
> 실제 값(계정, 승인자, 예산)은 사람이 채운다. 비어 있는 값은 Claude 가 추정하지 않고 질문한다.
> 저장소에 커밋하고, 바꿀 때는 PR 로 리뷰한다.
> CLAUDE.md 의 팀 규칙 안에서 쓴다. 규칙을 벗어나는 결정은 "4. 제약과 승인" 에 예외로 적고 승인자를 둔다.
>
> 근거: `docs/requirements/observability.md`(플랫폼팀 · 결제 서비스 오너 회의), `specs/eks-demo.md`(환경), `CLAUDE.md`(팀 규칙).
> 호출 경로 · 플래그 · 수집 파이프라인은 OpenTelemetry Demo 차트 0.42.1 의 values 와 렌더링 결과에서 확인했다
> (`helm show values open-telemetry/opentelemetry-demo --version 0.42.1`). "가정" 으로 표시한 값은 구현 PR 에서 실제 수집 데이터로 확인하고 고친다.
> "미정" 은 다음 회의 후 PR 로 채운다.

## 1. 목적

"결제(주문)가 지금 되는가 · 얼마나 느린가 · 어디서 깨졌는가" 를 팀이 같은 화면(Grafana) · 같은 절차(이 스펙의 운영 질문)로 답한다.
장애가 나면 메트릭 → 트레이스 → 로그를 trace_id 하나로 따라가 원인 서비스를 **5분 안에** 좁힌다.
스택이 떠 있는 것은 완료가 아니다. 주문 요청의 세 신호가 실제로 들어오고 trace_id 로 이어져야 "관측된다" 고 본다.

## 2. 환경

`specs/eks-demo.md` 2장의 환경을 그대로 쓴다. 이 작업에서 더해지는 것만 적는다.

| 항목 | 값 |
| --- | --- |
| AWS 계정 | dev 전용 계정 (`specs/eks-demo.md` 와 같다. 계정 ID 는 저장소에 적지 않는다) |
| 리전 | ap-northeast-2 |
| 클러스터 | `ai-devops-lab-dev` (Kubernetes 1.36, m6i.xlarge 2대 · 최대 4대) |
| 네임스페이스 | 관측 스택: `observability` (신규, Argo CD 자동 Sync)<br>관측 대상: `otel-demo-dev` 만. `otel-demo-prod` 에는 관측 스택을 두지 않고 신호도 보내지 않는다 |
| 관측 스택 | 메트릭 · 알람 · 대시보드: kube-prometheus-stack (Prometheus · Alertmanager · Grafana · kube-state-metrics)<br>로그: Loki, 트레이스: Tempo<br>수집: Demo 차트의 OTel Collector(daemonset, `otel-collector`)를 그대로 쓰고 exporter 만 바꾼다 |
| 차트 출처 | kube-prometheus-stack: prometheus-community. Loki · Tempo: grafana-community. **버전은 구현 PR 에서 고정한다(스펙에 적지 않는다)** |
| 보존 | 메트릭 2일, 로그 48시간, 트레이스 24시간. 저장은 emptyDir (PVC 없음, 재시작 시 소실) |
| 접속 | port-forward 로만. Grafana 는 로그인 필수(Secret `observability/grafana-admin`, 사람이 만든다) |
| 실행 전 확인 | `specs/eks-demo.md` 의 세 가지 확인에 더해<br>`kubectl get ns observability` → 있음(배포 후)<br>`argocd app list -p observability` → 이 작업의 Application 만 보임 |

## 3. 범위

포함
- `observability` 네임스페이스에 kube-prometheus-stack · Loki · Tempo 를 Argo CD 로 배포. 별도 AppProject(`observability`)를 두어 기존 `otel-demo` 프로젝트 권한을 넓히지 않는다 — `gitops/apps`
- Demo Collector 의 exporter 변경: traces → Tempo, metrics → Prometheus(kube-prometheus-stack), logs → Loki. span_metrics 커넥터는 유지 — `gitops/values/otel-demo`
- Demo 내장 백엔드(jaeger · prometheus · grafana · opensearch)를 dev 에서 끈다 — `gitops/values/otel-demo` (dev 값에만)
- "결제 여정" Grafana 대시보드 1개를 Git 에 코드로 둔다 (9장 SLI 와 7장 운영 질문 A 를 한 화면에) — `gitops/manifests/observability`
- `tests/signals.sh`: 주문 요청의 메트릭 · 트레이스 · 로그가 들어오고 trace_id 로 이어지는지 확인 (5장)
- 스택이 안정된 뒤 평소 수치(기준선)를 재서 10장에 적는다
- Claude 의 읽기 전용 조회 경로(port-forward 된 Prometheus · Loki · Tempo HTTP API)와 답에 붙일 근거 형식 (7장 끝)

제외 (별도 요구사항 필요)
- 알람 룰 · 기록(recording) 규칙 · 알람 등급 · 수신처 (알람 정책 회의 뒤 별도 작업). Alertmanager 는 설치만 하고 라우팅은 비워 둔다
- infra(Terraform) 변경. EBS CSI · PVC · 오브젝트 스토리지 도입
- 외부 공개(Ingress · 공개 LB), Grafana SSO
- prod(`otel-demo-prod`) 관측
- 새 검증 스크립트(`tests/signals.sh`) 외의 테스트 추가, 애플리케이션 코드(계측) 수정
- Demo 의 다른 보조 백엔드(프로파일링 `firepit`, `opamp-server` 등) 처리. 요구사항에 없다. 자원이 부족하면 구현 PR 에서 끄기를 제안하고 승인받는다

## 4. 제약과 승인

- 모든 변경은 Git 브랜치 → PR → 사람 리뷰. Claude 는 읽기 전용으로 조회 · 분석 · PR 작성까지만 한다. 대시보드는 UI 에서 만든 것을 인정하지 않는다(Git 의 JSON/ConfigMap 만).
- 자원: 노드를 늘리지 않는다(m6i.xlarge 2대 유지). Demo 내장 백엔드를 끈 만큼 안에서 해결한다. 구현 PR 에 관측 스택 전체의 requests/limits 합계와 노드 여유를 적는다.
- 저장: PVC 를 쓰지 않는다(클러스터에 EBS CSI 없음). 모든 백엔드는 emptyDir. 완료 증거에 `kubectl get pvc -A` 가 비어 있음을 포함한다.
- 보존: 메트릭 2일 · 로그 48시간 · 트레이스 24시간을 넘기지 않는다(emptyDir 용량 보호).
- 민감 정보: Collector 의 기존 처리기(`transform/redact_sensitive_data`, `redaction` — 카드번호 마스킹 · CVV/PIN 삭제 · 이메일 해시)를 **제거하거나 약화하지 않는다**. 로그 · 트레이스에 카드번호 원문이 남으면 실패로 본다.
- 비용: 월 예산 상한과 알림 대상은 **미정**(`specs/eks-demo.md` 와 같다). 이 작업은 노드를 늘리지 않으므로 추가 AWS 비용은 없다고 보되, 승인자가 확인한다.
- `expires` 태그 · 7일 내 destroy 는 `specs/eks-demo.md` 를 따른다. 관측 스택은 클러스터와 함께 사라진다.
- **예외** (팀 규칙 "반드시 지킬 것" 1 번): Grafana admin 비밀번호는 사람이 `kubectl create secret generic grafana-admin -n observability …` 로 직접 만든다. Git 에는 Secret 이름만 적는다. 승인자: @TeddySB2
- **예외** (팀 규칙 1 · 2 번): 장애 주입(`scenarios/flag.sh paymentFailure …` 등)은 사람이 직접 실행한다. Claude 는 실행하지 않고, 주입 전후의 관측 데이터를 읽기 전용으로 조회해 원인을 좁힌다. 승인자: @TeddySB2

## 5. 완료 증거

| 확인 | 기준 (명령과 기대값) |
| --- | --- |
| 배포 | `argocd app get kube-prometheus-stack`, `argocd app get loki`, `argocd app get tempo` → 셋 다 Sync `Synced`, Health `Healthy` (AppProject `observability`, `gitops/apps`)<br>`kubectl -n observability get pod` → 전부 `Running`, RESTARTS 가 10분간 증가하지 않음<br>`kubectl -n otel-demo-dev get deploy jaeger prometheus grafana opensearch` → 넷 다 `NotFound` (내장 백엔드 꺼짐)<br>`kubectl get pvc -A` → 빈 결과<br>`argocd app get otel-demo-dev` → 여전히 `Synced` · `Healthy`, `tests/smoke.sh` 통과 (Demo 를 깨뜨리지 않았다) |
| 신호 (관측된다) | `tests/signals.sh` 통과. load-generator 가 계속 만드는 주문을 쓴다. 각 단계는 port-forward 된 HTTP API 로 확인하고 exit code 로 판정한다:<br>1. **메트릭**: Prometheus 에 checkout `PlaceOrder` 서버 span 의 호출 수(9장 SLI 분모)가 있고 5분 전보다 늘어남<br>2. **트레이스**: Tempo 에서 최근 15분 `service.name=checkout` · span 이름 `PlaceOrder` 로 검색 → 1건 이상. 그 트레이스에 `frontend`, `checkout`, `payment` 서비스의 span 이 모두 들어 있음<br>3. **로그**: 2 에서 얻은 trace_id 로 Loki 를 검색(`checkout` 또는 `payment` 서비스) → 1줄 이상. 같은 trace_id 로 메트릭 → 트레이스 → 로그가 이어짐<br>4. **민감 정보**: 2 의 트레이스 속성과 3 의 로그에 `demo.payment.card_number` 원문(`****-****-****-` 로 시작하지 않는 16자리)이 없음<br>5. **Grafana**: 인증 없이 `GET /api/dashboards/home` → `401`. 로그인 후 "결제 여정" 대시보드가 Git 에서 provisioning 됨(`kubectl -n observability get cm -l grafana_dashboard=1` 에 해당 ConfigMap 존재)<br>6. **파이프라인**: Collector 자체 메트릭에서 exporter 전송 실패가 10분간 0 (7장 C 의 지표) |
| 기준선 | 신호 확인 뒤 장애 없는 상태에서 30분 이상 측정해 10장에 적는다. 측정값 · 쿼리 · 시간 범위를 함께 남긴다 |
| 실패 대응 (사람이 주입) | 승인자가 `scenarios/flag.sh paymentFailure <variant>` 실행 →<br>5분 안에 대시보드의 주문 실패율이 오르고, Tempo 에서 `payment` 의 `Charge` span 이 `ERROR` 인 트레이스가 보이고, 그 trace_id 로 payment 로그가 나온다<br>Claude 는 읽기 전용 조회만으로 "payment" 를 원인 서비스로 지목하고 쿼리 · 시간 범위 · 데이터소스를 근거로 붙인다<br>`scenarios/flag.sh paymentFailure off` 뒤 5분 안에 실패율이 기준선으로 돌아오고 `tests/smoke.sh` · `tests/signals.sh` 가 다시 통과<br>관측 스택 자체가 깨지면 revert PR 로 되돌리고 위 "배포" · "신호" 를 다시 통과 |
| 종료 | `specs/eks-demo.md` 의 종료 기준을 따른다. 관측 스택은 PVC · LB 를 만들지 않으므로 destroy 뒤 잔여 리소스를 더하지 않는다 |

## 6. 승인자

| 변경 | 승인자 |
| --- | --- |
| 스펙 · 팀 규칙 · `gitops/apps` 변경 (CODEOWNERS) | @TeddySB2 |
| Grafana admin Secret 직접 생성 (예외) | @TeddySB2 |
| 장애 주입 실행 (예외) | @TeddySB2 |
| Demo 보조 백엔드(firepit 등) 끄기 | @TeddySB2 |
| 알람 등급 · 수신처 · 알람 지표 | 미정 (알람 정책 회의) |
| 월 예산 상한 · 알림 대상 | 미정 |
| Claude 의 Slack 사용 여부 · 범위 | 미정 |

## 7. 먼저 답할 운영 질문

대시보드 · (추후) 알람 · Claude 조회의 출발점. 각 질문은 "어느 신호 · 어느 데이터소스로 답하는가" 를 같이 적는다.
메트릭 이름은 구현 PR 에서 실제 수집된 이름으로 고친다(가정 표시).

**A. 결제 여정 (대시보드 1면)**

| 질문 | 신호 · 데이터소스 |
| --- | --- |
| A1. 지금 주문이 되는가 | 최근 5분 주문 성공률(9장 SLI-1) — Prometheus |
| A2. 얼마나 느린가 | 최근 5분 주문 p95 (9장 SLI-2), 목표선 1초 — Prometheus |
| A3. 어디서 깨졌는가 | 8장 호출 경로의 서비스별 ERROR span 비율과 p95 (payment · cart · product-catalog · currency · shipping · email · kafka) — Prometheus(span_metrics). 하나 골라 Tempo 로 이동 |
| A4. 사용자 탓인가 시스템 탓인가 | frontend `POST /api/checkout` 서버 span 의 ERROR(=5xx) 와 그 외(2xx · 4xx)를 나눠 본다 — Prometheus(span_metrics). 5xx 만 SLI 실패다. **한계**: span_metrics 기본 디멘션에 HTTP 상태 코드가 없고 frontend 의 `http_server_request_duration_seconds` 에는 route 라벨이 없어 4xx 를 2xx 와 가르지 못한다. 가르려면 커넥터에 `http.response.status_code` 디멘션을 더해야 한다(8장 "그대로 유지" 와 충돌 → 별도 승인) |
| A5. 주문이 끝까지 처리됐는가 | kafka `orders` 토픽 적재(lag)와 accounting · fraud-detection 의 소비 — Prometheus(Collector `kafkametrics` 수신기) |
| A6. 결제 실패 플래그가 켜져 있나 | `scenarios/flag.sh --list` (사람). flagd 상태는 메트릭으로 안 나오므로 조회 절차에 넣는다 |

**B. 아침 점검 (매일 같은 순서)**

| 질문 | 신호 · 데이터소스 |
| --- | --- |
| B1. 지난 24시간 재시작한 Pod 는 | `kube_pod_container_status_restarts_total` 증가분 상위 — kube-state-metrics |
| B2. NotReady 노드 · Pending Pod · OOMKilled 가 있나 | `kube_node_status_condition`, `kube_pod_status_phase`, `kube_pod_container_status_last_terminated_reason` — kube-state-metrics |
| B3. 노드 CPU · 메모리 여유와 HPA 상태 | node-exporter, `kube_horizontalpodautoscaler_status_current_replicas` — Prometheus |
| B4. 주문 실패율 · p95 가 기준선(10장) 안인가 | A1 · A2 를 24시간 범위로 |

**C. 수집 파이프라인 자체 (데이터가 없을 때 먼저 의심)**

| 질문 | 신호 · 데이터소스 |
| --- | --- |
| C1. Collector 가 받고 내보내는가 | `otelcol_exporter_sent_{spans,metric_points,log_records}_total`, `otelcol_exporter_send_failed_{spans,metric_points,log_records}_total`(라벨 `exporter`), `otelcol_exporter_queue_size` — Collector(contrib 0.160.0) 자체 메트릭. 이름은 Demo 내장 Prometheus 에서 확인했다(구현 PR) |
| C2. Prometheus · Loki · Tempo 가 받고 있는가 | 각 백엔드의 ingest 메트릭과 Prometheus `up` — Prometheus |
| C3. 마지막 데이터가 언제인가 | A1 분모의 최신 샘플 시각, Tempo 최근 트레이스 시각, Loki 최근 로그 시각 — 각 API |

**D. 언제부터 · 직전에 무엇이 바뀌었나**

| 질문 | 신호 · 데이터소스 |
| --- | --- |
| D1. 언제부터 나빠졌나 | A1 · A2 그래프의 변곡점 시각 |
| D2. 그 직전 배포가 있었나 | `argocd app history otel-demo-dev`, `kubectl -n otel-demo-dev rollout history deploy/<svc>`, `kube_deployment_status_observed_generation` 변화 |
| D3. 플래그가 바뀌었나 | A6. flagd 는 emptyDir 파일이라 Git 에 흔적이 없다. 주입한 사람이 시각과 플래그를 PR 또는 이슈에 남긴다 |
| D4. 노드 · HPA 가 움직였나 | `kube_node_created`, HPA 이벤트, `kubectl get events -n otel-demo-dev --sort-by=.lastTimestamp` |

**Claude 의 조회 규칙**
- 경로: port-forward 된 Prometheus · Loki · Tempo HTTP API 를 읽기 전용으로 쓴다. Grafana API 토큰 발급 여부는 미정.
- 순서: A1/A2(메트릭) → A3 으로 서비스 좁히기 → Tempo 에서 ERROR span 과 trace_id → 그 trace_id 로 Loki. 항상 C 를 먼저 배제한다(데이터가 없는 것과 장애를 구분).
- 답 형식: 결론 한 줄 + 근거(쿼리 원문, 시간 범위, 데이터소스, 결과 수치). 근거 없는 추정은 "가정" 이라고 쓴다.

## 8. 결제 여정의 호출 경로와 수집 지점

차트 0.42.1 의 `components.checkout.env`(CART_ADDR · CURRENCY_ADDR · EMAIL_ADDR · PAYMENT_ADDR · PRODUCT_CATALOG_ADDR · SHIPPING_ADDR · KAFKA_ADDR) 와 `components.frontend.env`(CHECKOUT_ADDR) 에서 확인한 경로다.
span 이름은 구현 PR 에서 Demo 내장 Prometheus 의 span_metrics(`traces_span_metrics_calls_total` 의 `span_name`)로 확인했다.
서버 span 이름이 아래 그림과 다른 것: cart `POST /oteldemo.CartService/GetCart` · `POST /oteldemo.CartService/EmptyCart`, shipping `POST /get-quote` · `POST /ship-order`, email `POST /send_order_confirmation`, kafka 적재는 checkout 의 producer span `publish orders`.
checkout `oteldemo.CheckoutService/PlaceOrder`, payment `oteldemo.PaymentService/Charge`, frontend `POST /api/checkout` 은 그림과 같다.

```
사용자 / load-generator (Locust, LOCUST_HOST=http://frontend-proxy:8080)
  └─ frontend-proxy (Envoy :8080)                         HTTP, 접근 로그
      └─ frontend (Next.js)  POST /api/checkout            HTTP 서버 span  ← A4 (4xx/5xx 구분)
          └─ checkout (Go)   oteldemo.CheckoutService/PlaceOrder   gRPC 서버 span  ← SLI-1 · SLI-2 측정점
              ├─ cart              GetCart → (끝에) EmptyCart        gRPC
              ├─ product-catalog   GetProduct (상품마다)             gRPC   ← productCatalogFailure
              ├─ currency          Convert                            gRPC
              ├─ shipping          GetQuote → ShipOrder (HTTP)        HTTP   ← intlShippingSlowdown
              ├─ payment           oteldemo.PaymentService/Charge    gRPC   ← paymentFailure · paymentUnreachable
              ├─ email             SendOrderConfirmation (HTTP)       HTTP   ← emailMemoryLeak
              └─ kafka  topic orders  (produce)                       ← kafkaQueueProblems
                  ├─ accounting       (consume, 비동기)
                  └─ fraud-detection  (consume, 비동기)
```

- 동기 경로(frontend → checkout → 하위 6개)가 주문 성공 · 지연을 결정한다. kafka 이후는 비동기라 SLI 에 넣지 않고 A5 로 따로 본다.
- checkout · payment 는 차트에서 `service.criticality=critical` 로 표시된 서비스다(`OTEL_RESOURCE_ATTRIBUTES_EXTRA`). 대시보드에서 이 둘을 맨 위에 둔다.
- 장바구니 단계(상품 조회 · 담기)는 `tests/smoke.sh` 가 이미 검사한다. 이 스펙은 그 다음 단계인 주문 확정을 다룬다.

**신호별 수집 지점** (모두 Demo Collector `otel-collector` 를 거친다. 애플리케이션은 이미 OTLP 로 보내고 있어 코드 수정이 없다)

| 신호 | 어디서 나오나 | Collector 처리 | 보내는 곳 (변경 후) |
| --- | --- | --- | --- |
| 트레이스 | 각 서비스 SDK → OTLP(4317/4318) | `transform/sanitize_spans` · `transform/redact_sensitive_data` · `redaction` 유지 | Tempo (지금은 jaeger) |
| 메트릭 (앱) | 각 서비스 SDK → OTLP, Collector `kafkametrics` · `prometheus/ad` 수신기 | 그대로 | Prometheus (지금은 내장 prometheus 의 OTLP 수신) |
| 메트릭 (span 기반) | Collector `span_metrics` 커넥터가 트레이스에서 생성. 디멘션 service.name · span.name · span.kind · status.code (기본값, 라벨 `service_name` · `span_name` · `span_kind` · `status_code` 로 확인) | 그대로 유지. SLI 의 원천 | Prometheus |
| 메트릭 (클러스터) | kube-state-metrics · node-exporter · kubelet (kube-prometheus-stack) | — | Prometheus |
| 로그 | 각 서비스 SDK → OTLP 로그(trace_id · span_id 포함) | `transform/sanitize_logs` 유지 | Loki (지금은 opensearch) |

Collector 의 Prometheus 전송 방식은 OTLP 수신(`otlp_http/prometheus` → kube-prometheus-stack Prometheus 의 `enableOTLPReceiver`, Demo 내장 prometheus 와 같은 `promote_resource_attributes` 목록)이다.
span_metrics 메트릭 이름은 `traces_span_metrics_calls_total` · `traces_span_metrics_duration_milliseconds_bucket`(라벨 `service_name` · `span_name` · `span_kind` · `status_code`)로 Demo 내장 Prometheus 에서 확인했다(구현 PR). 새 Prometheus 도 같은 기본 번역 규칙을 쓰므로 9장 쿼리를 그대로 쓴다.

## 9. SLI 정의 (목표치를 재는 방법)

측정점은 **checkout 서비스의 `oteldemo.CheckoutService/PlaceOrder` 서버 span** 하나다. frontend 가 아닌 이유: Next.js 라우트 span 이름은 계측 버전에 따라 바뀌지만 gRPC 메서드 이름은 proto 에 고정돼 있고, 결제 실패를 가장 가까이서 본다. frontend 의 `POST /api/checkout` 5xx 는 보조 지표(A4)로 함께 본다.

| SLI | 정의 | 목표 (결제 서비스 오너 합의) |
| --- | --- | --- |
| SLI-1 주문 가용성 | 분모: `service.name="checkout"`, `span.name="oteldemo.CheckoutService/PlaceOrder"`, `span.kind="SPAN_KIND_SERVER"` 인 span 수<br>분자: 그 중 `status.code != "STATUS_CODE_ERROR"` 인 span 수<br>실패로 보는 것: checkout 이 PlaceOrder 를 ERROR 로 끝낸 모든 경우(payment 거절 · 하위 서비스 불가 · 타임아웃). 사용자 입력 오류로 frontend 가 4xx 를 돌려주고 checkout 까지 오지 않은 요청은 분모에 들어가지 않는다 | 30일 창 99% (dev 보존이 2일이라 30일은 못 잰다. 대시보드는 5분 · 1시간 · 24시간 창을 보이고, 30일은 목표 정의로만 둔다) |
| SLI-2 주문 지연 | 같은 span 의 duration 히스토그램에서 p95. 성공 · 실패를 가르지 않는다(실패도 사용자가 기다린 시간이다) | p95 1초 미만 (대시보드로만 본다. 알람은 걸지 않는다) |

- 쿼리(이름은 8장 끝에서 확인. 대시보드 `gitops/manifests/observability/payment-journey-dashboard.yaml` 과 `tests/signals.sh` 가 이 쿼리를 쓴다):
  - SLI-1 = `1 - sum(rate(traces_span_metrics_calls_total{service_name="checkout", span_name="oteldemo.CheckoutService/PlaceOrder", span_kind="SPAN_KIND_SERVER", status_code="STATUS_CODE_ERROR"}[5m])) / sum(rate(traces_span_metrics_calls_total{service_name="checkout", span_name="oteldemo.CheckoutService/PlaceOrder", span_kind="SPAN_KIND_SERVER"}[5m]))`
  - SLI-2 = `histogram_quantile(0.95, sum by (le) (rate(traces_span_metrics_duration_milliseconds_bucket{service_name="checkout", span_name="oteldemo.CheckoutService/PlaceOrder", span_kind="SPAN_KIND_SERVER"}[5m])))`
- span_metrics 기본 히스토그램 버킷에 1초 경계(`le="1000"`)가 있음을 Demo 내장 Prometheus 에서 확인했다(구현 PR). 버킷: 2 · 4 · 6 · 8 · 10 · 50 · 100 · 200 · 400 · 800 · 1000 · 1400 · 2000 · 5000 · 10000 · 15000 ms.
- 트래픽: load-generator 가 5명(`LOCUST_USERS=5`)으로 주문을 계속 만든다. 분모가 5분에 0 이면 "주문 없음" 으로 표시하고 가용성을 100% 로 그리지 않는다.

## 10. 기준선 (측정 후 채운다)

스택을 올리고 `tests/signals.sh` 가 통과한 뒤, 장애 주입이 없는 상태에서 30분 이상 재서 적는다. 기준선이 목표에 못 미치면 목표를 바꾸기 전에 원인부터 본다.

| 항목 | 값 | 측정 | 쿼리 · 시간 범위 · 데이터소스 |
| --- | --- | --- | --- |
| 주문 실패율 (SLI-1 의 1 − 값) | 미측정 | 날짜 · 측정자 | |
| 주문 p95 (SLI-2) | 미측정 | | |
| 주문 처리량 (PlaceOrder/분) | 미측정 | | |
| 하위 서비스별 p95 (payment · cart · product-catalog · currency · shipping · email) | 미측정 | | |
| 관측 스택 자원 (requests 합계 · 노드 여유) | 미측정 | | `kubectl top node`, `kubectl -n observability top pod` |

## 11. 구현 위치 (디렉터리 수준)

파일 이름 · values 키 · 차트 버전은 구현 PR 에서 정한다. 차트 값의 키는 추측하지 않고 각 차트의 values.yaml 에서 확인한다(`gitops/CLAUDE.md`).

| 무엇 | 어디 | 관리 주체 |
| --- | --- | --- |
| AppProject `observability`, kube-prometheus-stack · Loki · Tempo Application | `gitops/apps` | GitOps (Argo CD). CODEOWNERS 승인 |
| 세 차트의 values (보존 기간 · emptyDir · Grafana 로그인 · 데이터소스 provisioning) | `gitops/values/observability` | GitOps |
| 결제 여정 대시보드(JSON ConfigMap), 추후 알람 룰 | `gitops/manifests/observability` | GitOps |
| Demo Collector exporter 변경, 내장 백엔드 끄기 | `gitops/values/otel-demo` (dev 값. prod 값은 건드리지 않는다) | GitOps |
| 신호 검증 스크립트 | `tests/signals.sh` | 저장소 |
| Grafana admin Secret | 클러스터 `observability/grafana-admin` | 사람 (예외, 4장) |

구현 PR 의 검증(팀 규칙 완료 조건): YAML 파싱, 세 차트와 Demo 차트의 `helm template` 렌더링, `kubeconform`. Demo 렌더링 명령은 `gitops/CLAUDE.md` 의 것을 쓴다.
