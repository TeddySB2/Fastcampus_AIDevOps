# ai-devops-lab

쇼핑몰 서비스의 dev 환경을 AWS EKS 에 GitOps 로 구축·운영하는 플랫폼팀 저장소.
쇼핑몰 서비스로는 OpenTelemetry Demo(Astronomy Shop)를 쓴다. Claude Code 와 함께 작업하되, 판정은 도구가 하고 승인은 사람이 한다.

> 강의 수강생은 [course/README.md](course/README.md) 에서 클립별 시작 태그와 진행 순서를 확인한다.

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
docs/                     정리 순서
course/                   강의 진행용 자료 (Claude 는 읽지 않도록 deny)
```

## 애플리케이션 소스는 왜 product-catalog 만 있나

배포는 OpenTelemetry Demo **전체**(서비스 25개 + 관측 스택)를 한다. 다만 소스를 이 저장소에 두지 않는다.

- 앱 정의: 공식 Helm 차트 `open-telemetry/opentelemetry-demo` **0.42.1** (gitops/apps/*.yaml 에 고정)
- 이미지: 업스트림이 빌드해 둔 `ghcr.io/open-telemetry/demo:3.1.0-<서비스>`
- 이 저장소에 두는 것: 차트에 덮어쓸 값(`gitops/values`), 차트 밖 리소스(`gitops/manifests`), 직접 고치는 서비스 소스(`app/product-catalog`)
- product-catalog 만 `dev.yaml` 의 `imageOverride` 로 우리 ECR 이미지(digest 고정)로 바꾼다

전체 소스가 필요하면 업스트림을 본다: https://github.com/open-telemetry/opentelemetry-demo/tree/3.1.0

## 준비물

| 도구 | 용도 |
| --- | --- |
| Terraform ≥ 1.10, tflint, checkov | infra |
| AWS CLI v2, kubectl, helm, kubeconform, yq v4 | 클러스터·렌더링 |
| argocd CLI, gh CLI | GitOps·PR |
| Claude Code, uv(uvx), Node.js(npx) | 에이전트·MCP |

버전은 고정하고, 올릴 때는 단독 PR 로 한다.

## 처음 한 번 (부트스트랩)

```bash
# 0. 자리표시자 교체 (fork 한 경우: GitHub owner, 저장소 이름)
./scripts/init-repo.sh <github-owner> <repo-name>

# 1. 클러스터 (사람이 plan 을 검토하고 apply)
cd infra/cluster
cp backend.hcl.example backend.hcl && cp dev.tfvars.example dev.tfvars   # 값 채우기
terraform init -backend-config=backend.hcl
terraform plan -var-file=dev.tfvars -out=tfplan
terraform apply tfplan
aws eks update-kubeconfig --region ap-northeast-2 --name "$(terraform output -raw cluster_name)"

# 2. GitHub 저장소 변수 등록 (Settings → Secrets and variables → Actions → Variables)
#    AWS_REGION, AWS_CI_ROLE_ARN(=github_ci_role_arn), ECR_REPOSITORY_URL(=ecr_repository_url)
#    Secrets: ANTHROPIC_API_KEY (CI 실패 시 headless Claude 수정 PR)
#    Environments: prod (승인자 지정)

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
- prod(`otel-demo-prod`)는 승격 PR 이 merge 되기 전까지 동기화하지 않는다. 관측 스택 없이 앱만 올라간다.
- 처음에는 product-catalog 도 업스트림 이미지로 뜬다. `app/product-catalog` 를 바꿔 main 에 merge 하면
  CI 가 ECR 이미지로 교체하는 PR 을 만든다.

## Claude Code

```bash
export AWS_PROFILE=ai-devops-readonly                       # 읽기 전용 프로파일
export ARGOCD_MCP_TOKEN=$(argocd account generate-token --account mcp-readonly)
claude
```

- 쓰기 명령은 `.claude/settings.json` deny 와 `guard-kube-context.sh` Hook 이 막는다.
- 파일을 고치면 `post-edit-validate.sh` 가 fmt/validate/YAML 검사를 돌린다.
- 배포 장애는 `/deploy-triage` Skill 로 조사한다.

## 정리

`docs/teardown.md` 순서를 따른다.

