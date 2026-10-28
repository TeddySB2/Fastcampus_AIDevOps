---
name: daily-health
description: 아침 점검. otel-demo-dev 의 배포 상태 · 비정상 Pod · 주문 오류율과 지연 · 최근 알람 · 비용 이상(노드 수, Pending Pod)을 읽기 전용으로 조회해 정상 / 확인 필요 / 즉시 대응 으로 나눈 보고서를 만들고, 승인을 받아 Slack #ops-daily 에 올린다.
---

# 일일 클러스터 헬스체크

모든 항목은 **판정 · 근거(명령 또는 쿼리) · 후속 확인 명령** 세 가지를 가진다. 근거 없는 "정상" 은 쓰지 않는다.

## 0. 대상 확인

- `kubectl config current-context` → `ai-devops-lab-dev` 가 아니면 멈춘다.
- 점검 시각(KST)과 범위(지난 24시간)를 보고서 맨 위에 적는다.

## 1. 항목과 판정 기준

| # | 항목 | 조회 | 정상 | 확인 필요 | 즉시 대응 |
| --- | --- | --- | --- | --- | --- |
| 1 | 배포 상태 | `argocd app list` | 모든 앱 Synced · Healthy | OutOfSync 또는 Progressing 이 30분 넘음 | Degraded |
| 2 | 비정상 Pod | `kubectl get pods -n otel-demo-dev`, 재시작 증가분 (Prometheus `increase(kube_pod_container_status_restarts_total{namespace="otel-demo-dev"}[24h])`) | 모두 Running · Ready, 재시작 0 | 재시작 1~4회 | CrashLoopBackOff, 재시작 5회 이상, NotReady |
| 3 | 주문 오류율 | `checkout:place_order_errors:ratio_rate1h` (없으면 스펙 5장 원본 쿼리) | 1% 미만 | 1~5% | 5% 초과 또는 page 알람 발화 중 |
| 4 | 주문 지연 | PlaceOrder p95 (1시간) | 1초 미만 | 1~3초 | 3초 초과 |
| 5 | 최근 알람 | `ALERTS{alertstate="firing"}`, 지난 24시간 `ALERTS` 변화 | 발화 없음 (Watchdog 제외) | ticket · warning 발화 | page · critical 발화 |
| 6 | 비용 이상 | `kubectl get nodes`, Pending Pod 수 | 노드 2대, Pending 0 | 노드 3대 이상 (스펙 최대 4) | 노드 4대 또는 Pending 이 10분 넘음 |
| 7 | 관측 파이프라인 | `sum(rate(otelcol_exporter_send_failed_spans_total[1h]))` 등 Collector 실패 지표, `./tests/signals.sh` | 실패 0, signals PASS | 실패 증가 | 신호 중단 (메트릭 · 로그 · 트레이스 중 하나라도 없음) |

- 조회가 실패하면(연결 오류 · 권한 · 타임아웃 · 빈 결과) 그 항목은 **확인 필요** 다. "알람 없음" 처럼 정상으로 쓰지 않는다.
- 숫자는 쿼리 결과 그대로 적는다. 반올림은 소수 둘째 자리까지.

## 2. 보고서 형식 (Slack mrkdwn)

```
*[dev 일일 점검] 10/20 (월) 09:00 KST* — 즉시 대응 0 · 확인 필요 1 · 정상 6

:red_circle: *즉시 대응*
(없음)

:large_yellow_circle: *확인 필요*
• 비정상 Pod — email 재시작 2회 (24h) · 근거: increase(kube_pod_container_status_restarts_total{…}[24h]) · 다음: kubectl describe pod -n otel-demo-dev -l app.kubernetes.io/component=email

:large_green_circle: *정상*
• 배포 상태 — 앱 7개 Synced · Healthy (argocd app list)
• …
```

- 즉시 대응 항목이 있으면 첫 줄에 담당자 멘션을 넣는다 (`specs/observability.md` 11장의 승인자). 없으면 멘션하지 않는다.
- 변경이 필요한 항목은 "제안" 으로만 쓰고 GitHub Issue 초안을 함께 만든다 (`gh issue create` 는 사람이 승인한 뒤).

## 3. 전송

1. 보고서를 화면에 먼저 보여 준다.
2. 사람이 "보내" 라고 하면 Slack MCP 로 `#ops-daily` 에 보낸다. 다른 채널에는 보내지 않는다.
3. 보낸 메시지 링크(또는 timestamp)를 마지막에 적는다.
