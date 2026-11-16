---
name: obs-ask
description: 운영 질문("결제 에러 언제부터 늘었어?", "제일 느린 API 는?", "재시작한 Pod 있어?", "실패한 주문 한 건 따라가 봐")을 Grafana MCP 로 PromQL · LogQL · TraceQL 조회해 근거와 함께 답한다. 읽기 전용. 대시보드 · 알람 · 플래그는 바꾸지 않는다.
---

# 관측 데이터에 질문하기 (읽기 전용)

목표는 "그럴듯한 답" 이 아니라 **누가 다시 돌려도 같은 결과가 나오는 쿼리와 그 결과** 다.
CLAUDE.md 의 "관측 데이터 조회" 규칙을 지키고, 이 Skill 은 그 규칙을 질문별 절차로 푼다.

## 0. 범위를 정한다

- 질문에 시간 범위가 없으면 **최근 1시간**. 더 넓힐 때는 이유를 먼저 말하고, 최대 24시간.
- 대상은 `otel-demo-dev`. 시각은 KST 절대 시각으로 적는다 (예: 11-16 22:19:15 KST).

## 1. 이름을 먼저 확인한다 (추측 금지)

1. 결제 여정 메트릭은 `specs/observability.md` 의 SLI 쿼리에 있는 이름을 그대로 쓴다
   (`traces_span_metrics_calls_total`, `traces_span_metrics_duration_milliseconds_bucket`,
   라벨 `service_name` · `span_name` · `span_kind` · `status_code`).
2. 그 밖의 이름은 목록으로 확인한다: `list_prometheus_metric_names` → `list_prometheus_label_values` → `list_loki_label_names`.
3. 결과가 비면 여기로 돌아와 이름을 다시 확인한다.

## 2. 질문별 조회

| 질문 | 조회 |
| --- | --- |
| 에러가 언제부터 | span metrics 를 `status_code` 별로 range query 해서 범위를 잡고, 정확한 첫 시각은 Tempo(`status = error`) · Loki 에러 로그로 확인한다. 메트릭은 Collector 주기 때문에 1 ~ 2분 늦게 보인다 |
| 느린 API | 서버 span(`span_kind="SPAN_KIND_SERVER"`) 의 p95 를 `service_name` · `span_name` 별로, **호출 수와 함께**. 연결을 열어 두는 스트림 span(flagd `EventStream` 등)은 지연이 아니므로 뺀다 |
| 재시작한 Pod | `kube_pod_container_status_restarts_total` 증가분. 비면 같은 메트릭의 시계열 개수를 세어 "0" 과 "데이터 없음" 을 구분한다 |
| 한 건 따라가기 | Loki 에러 로그(`{service_name="…"} \| detected_level="error"` 또는 `\|~ "(?i)error\|fail"`) 의 `trace_id` → Tempo 트레이스. 실패 지점과 그 뒤에 실행되지 않은 단계를 적는다 |

- flagd `EventStream` 의 ERROR span 은 10분마다 끊겼다 붙는 플래그 구독 스트림이다. 결제 에러로 세지 않는다.
- 로그 · 트레이스에 이메일 · 카드 정보가 보이면 인용하지 않고 "민감 정보 있음" 으로만 적는다.

## 3. 답 형식

```
<결론 한두 줄. 숫자와 KST 절대 시각>

| 확인 | 결과 | 데이터소스 |
| --- | --- | --- |

확인하지 못한 것
- <빈 결과, 조회 실패, 가정 — 예: 플래그 상태는 scenarios/flag.sh --list 로 사람이 확인>

<details><summary>실행한 쿼리</summary> 쿼리 원문 · 시간 범위 </details>
```

- 원인은 "가설" 로 쓴다. 근거가 한 건뿐이면 확신이 낮다고 적는다.
- 표는 5줄 안쪽으로. 쿼리 원문은 접어서 아래에 둔다.
