# Runbook: 주문(결제) 실패 — CheckoutErrorBudgetBurnFast / Slow

알람 계약: `specs/observability.md` 6장. 이 문서는 알람을 받은 사람이 처음 15분 동안 하는 일이다.

## 1. 영향 확인 (5분)

- 대시보드 **결제 여정** (uid `checkout-journey`): 주문 실패율, p95, 하위 서비스 에러
- 실패율이 지금도 오르는 중인지, 이미 내려오는 중인지 본다. 내려오는 중이면 ticket 으로 낮춘다.

```promql
checkout:place_order_errors:ratio_rate5m
sum by (service_name, span_name) (rate(traces_span_metrics_calls_total{status_code="STATUS_CODE_ERROR"}[5m]))
```

## 2. 어디서 실패하나 (5분)

- 하위 호출 중 에러가 나는 서비스: payment · cart · currency · shipping · email
- 같은 시간대 에러 로그 (Loki):

```logql
{service_name=~"checkout|payment"} | detected_level="error"
```

- 에러 로그의 trace_id 로 Tempo 트레이스를 열어 어느 span 에서 실패했는지 확인한다.

## 3. 최근 변경 (5분)

- `argocd app history otel-demo-dev`, `git log --oneline -10 -- gitops/ app/`
- flagd 플래그: `./scenarios/flag.sh --list` 에서 `paymentFailure`, `paymentUnreachable`, `cartFailure` 가 off 인지

## 4. 다음 행동

| 원인 | 행동 | 승인 |
| --- | --- | --- |
| 최근 배포 | 원인 커밋 `git revert` PR | 코드 오너 |
| 플래그 · 설정 | 원래 값으로 되돌리는 PR 또는 플래그 off | 온콜 |
| 외부 결제사 · 알 수 없음 | 장애 채널 개설, Part 5 Triage 절차 | 온콜 리드 |

AI(Claude)는 1~3 의 조회와 정리를 맡는다. 4 의 실행은 사람이 한다.
