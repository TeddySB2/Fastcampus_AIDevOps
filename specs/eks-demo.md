# 작업 스펙: 쇼핑몰 dev 환경 EKS 구축

> 상태: 진행 중  (현재 작업이면 CLAUDE.md 에서 import 한다. 끝나면 "완료" 로 바꾸고 지우지 않는다)

> AI 에게 맡길 작업의 목적·범위·제약·완료 기준을 팀이 검토할 수 있게 적은 문서.
> 실제 값(계정, 승인자, 예산)은 사람이 채운다. 비어 있는 값은 Claude 가 추정하지 않고 질문한다.
> 저장소에 커밋하고, 바꿀 때는 PR 로 리뷰한다.
> CLAUDE.md 의 팀 규칙 안에서 쓴다. 규칙을 벗어나는 결정은 "4. 제약과 승인" 에 예외로 적고 승인자를 둔다.
>
> 근거: `docs/requirements/eks-dev.md`(팀 회의 요구사항), `CLAUDE.md`(팀 규칙). "미정" 은 다음 회의 후 PR 로 채운다.

## 1. 목적

쇼핑몰 서비스(OpenTelemetry Demo)를 dev EKS 에 올려, 배포 · 관측 · 장애 대응 · 복구 흐름을 팀이 같은 절차로 검증한다.
상품 조회와 장바구니가 실제로 동작해야 "올라갔다" 고 본다.

## 2. 환경

| 항목 | 값 |
| --- | --- |
| AWS 계정 | dev 전용 계정. 계정 ID 는 공개 저장소에 적지 않는다 (기대값은 작업자가 저장소 밖에서 관리) |
| 리전 | ap-northeast-2 |
| 클러스터 | `ai-devops-lab-dev` (Kubernetes 1.36) |
| 네임스페이스 | `otel-demo-dev` (자동 Sync), `otel-demo-prod` (같은 클러스터, 수동 Sync), `argocd` |
| 차트 | OpenTelemetry Demo 공식 Helm 차트 0.42.1 고정 |
| 실행 전 확인 | `aws sts get-caller-identity --query Account --output text` → dev 계정 ID 와 일치 (사람이 대조)<br>`aws configure get region` → `ap-northeast-2`<br>`kubectl config current-context` → `ai-devops-lab-dev` 를 가리킴 |

## 3. 범위

포함
- VPC · EKS · ECR — Terraform (`infra/cluster`)
- Argo CD 와 root Application — Terraform (`infra/platform`)
- Demo 전체 서비스. 관측 스택(Grafana · Jaeger 등)과 load-generator 포함 — GitOps (`gitops/`)
- metrics-server 와 HPA
- product-catalog 한 서비스만 직접 빌드 → ECR(태그 변경 불가, IMMUTABLE) → digest 로 배포. 이후 CI(`.github/workflows`)로 자동화
- prod 승격: 같은 클러스터의 `otel-demo-prod` 로, 사람이 Sync
- `tests/smoke.sh` 작성 (5장 기능 검사용, 아직 없음)

제외 (별도 요구사항 필요)
- 외부 공개(공개 LoadBalancer · Ingress · 도메인). 접속은 port-forward 로만
- 노드 오토스케일링(Karpenter 등)
- 멀티리전
- 실제 고객 데이터 · 결제

## 4. 제약과 승인

- 모든 변경은 Git 브랜치 → PR → 사람 리뷰로만 한다. Claude 는 읽기 전용 권한으로 조회 · 분석 · PR 작성까지 한다.
- `terraform apply/destroy` 와 prod Sync 는 승인자가 직접 실행한다. Claude 는 실행할 명령 · 예상 영향 · 되돌리는 방법을 PR 에 적는다.
- 노드: m6i.xlarge, 최소 2대 · 최대 4대.
- EKS API endpoint: 공개하되 작업자 IP/32 로 제한. IP 값은 커밋하지 않는 tfvars 로 사람이 넣는다.
- Terraform state: S3 backend(`use_lockfile`). 버킷은 사람이 미리 만들고 지우지 않는다. backend 설정 파일(`backend.hcl`)은 커밋하지 않는다.
- 모든 리소스에 `expires` 태그(생성 후 최대 7일)를 단다. 쓰지 않는 시간에는 내린다.
- 비용: 월 예산 상한과 알림 받을 사람은 **미정**. 다음 회의 후 PR 로 채운다. 정해지기 전 apply 여부는 승인자가 판단한다.
- **예외** (팀 규칙 "반드시 지킬 것" 1 · 2 번): 장애 주입(flagd 플래그 변경, 시나리오 스크립트)은 클러스터를 직접 바꾸는 일이라 사람이 직접 실행한다. Claude 는 실행하지 않는다. 승인자: @TeddySB2

## 5. 완료 증거

| 확인 | 기준 (명령과 기대값) |
| --- | --- |
| 배포 | `argocd app get <앱 이름>` → Sync Status `Synced`, Health Status `Healthy`<br>배포된 product-catalog 이미지 digest(`kubectl get pod -n otel-demo-dev -o jsonpath='{..imageID}'`) = `aws ecr describe-images` 의 `imageDigest` |
| 기능 | `tests/smoke.sh` 통과: 상품 목록 → 상세 → 장바구니 추가 → 조회 → 비우기. Pod Running 만으로는 완료가 아니다 |
| 실패 대응 | 실패하면 revert PR 로 되돌리고, 위 배포 · 기능 검사를 다시 통과 |
| 종료 | 생성 후 7일(`expires` 태그) 이내에 승인자가 destroy.<br>정리 후 LB · EBS · ENI 잔여 0 (`aws elbv2 describe-load-balancers`, `aws ec2 describe-volumes`, `aws ec2 describe-network-interfaces` 를 클러스터 태그로 필터 → 빈 결과).<br>state 버킷만 남고, ECR 저장소는 destroy 때 이미지와 함께 삭제 |

## 6. 승인자

| 변경 | 승인자 |
| --- | --- |
| `terraform apply/destroy` | @TeddySB2 |
| prod Sync (`otel-demo-prod`) | @TeddySB2 |
| 장애 주입 예외 | @TeddySB2 |
| 스펙 · 팀 규칙 · infra · gitops/apps 변경 (CODEOWNERS) | @TeddySB2 |
| 월 예산 상한 · 알림 대상 | 미정 |
