# ai-devops-lab

「AI DevOps 구축과 운영」 Part 3 ~ 8 실습 저장소.
OpenTelemetry Demo 를 EKS 에 GitOps 로 배포하고, Claude Code 와 함께 운영한다.

> 이 브랜치는 **Part 3 완료 상태(p3-end)** 다. 챕터별 시작 상태는 `p3-chN-start` 태그로 제공한다.

## 구성

```
CLAUDE.md                 저장소 규칙 (사람과 Claude 공통)
.claude/                  권한(allow/ask/deny), Hook, Skill
.mcp.json                 EKS · Argo CD MCP (읽기 전용)
contracts/eks-demo.md     작업 계약서 (1-1)
infra/cluster             VPC · EKS · ECR · GitHub OIDC (Terraform)
infra/platform            Argo CD + root Application (Terraform)
gitops/apps               Argo CD Application (dev 자동 / prod 수동)
gitops/values/otel-demo   차트 값 (common / dev / prod)
gitops/manifests          차트 밖의 리소스 (HPA 등)
app/product-catalog       직접 빌드하는 유일한 서비스 (업스트림 3.1.0 vendored)
tests/smoke.sh            사용자 여정 Smoke Test
scenarios/                장애·실수 장면 재현 스크립트, reset
.github/workflows         CI(빌드·스캔·배포 PR), 승격, headless AI 수정 PR
docs/                     구축 기록, 정리 순서
```

## 준비물

| 도구 | 용도 |
| --- | --- |
| Terraform ≥ 1.10, tflint, checkov | infra |
| AWS CLI v2, kubectl, helm, kubeconform, yq v4 | 클러스터·렌더링 |
| argocd CLI, gh CLI | GitOps·PR |
| Claude Code, uv(uvx), Node.js(npx) | 에이전트·MCP |

버전은 `docs/setup-log.md` 에 기록하고 촬영 기간 동안 고정한다.

## 처음 한 번 (부트스트랩)

```bash
# 0. 자리표시자 교체 (GitHub owner)
./scripts/init-repo.sh <github-owner>

# 1. 클러스터 (사람이 plan 을 검토하고 apply)
cd infra/cluster
cp backend.hcl.example backend.hcl && cp dev.tfvars.example dev.tfvars   # 값 채우기
terraform init -backend-config=backend.hcl
terraform plan -var-file=dev.tfvars -out=tfplan
terraform apply tfplan
aws eks update-kubeconfig --region ap-northeast-2 --name "$(terraform output -raw cluster_name)"

# 2. GitHub 저장소 변수 등록 (Settings → Secrets and variables → Actions → Variables)
#    AWS_REGION, AWS_CI_ROLE_ARN(=github_ci_role_arn), ECR_REPOSITORY_URL(=ecr_repository_url)
#    Secrets: ANTHROPIC_API_KEY (6-3)
#    Environments: prod (승인자 지정, 6-2)

# 3. 플랫폼 (Argo CD + root Application)
cd ../platform
cp backend.hcl.example backend.hcl && cp platform.tfvars.example platform.tfvars
terraform init -backend-config=backend.hcl
terraform plan -var-file=platform.tfvars -out=tfplan && terraform apply tfplan

# 4. 확인
kubectl -n argocd get applications            # root, otel-demo-dev(Synced/Healthy), otel-demo-prod(OutOfSync — 정상)
kubectl -n otel-demo-dev port-forward svc/frontend-proxy 8080:8080 &
./tests/smoke.sh
```

- GitOps 저장소는 공개 저장소를 가정한다. 비공개면 Argo CD 에 저장소 자격 증명을 추가해야 한다.
- prod(`otel-demo-prod`)는 6-2 전까지 동기화하지 않는다. 관측 스택 없이 앱만 올라간다.
- 처음에는 product-catalog 도 업스트림 이미지로 뜬다. `app/product-catalog` 를 바꿔 main 에 merge 하면
  CI 가 ECR 이미지로 교체하는 PR 을 만든다 (6-1).

## Claude Code

```bash
export AWS_PROFILE=ai-devops-readonly                       # 읽기 전용 프로파일
export ARGOCD_MCP_TOKEN=$(argocd account generate-token --account mcp-readonly)
claude
```

- 쓰기 명령은 `.claude/settings.json` deny 와 `guard-kube-context.sh` Hook 이 막는다.
- 파일을 고치면 `post-edit-validate.sh` 가 fmt/validate/YAML 검사를 돌린다.
- 배포 장애는 `/deploy-triage` Skill 로 조사한다.

## 장면 재현 (강사용)

| 스크립트 | 장면 | 클립 |
| --- | --- | --- |
| `scenarios/flag.sh productCatalogFailure on` | Pod 는 Running 인데 Smoke 실패 | 2-3 |
| `scenarios/flag.sh loadGeneratorFloodHomepage on` (또는 Locust UI `/loadgen/`) | 부하 증가 → HPA 확장 | 4-1 |
| `scenarios/break-values.sh` | 잘못된 이미지 태그 → Degraded | 3-2 |
| `scenarios/break-env.sh` | DB 설정 누락 → CrashLoopBackOff | 5-1 |
| `scenarios/break-oom.sh` | memory limit 축소 → OOMKilled | 5-1 |
| `scenarios/reset.sh <tag>` | 시작 상태로 되돌리기 | 매 테이크 |

## 정리

`docs/teardown.md` 순서를 따른다.

## 검증 상태 (이 초안 기준)

| 항목 | 결과 |
| --- | --- |
| Terraform 문법·타입 (`validate`, OpenTofu 1.10 로 대체 실행) | 통과 (cluster, platform) |
| `checkov` (infra/.checkov.yaml 예외 3건 포함) | 35 통과 / 0 실패 |
| GitHub Actions (`actionlint`) | 통과 |
| `kubeconform` (HPA) | 통과 |
| `tests/smoke.sh` (모의 서버) | 정상·실패 경로 모두 기대대로 |
| `helm template` 렌더링, 실제 `terraform plan/apply`, 클러스터 배포 | **미실행 — 1단계 환경 완주에서 확인** |
