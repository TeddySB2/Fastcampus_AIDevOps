---
name: daily-health
description: 아침 점검. otel-demo-dev 의 배포 상태 · 비정상 Pod · 주문 오류율과 지연 · 최근 알람 · 비용 이상(노드 수, Pending Pod)을 읽기 전용으로 조회해 보고서를 만들고, 승인을 받아 Slack #ops-daily 에 올린다.
---

# 일일 클러스터 헬스체크

각 항목에 판정과 근거(명령 또는 쿼리), 후속 확인 명령을 붙인다.

## 1. 항목

| # | 항목 | 조회 |
| --- | --- | --- |
| 1 | 배포 상태 | `argocd app list` |
| 2 | 비정상 Pod | `kubectl get pods -n otel-demo-dev`, `increase(kube_pod_container_status_restarts_total{namespace="otel-demo-dev"}[24h])` |
| 3 | 주문 오류율 | `checkout:place_order_errors:ratio_rate1h` |
| 4 | 주문 지연 | PlaceOrder p95 (1시간) |
| 5 | 최근 알람 | `ALERTS{alertstate="firing"}` (Watchdog 제외) |
| 6 | 비용 이상 | `kubectl get nodes`, Pending Pod 수 |
| 7 | 관측 파이프라인 | Collector 실패 지표, `./tests/signals.sh` |

## 2. 보고서 형식 (Slack mrkdwn)

```
*[dev 일일 점검] 10/20 (월) 09:00 KST*
• 배포 상태 — 정상 · 앱 7개 Synced · Healthy (argocd app list)
• 비정상 Pod — 확인 필요 · email 재시작 2회 (24h) · 다음: kubectl describe pod …
• …
```

## 3. 전송

1. 보고서를 화면에 먼저 보여 준다.
2. 사람이 "보내" 라고 하면 Slack MCP 로 `#ops-daily` 에 보낸다.
