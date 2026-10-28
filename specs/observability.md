# 작업 스펙: 쇼핑몰 dev 관측 체계

> 상태: 진행 중  (현재 작업이면 CLAUDE.md 에서 import 한다. 끝나면 "완료" 로 바꾸고 지우지 않는다)

> AI 에게 맡길 작업의 목적·범위·제약·완료 기준을 팀이 검토할 수 있게 적은 문서.
> 실제 값(SLO 수치, 담당자, 채널)은 사람이 채운다. 비어 있는 값은 Claude 가 추정하지 않고 질문한다.
> 저장소에 커밋하고, 바꿀 때는 PR 로 리뷰한다.
>
> 근거: `docs/requirements/observability.md`(팀 회의 요구사항), `specs/eks-demo.md`(환경), OTel Demo 차트 0.42.1 의 서비스 구성.

## 1. 목적

"결제(주문)가 지금 정상인가" 에 한 화면 · 한 질문으로 답할 수 있게 한다.
장애가 나면 메트릭 → 트레이스 → 로그를 trace_id 하나로 따라가 원인 서비스를 5분 안에 좁힌다.
AI(Claude)는 이 데이터를 **읽기 전용**으로 조회해 근거(쿼리 · 시간 범위 · 데이터소스)와 함께 답한다.

## 2. 환경

| 항목 | 값 |
| --- | --- |
| 클러스터 | `ai-devops-lab-dev` (specs/eks-demo.md 와 같다) |
| 대상 네임스페이스 | `otel-demo-dev` (prod 는 관측 스택 없음) |
| 관측 네임스페이스 | `observability` |
| 스택 | kube-prometheus-stack 92.10.0 · Loki 18.16.1 (앱 3.7) · Tempo 3.2.0 (앱 3.1), Collector 는 Demo 차트의 것 |
| 접속 | port-forward. Grafana `svc/kps-grafana 3000:80`, 조회 스크립트는 API 서버 service proxy |
| 실행 전 확인 | `kubectl config current-context` → `ai-devops-lab-dev`, `kubectl get ns observability` |

## 3. 요청 경로와 수집 지점

결제 여정: 브라우저 → frontend-proxy(Envoy) → frontend → checkout → cart · product-catalog · currency · shipping(quote) · **payment** · email, 주문 이벤트 → kafka → accounting · fraud-detection

| 신호 | 어디서 | 무엇으로 | 저장 |
| --- | --- | --- | --- |
| 메트릭 | 각 서비스 SDK, Collector span_metrics, kube-state-metrics, node-exporter | OTLP → Prometheus, 스크레이프 | Prometheus (2일) |
| 트레이스 | 각 서비스 SDK (서버 · 클라이언트 span) | OTLP → Tempo | Tempo (24시간) |
| 로그 | 각 서비스 SDK 로그 (trace_id · span_id 포함) | OTLP → Loki | Loki (48시간) |

## 4. 운영 질문 (대시보드 · 알람 · AI 조회의 출발점)

1. 지금 주문이 성공하고 있나? 실패율은?
2. 주문이 느린가? p95 는?
3. 실패한다면 어느 하위 서비스에서?
4. 언제부터 그랬나? 그 직전에 무엇이 바뀌었나 (배포 · 플래그)?
5. 재시작하거나 Ready 가 아닌 Pod 가 있나?
6. 관측 파이프라인 자체는 정상인가 (Collector 드롭, 수집 중단)?

## 5. SLI · SLO

| 이름 | SLI | SLO | 근거 메트릭 |
| --- | --- | --- | --- |
| 주문 가용성 | PlaceOrder 서버 span 중 에러가 아닌 비율 | 99% (30일) | `traces_span_metrics_calls_total{service_name="checkout", span_name="oteldemo.CheckoutService/PlaceOrder", span_kind="SPAN_KIND_SERVER"}` |
| 주문 지연 | PlaceOrder p95 | 1초 미만 (대시보드 관찰, 알람 없음) | `traces_span_metrics_duration_milliseconds_bucket{...}` |

SLO 수치는 결제 서비스 오너가 정한 값이다 (docs/requirements/observability.md). 7장 기준선으로 현실성만 확인하고, 못 미치면 목표를 바꾸기 전에 원인부터 본다.

## 6. 알람 계약

| 등급 | 조건 | 어디로 | 누가 | 응답 | Runbook |
| --- | --- | --- | --- | --- | --- |
| page | 주문 가용성 burn rate 14.4 초과 (1h · 5m 창 모두), 2분 지속 | Slack #alerts + 담당자 멘션 | 온콜 (@TeddySB2) | 15분 안에 확인 | docs/runbooks/checkout-errors.md |
| ticket | 주문 가용성 burn rate 6 초과 (6h · 30m 창 모두), 15분 지속 | Slack #alerts | 서비스 오너 | 다음 업무일 | 같은 문서 |
| 기록 | 그 밖의 원인형 지표 (CPU, 재시작 1회 등) | 대시보드 · 일일 점검 | — | 일일 점검에서 확인 | — |

- 원인 후보(CPU, 메모리)로 사람을 깨우지 않는다. 사용자 영향(주문 실패)으로 깨운다.
- 모든 page · ticket 알람에는 `runbook_url` 과 `summary` 가 있다.
- 알람 룰은 `gitops/manifests/observability/rules/` 에 두고 `./tests/promtool.sh` 를 통과해야 merge 한다.

## 7. 관측 기준선 (1-3 에서 측정, `./tests/signals.sh`)

| 항목 | 값 | 측정 시각 |
| --- | --- | --- |
| 주문 요청 (load-generator 기준) | 리허설에서 채운다 | |
| 주문 실패율 (플래그 off) | 리허설에서 채운다 | |
| 주문 p95 | 리허설에서 채운다 | |
| trace_id 로 세 신호 연결 | PASS / FAIL | |

## 8. 범위

포함
- 관측 스택 설치와 Collector 연결 (GitOps)
- 결제 여정 대시보드, 주문 SLO 알람, Alertmanager → Slack
- Grafana MCP(읽기 전용) · Slack MCP 연결, 관측 조회 Skill, 일일 헬스체크 Skill

제외
- prod 관측 (별도 클러스터 · 별도 스택이 필요), 장기 보존(S3), 외부 공개
- 알람의 자동 조치 (Part 5 이후, 사람 승인 경로로만)

## 9. 제약과 승인

- 관측 스택 변경도 Git PR 로만 한다. Grafana UI · MCP 로 대시보드 · 알람을 바꾸지 않는다.
- PV 없음: Prometheus · Loki · Tempo · Grafana 는 재시작하면 데이터가 사라진다 (실습 환경 한정, 운영은 PVC 또는 오브젝트 스토리지).
- Secret(Grafana admin, Slack 웹훅, 서비스 계정 토큰)은 사람이 클러스터 · 환경 변수에 직접 넣는다. Git · 대화에 남기지 않는다.
- 노드 추가 없이 m6i.xlarge 2대 안에서 돌린다. 넘치면 보존 기간 · 리소스를 줄이는 PR 을 먼저 낸다.

## 10. 완료 증거

| 확인 | 기준 (명령과 기대값) |
| --- | --- |
| 스택 | Argo CD `obs-*` 앱 4개 Synced · Healthy |
| 신호 연결 | `./tests/signals.sh` 가 PASS (메트릭 · 로그 · 트레이스 · exemplar) |
| 알람 | `./tests/promtool.sh` 통과, `paymentFailure 50%` 주입 시 page 발화 → Slack 도착, off 하면 해제 |
| AI 조회 | Claude 답변에 쿼리 · 시간 범위 · 데이터소스가 붙어 있고, 원본 패널 값과 같다 |
| 일일 점검 | `/daily-health` 결과가 #ops-daily 에 올라가고, 조회 실패 항목은 "확인 필요" 로 표시된다 |

## 11. 승인자

| 변경 | 승인자 |
| --- | --- |
| SLO 수치 · 알람 계약 | 서비스 오너 (@TeddySB2) |
| 관측 스택 values | 플랫폼팀 (@TeddySB2) |
| MCP 권한 (Grafana · Slack) | 플랫폼팀 리드 (@TeddySB2) |
