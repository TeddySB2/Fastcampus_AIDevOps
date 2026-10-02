# 요구사항: 쇼핑몰 dev 환경 EKS 구축

> 플랫폼팀 회의에서 정한 내용. 결정되지 않은 것은 "미정" 으로 남겼다.
> 작업 스펙(specs/eks-demo.md)은 이 문서와 CLAUDE.md(팀 규칙)를 바탕으로 쓴다.

## 목적

- 쇼핑몰 서비스(OpenTelemetry Demo)를 dev EKS 에 올려, 배포 · 관측 · 장애 대응 · 복구 흐름을 팀이 같은 절차로 검증한다.
- 상품 조회와 장바구니가 실제로 동작해야 "올라갔다" 고 본다.

## 환경 (결정)

- AWS: dev 전용 계정 (계정 ID 는 공개 저장소에 적지 않는다), 리전 ap-northeast-2
- 클러스터: `ai-devops-lab-dev`, Kubernetes 1.36
- 네임스페이스: `otel-demo-dev`(자동 Sync), `otel-demo-prod`(같은 클러스터, 수동 Sync), `argocd`
- 차트: OpenTelemetry Demo 공식 Helm 차트 0.42.1 고정

## 범위 (결정)

포함
- VPC · EKS · ECR (Terraform), Argo CD 와 root 앱
- Demo 전체 서비스. 관측 스택(Grafana · Jaeger 등)과 load-generator 포함
- metrics-server 와 HPA
- product-catalog 한 서비스만 직접 빌드 → ECR(태그 변경 불가, IMMUTABLE) → digest 로 배포, 이후 CI 로 자동화
- prod 승격: 같은 클러스터의 `otel-demo-prod` 로, 사람이 Sync

제외
- 외부 공개(공개 LoadBalancer · Ingress · 도메인). 접속은 port-forward 로만
- 노드 오토스케일링(Karpenter 등), 멀티리전, 실제 고객 데이터 · 결제

## 운영 · 비용 (결정)

- 노드: m6i.xlarge, 최소 2대 · 최대 4대
- API endpoint: 공개하되 작업자 IP/32 로 제한
- Terraform state: S3 backend(use_lockfile). 버킷은 사람이 미리 만들고 지우지 않는다
- 쓰지 않는 시간에는 내린다. 잊었을 때를 대비해 리소스에 `expires` 태그(생성 후 최대 7일)를 단다

## 승인 · 실행 (결정)

- `terraform apply/destroy`, prod Sync 는 사람이 실행한다. 승인자: @TeddySB2
- Claude 는 읽기 전용 권한으로 조회 · 분석 · PR 작성까지 한다
- 장애 주입(flagd 플래그 변경, 시나리오 스크립트)은 사람이 직접 실행한다. 클러스터를 직접 바꾸는 일이라 팀 규칙의 예외다

## 완료 기준 (결정)

- Argo CD 앱이 Synced + Healthy
- 배포된 product-catalog 이미지 digest 가 ECR 의 digest 와 일치
- `tests/smoke.sh` 통과: 상품 목록 → 상세 → 장바구니 추가 → 조회 → 비우기
- 실패하면 revert PR 로 되돌리고 같은 검사를 다시 통과
- 정리 후 LB · EBS · ENI 잔여 0. state 버킷만 남기고, ECR 저장소는 destroy 때 이미지와 함께 지운다

## 미정 (다음 회의 전까지)

- 월 예산 상한과 알림 받을 사람
- 작업 종료 시점 (언제 내리는가)
- 장애 주입 예외의 승인자
