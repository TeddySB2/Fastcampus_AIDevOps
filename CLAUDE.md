# ai-devops-lab

쇼핑몰 서비스(OpenTelemetry Demo)의 dev 환경을 AWS EKS 에 GitOps 로 구축·운영하는 플랫폼팀 저장소다.
이 파일은 **플랫폼팀의 팀 규칙**이다. 이 저장소에서 일하는 사람과 Claude 가 함께 지킨다.

- 작업 계약서(contracts/)는 이 규칙 안에서 쓴다. 규칙을 벗어나야 하는 결정은 계약서에 "예외" 로 표시하고 승인자를 적는다.
- 이 파일을 바꿀 때는 PR 로 하고 CODEOWNERS 승인을 받는다.

## 환경 사실 (추정하지 말고 이 값을 쓴다)

- 계정 · 리전 · 클러스터 · 네임스페이스 · 차트 버전은 아래 계약서 "2. 환경" 을 따른다 (여기에 복사하지 않는다)
- 직접 빌드하는 서비스: app/product-catalog 하나뿐. 나머지는 차트 기본 이미지
- 작업 전에 계약서의 "실행 전 확인" 으로 대상을 확인하고, 다르면 멈추고 사람에게 알린다

## 작업 계약 (현재 작업의 목적 · 환경 · 범위 · 제약 · 완료 증거)

@contracts/eks-demo.md

- 계약서와 다른 요청(범위 밖, 제약 위반)을 받으면 작업 전에 차이를 알리고 확인받는다.
- 계약서 변경은 PR 로만 한다. 작업이 바뀌면 위 import 를 해당 계약서로 바꾼다.

## 리소스 관리 주체 (한 리소스는 한 도구만 관리한다)

| 대상 | 관리 주체 | 위치 |
| --- | --- | --- |
| VPC, EKS, ECR, IAM, 기반 애드온 | Terraform | infra/cluster |
| Argo CD 와 root Application | Terraform | infra/platform |
| OTel Demo 설정, HPA 등 앱 리소스 | GitOps (Argo CD) | gitops/ |
| 이미지 빌드·스캔·배포 PR | CI | .github/workflows |
| 설계 선택, 승인, 예외, 복구 판단 | 사람 | PR 리뷰 |

## 반드시 지킬 것

1. 클러스터와 AWS 를 직접 바꾸지 않는다. 모든 변경은 Git 브랜치 → PR → 사람 리뷰를 거친다.
2. `terraform apply/destroy`, `kubectl apply/edit/patch/delete/scale`, `helm install/upgrade`, `argocd app sync` 는 실행하지 않는다.
   필요하면 실행할 명령과 예상 영향, 되돌리는 방법을 제시하고 사람에게 맡긴다.
3. 조회는 자유롭게 한다: `kubectl get/describe/logs/events`, `argocd app get/diff/history`, MCP(읽기 전용).
4. 주장에는 근거를 붙인다: 파일 경로와 줄, 명령과 출력, 리소스 이름. 근거가 없으면 "가정" 이라고 쓴다.
5. 모르는 값(계정 ID, 승인자, 예산 등)은 만들어 내지 말고 질문한다.
6. Secret · 토큰 · state 파일은 직접 열거나 출력하지 않는다. `terraform plan/show` 의 요약은 다룬다 (민감한 값은 가린다).

## 완료 조건 (작업을 끝냈다고 말하기 전에 확인)

- Terraform: `terraform fmt -check`, `terraform validate`, `checkov -d infra --config-file infra/.checkov.yaml`, `terraform plan` 요약
- GitOps: YAML 파싱, `helm template` 렌더링, `kubeconform`
- 배포: Argo CD 앱 Healthy + `tests/smoke.sh` 통과. Pod 가 Running 인 것만으로는 완료가 아니다
- 보고: 무엇을 바꿨는지, 어떤 검증을 통과했는지, 확인하지 못한 것이 무엇인지

## 자주 쓰는 명령

```bash
aws eks update-kubeconfig --region ap-northeast-2 --name ai-devops-lab-dev --alias ai-devops-lab-dev
kubectl -n otel-demo-dev port-forward svc/frontend-proxy 8080:8080   # 상점 UI, /feature 는 플래그 UI
kubectl -n argocd port-forward svc/argocd-server 8081:80             # Argo CD
BASE_URL=http://localhost:8080 ./tests/smoke.sh
```
