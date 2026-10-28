---
name: obs-ask
description: 운영 질문("결제 에러 언제부터 늘었어?", "제일 느린 API 는?", "재시작한 Pod 있어?")을 Grafana MCP 로 PromQL · LogQL · TraceQL 조회해 근거와 함께 답한다. 읽기 전용. 대시보드 · 알람은 바꾸지 않는다.
---

# 관측 데이터에 질문하기 (읽기 전용)

목표는 "그럴듯한 답" 이 아니라 **누가 다시 돌려도 같은 결과가 나오는 쿼리와 그 결과** 다.

## 0. 질문을 쿼리 조건으로 바꾼다

- 대상 서비스(`service_name`), 지표(에러율 · 지연 · 요청 수 · 재시작), 시간 범위를 정한다.
- 시간 범위가 없으면 최근 1시간. 시각은 KST 절대 시각으로 적는다 (예: 10/20 14:00~15:00).
- 결제 여정의 SLI 는 `specs/observability.md` 5장의 메트릭을 그대로 쓴다.

## 1. 이름을 먼저 확인한다 (추측 금지)

1. `list_datasources` — 데이터소스 uid (prometheus · loki · tempo)
2. `list_prometheus_metric_names` (regex 로 좁혀서) — 실제 메트릭 이름
3. `list_prometheus_label_values` — `service_name`, `span_name`, `status_code` 의 실제 값
4. 로그는 `list_loki_label_names` → `service_name` 이 있는지

## 2. 조회

| 질문 | 먼저 볼 것 |
| --- | --- |
| 에러가 늘었나 · 언제부터 | span metrics 의 `status_code="STATUS_CODE_ERROR"` 비율, 1분 간격 range query 로 처음 넘은 시각 |
| 느린 API | `traces_span_metrics_duration_milliseconds_bucket` 의 p95 를 `span_name` 별 topk |
| 재시작 · NotReady Pod | `kube_pod_container_status_restarts_total` 증가분, `kube_pod_status_ready{condition="false"}` |
| 원인 서비스 | 같은 시간대 `service_name` 별 에러 span, 그다음 Loki `{service_name="…"} \| detected_level="error"` |
| 한 건 따라가기 | 에러 로그의 `trace_id` → `get_tempo_trace` |

- 결과가 비면 1번으로 돌아가 이름을 다시 확인한다. 그래도 비면 "데이터 없음" 이라고 쓴다. 0 과 "없음" 을 구분한다.
- 큰 범위의 로그 조회는 `query_loki_stats` 로 크기부터 본다.

## 3. 답 형식

```
### 답
<한두 문장. 숫자와 시각>

### 근거
| 쿼리 | 데이터소스 | 시간 범위 (KST) | 결과 |
| --- | --- | --- | --- |

### 확인하지 못한 것
- <빈 결과, 조회 실패, 가정>
```

- 대시보드 패널과 숫자를 대조할 수 있으면 대시보드 이름과 패널 제목을 적는다 (`결제 여정` 대시보드).
- 원인은 "가설" 로 쓴다. 근거가 하나뿐이면 확신이 낮다고 적는다.
