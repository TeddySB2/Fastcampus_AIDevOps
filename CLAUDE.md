# ai-devops-lab

OpenTelemetry Demo 를 EKS 에 GitOps 로 배포·운영하는 강의 실습 저장소다.
이 파일은 이 저장소에서 일하는 사람과 Claude 가 함께 지키는 규칙이다.

## 환경 사실 (추정하지 말고 이 값을 쓴다)

- AWS 리전: ap-northeast-2 / 클러스터: ai-devops-lab-dev
- 네임스페이스: otel-demo-dev (자동 동기화), otel-demo-prod (수동 동기화), argocd
- 차트: opentelemetry-demo 0.42.1 (appVersion 3.1.0) — gitops/apps/*.yaml 에 고정
- 직접 빌드하는 서비스: app/product-catalog 하나뿐. 나머지는 차트 기본 이미지
- 이 값과 실제 환경이 다르면 작업을 멈추고 사람에게 알린다

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
6. Secret 값, 토큰, state 파일 내용은 읽지도 출력하지도 않는다.

## 완료 조건 (작업을 끝냈다고 말하기 전에 확인)

- Terraform: `terraform fmt -check`, `terraform validate`, `checkov -d infra --config-file infra/.checkov.yaml`, `terraform plan` 요약
- GitOps: YAML 파싱, `helm template` 렌더링, `kubeconform`
- 배포: Argo CD 앱 Healthy + `tests/smoke.sh` 통과. Pod 가 Running 인 것만으로는 완료가 아니다
- 보고: 무엇을 바꿨는지, 어떤 검증을 통과했는지, 확인하지 못한 것이 무엇인지

## 자주 쓰는 명령

```bash
aws eks update-kubeconfig --region ap-northeast-2 --name ai-devops-lab-dev
kubectl -n otel-demo-dev port-forward svc/frontend-proxy 8080:8080   # 상점 UI, /feature 는 플래그 UI
kubectl -n argocd port-forward svc/argocd-server 8081:80             # Argo CD
BASE_URL=http://localhost:8080 ./tests/smoke.sh
```
