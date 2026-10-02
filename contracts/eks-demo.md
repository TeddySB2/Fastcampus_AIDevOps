# 작업 계약: OpenTelemetry Demo 를 dev EKS 에 배포

> AI 에게 맡길 작업의 범위·제약·완료 기준을 팀이 검토할 수 있게 적은 문서.
> 실제 값(계정, 리전, 승인자)은 사람이 채운다. 비어 있는 값은 Claude 가 추정하지 않고 질문한다.

## 1. 목적

OpenTelemetry Demo 를 dev EKS 에 배포하고, 상품 조회와 장바구니 기능이 동작하는 것을 확인한다.

## 2. 환경

| 항목 | 값 |
| --- | --- |
| AWS 계정 | (전용 학습 계정 ID) |
| 리전 | ap-northeast-2 |
| 클러스터 | ai-devops-lab-dev |
| 네임스페이스 | otel-demo-dev (prod 는 otel-demo-prod, 수동 동기화) |
| 실행 전 확인 | `aws sts get-caller-identity`, `kubectl config current-context` |

## 3. 범위

포함
- Demo 의 EKS 배포, product-catalog 한 서비스의 ECR 이미지 교체
- 부하, 장애, 복구, 자원 정리

제외 (별도 요구사항 필요)
- 실제 고객 데이터·결제, 멀티리전 재해 복구, 전체 서비스 자체 빌드, 외부 공개

## 4. 제약

- 기반 인프라는 Terraform 으로만 관리한다. `apply` 는 사람이 plan 을 검토한 뒤 실행한다.
- 애플리케이션 변경은 GitOps PR 로만 한다. 클러스터 직접 수정 금지.
- 수정한 서비스는 ECR digest 로 배포한다. 나머지는 고정된 차트 기본 이미지를 쓴다.
- 생성·삭제·권한 확대는 변경 내용을 사람이 검토한다.
- 노드 상한: (예: 4대) / 예산 알림: (예: 월 OO USD) / 초과 시: 작업 중단 후 보고

## 5. 완료 증거

| 확인 | 기준 |
| --- | --- |
| 배포 | 배포 대상과 실제 이미지 digest 가 일치, Deployment rollout 완료 |
| 기능 | `tests/smoke.sh` 통과 (상품 조회 → 장바구니 추가 → 조회 → 비우기) |
| 실패 대응 | 검증 실패 시 다음 변경 중단 → 알려진 정상 버전으로 revert → 같은 검사 반복 |
| 종료 | 문서화된 순서로 삭제, LB·EBS·ENI 잔여 자원 없음 |

## 6. 승인자

| 변경 | 승인자 |
| --- | --- |
| Terraform apply | (이름) |
| prod 승격·Sync | (이름) |
| 정책 예외 | (이름) |
