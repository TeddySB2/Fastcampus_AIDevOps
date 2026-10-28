# 요구사항: 쇼핑몰 dev 관측 체계

> 플랫폼팀 · 결제 서비스 오너 회의에서 정한 내용. 결정되지 않은 것은 "미정" 으로 남겼다.
> 작업 스펙(specs/observability.md)은 이 문서, `specs/eks-demo.md`(환경), CLAUDE.md(팀 규칙)를 바탕으로 쓴다.

## 배경

- "결제가 느리다" 는 문의가 왔을 때 지금 대시보드로는 답을 못 했다. Demo 에 딸려 온 대시보드는 여러 개지만 "결제(주문)가 지금 정상인가" 를 보여 주는 화면이 없다.
- Demo 에 들어 있는 관측 백엔드는 데모용이다. Grafana 가 로그인 없이 누구나 Admin 이고, Alertmanager · kube-state-metrics 가 없어 알람을 보낼 수 없다.

## 목적 (결정)

- 결제(주문)가 지금 되는지, 얼마나 느린지, 어디서 깨졌는지를 팀이 같은 화면 · 같은 절차로 답한다.
- 장애가 나면 메트릭 → 트레이스 → 로그를 trace_id 하나로 따라가 원인 서비스를 5분 안에 좁힌다.
- Claude 는 관측 데이터를 읽기 전용으로 조회하고, 답에 근거(쿼리 · 시간 범위 · 데이터소스)를 붙인다.

## 목표치 (결정, 결제 서비스 오너 합의)

- 주문 가용성: 99% (30일 창)
- 주문 지연: p95 1초 미만 (대시보드로 본다. 알람은 걸지 않는다)
- 목표는 사용자에게 필요한 수준으로 정한 값이다. 스택을 올린 뒤 평소 수치(기준선)를 재서 목표가 현실적인지만 확인한다. 기준선이 목표에 못 미치면 목표를 바꾸기 전에 원인부터 본다.

## 스택 (결정)

- 메트릭 · 알람: kube-prometheus-stack (Prometheus · Alertmanager · Grafana · kube-state-metrics)
- 로그: Loki, 트레이스: Tempo
- 수집: Demo 차트에 들어 있는 OTel Collector 를 그대로 쓰고 보내는 곳만 바꾼다. Demo 내장 Prometheus · Grafana · Jaeger · OpenSearch 는 dev 에서 끈다
- 네임스페이스 `observability`, Argo CD 로 관리. 기존 otel-demo 프로젝트 권한을 넓히지 않도록 별도 AppProject 로 둔다
- 대시보드 · 알람 룰은 Git 에 코드로 둔다 (UI 에서 만든 것은 인정하지 않는다)
- 차트 출처: kube-prometheus-stack 은 prometheus-community, Loki · Tempo 는 grafana-community 저장소 (grafana 저장소의 Loki · Tempo 차트는 grafana-community 로 옮겨 갔다). 버전은 구현 PR 에서 렌더링 · 검증하며 고정하고, 스펙에는 적지 않는다

## 환경 제약 (결정)

- 클러스터에 EBS CSI 드라이버가 없다 → PVC 를 쓰지 않는다. 관측 백엔드는 emptyDir 이고, Pod 가 재시작되면 데이터가 사라진다 (dev 한정. 운영은 오브젝트 스토리지 · PVC)
- 그래서 보존은 짧게: 메트릭 2일, 로그 48시간, 트레이스 24시간
- 노드는 m6i.xlarge 2대(최대 4대) 그대로. 관측 스택 때문에 노드를 늘리지 않는다. Demo 내장 백엔드를 끄는 만큼 안에서 해결한다
- 접속은 port-forward 로만. prod(`otel-demo-prod`)에는 관측 스택을 두지 않는다
- Grafana admin 비밀번호는 사람이 Secret(`observability/grafana-admin`)으로 직접 만든다 (팀 규칙 예외, 승인자 @TeddySB2). 이번 작업에서 infra(Terraform)는 바꾸지 않는다

## 검증 (결정)

- 스택이 떠 있는 것만으로는 완료가 아니다. 주문 요청의 메트릭 · 로그 · 트레이스가 실제로 들어오고 trace_id 로 이어지는지 스크립트(`tests/signals.sh`)로 확인한다. 주문은 load-generator 가 계속 만드는 것을 쓴다
- 확인이 끝나면 장애가 없는 평소 수치(주문 실패율 · p95)를 재서 스펙에 기준선으로 남긴다
- 장애 주입은 사람이 한다 (`scenarios/flag.sh paymentFailure …`, 팀 규칙 예외, 승인자 @TeddySB2)

## 스펙에서 정할 것 (작업자)

- 먼저 답할 운영 질문 목록 (대시보드 · 알람 · AI 조회의 출발점). 결제만이 아니라 아침 점검 때 늘 묻는 것 — Pod 재시작 · NotReady, 수집 파이프라인 자체의 상태, 언제부터 · 직전에 무엇이 바뀌었나 — 도 포함한다
- 결제 여정의 실제 호출 경로와 신호별 수집 지점
- 목표치를 잴 SLI 의 정확한 정의 (어떤 서비스 · 어떤 span · 무엇을 실패로 볼지)
- "관측된다" 의 완료 증거 (명령과 기대값)
- 구현 위치는 디렉터리 수준까지만 적는다 (`gitops/apps`, `gitops/values/observability`, `gitops/manifests/observability`). 파일 이름 · values 키 · 차트 버전은 구현 PR 에서 정한다

## 이번 작업에서 하지 않는 것 (결정)

- 알람 룰 · 기록 규칙 · 알람 등급 (알람 정책 회의 뒤 별도 작업)
- infra(Terraform) 변경, 새 검증 스크립트 외의 테스트 추가

## 미정 (다음 회의 전까지)

- 알람 등급과 받을 곳 (Slack 채널, 담당자, 응답 시간)
- 알람을 보낼 지표 (목표치 기반으로 하되 세부는 알람 정책 회의에서)
- Claude 의 Slack 사용 여부와 범위
