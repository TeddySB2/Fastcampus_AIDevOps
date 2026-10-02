# 작업 스펙: 쇼핑몰(OTel Demo) dev 환경 EKS 구축

> 상태: 진행 중  (현재 작업이면 CLAUDE.md 에서 import 한다. 끝나면 "완료" 로 바꾸고 지우지 않는다)

> AI 에게 맡길 작업의 목적·범위·제약·완료 기준을 팀이 검토할 수 있게 적은 문서.
> 실제 값(계정, 승인자, 예산)은 사람이 채운다. 비어 있는 값은 Claude 가 추정하지 않고 질문한다.
> 저장소에 커밋하고, 바꿀 때는 PR 로 리뷰한다.
> CLAUDE.md 의 팀 규칙 안에서 쓴다. 규칙을 벗어나는 결정은 "4. 제약과 승인" 에 예외로 적고 승인자를 둔다.
> 근거: docs/requirements/eks-dev.md (팀 회의 요구사항)

## 1. 목적

쇼핑몰 서비스(OpenTelemetry Demo)를 dev EKS 에 올려 배포 · 관측 · 장애 대응 · 복구 흐름을 같은 절차로 검증한다.
상품 조회와 장바구니가 실제로 동작해야 완료로 본다.

## 2. 환경

| 항목 | 값 |
| --- | --- |
| AWS 계정 | (dev 전용 계정 ID — 공개 저장소에는 적지 않는다) |
| 리전 | ap-northeast-2 |
| 클러스터 | ai-devops-lab-dev (Kubernetes 1.36) |
| 네임스페이스 | otel-demo-dev (자동 Sync), otel-demo-prod (수동 Sync), argocd |
| 차트 | OpenTelemetry Demo 공식 Helm 차트 0.42.1 |
| 실행 전 확인 | `aws sts get-caller-identity` 의 계정, `kubectl config current-context` 가 ai-devops-lab-dev (update-kubeconfig 에 `--alias` 로 등록) |

## 3. 범위

포함
- VPC · EKS · ECR (Terraform), Argo CD 와 root 앱
- Demo 전체 서비스 (관측 스택, load-generator 포함), metrics-server 와 HPA
- product-catalog 한 서비스만 직접 빌드 → ECR → digest 배포, 이후 CI 자동화
- prod 승격: 같은 클러스터 otel-demo-prod, 사람이 Sync
- 장애 주입과 복구 (예외 — 4 참고)

제외 (별도 요구사항 필요)
- 외부 공개 (공개 LoadBalancer · Ingress · 도메인). 접속은 port-forward
- 노드 오토스케일링, 멀티리전, 실제 고객 데이터 · 결제

## 4. 제약과 승인

- 기반 인프라는 Terraform 으로만. `apply/destroy` 는 사람이 plan 을 검토한 뒤 실행한다.
- 앱 변경은 GitOps PR 로만. 클러스터 직접 수정 금지.
- product-catalog 는 ECR(IMMUTABLE) digest 로 배포한다. 나머지는 차트 기본 이미지.
- 노드 m6i.xlarge 최소 2 · 최대 4. API endpoint 는 작업자 IP/32 만 허용.
- state 는 S3 backend(use_lockfile). 버킷은 사람이 만들고 지우지 않는다.
- 비용: 월 $300 상한. AWS Budgets 알림은 사람이 콘솔에서 만들고 담당자 메일로 받는다. 넘으면 작업 중단 후 보고.
- 수명: 작업한 날 destroy 한다. 잊었을 때의 안전장치로 모든 리소스에 `expires` 태그(생성 후 최대 7일)를 단다.
- 예외: 장애 주입(flagd 플래그, 시나리오 스크립트)은 클러스터를 직접 바꾸므로 팀 규칙 1 의 예외다. 사람이 직접 실행하고 승인자는 @TeddySB2.

## 5. 완료 증거

| 확인 | 기준 (명령과 기대값) |
| --- | --- |
| 배포 | Argo CD 앱 Synced + Healthy, product-catalog 이미지 digest 가 ECR digest 와 일치 |
| 기능 | `tests/smoke.sh` 통과 (상품 목록 → 상세 → 장바구니 추가 → 조회 → 비우기) |
| 실패 대응 | 실패하면 다음 변경 중단 → revert PR 로 되돌림 → 같은 검사 다시 통과 |
| 종료 | 문서화된 순서로 삭제, LB · EBS · ENI 잔여 0 (state 버킷만 남김, ECR 저장소는 함께 삭제) |

## 6. 승인자

| 변경 | 승인자 |
| --- | --- |
| Terraform apply · destroy | @TeddySB2 |
| prod 승격 · Sync | @TeddySB2 |
| 정책 예외 (장애 주입) | @TeddySB2 |
