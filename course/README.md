# 강의 진행 자료 (「AI DevOps 구축과 운영」 Part 3)

이 디렉터리는 강사·수강생용이다. 저장소 자체는 "플랫폼팀이 dev 환경을 구축한다" 는 설정으로 작성돼 있고,
Claude 가 강의 맥락에 끌려가지 않도록 `.claude/settings.json` 에서 이 디렉터리 읽기를 막아 두었다.

## 진행 방식

- **Ch1 (1-1, 1-2) 은 강사 시연이다.** 스펙을 쓰고 규칙을 다듬는 과정을 보여주고, 그 결과를 `p3-ch1-end` 태그로 제공한다.
- **2-1 부터 직접 실습한다.** 저장소를 Fork 한 뒤 처음 한 번, 내 fork 의 `part3` 를 `p3-ch1-end` 로 되돌린다.
  Argo CD · 시나리오 스크립트 · CI 가 모두 `part3` 를 기준으로 하므로 작업 브랜치 이름도 `part3` 를 그대로 쓴다.
  ```bash
  git clone https://github.com/<내계정>/Fastcampus_AIDevOps.git
  cd Fastcampus_AIDevOps
  git fetch https://github.com/TeddySB2/Fastcampus_AIDevOps.git 'refs/tags/p3-*:refs/tags/p3-*'   # 태그는 원본에서
  gh repo set-default <내계정>/Fastcampus_AIDevOps          # upstream 원격은 추가하지 않는다 (gh 가 원본으로 PR 을 연다)
  git switch -C part3 p3-ch1-end && git push -f origin part3
  ./scripts/init-repo.sh <내계정>                            # gitops/infra/CODEOWNERS 의 저장소 주소를 내 fork 로
  git commit -am "chore: 저장소 주소를 내 fork 로" && git push origin part3
  ```
- GitHub 에서 PR 을 merge 한 뒤에는 항상 로컬도 맞춘다: `git pull origin part3`
- 태그는 "기준 상태" 다. 막히면 브랜치를 바꾸지 말고 필요한 경로만 비교하거나 가져온다.
  ```bash
  git diff p3-ch2-end -- infra/cluster                       # 차이부터 본다
  git restore --source p3-ch2-end -- infra/cluster           # 기준 코드로 맞춘다
  ```
- 처음부터 다시 하거나 중간 클립부터 시작하려면 그 클립의 시작 태그로 `part3` 를 다시 맞춘다.
  ```bash
  git switch -C part3 p3-ch3-start && git push -f origin part3
  ./scripts/init-repo.sh <내계정> && git commit -am "chore: 저장소 주소를 내 fork 로" && git push origin part3
  ```
  태그에서 `git restore --source <태그> -- gitops` 처럼 경로를 가져온 뒤에도 `./scripts/init-repo.sh <내계정>` 를 다시 실행한다.

## 클립별 시작 상태 (태그)

| 클립 | 태그 | 상태 |
| --- | --- | --- |
| 1-1 · 1-2 (시연) | `p3-ch1-start` | 요구사항 메모, 스펙 템플릿, CLAUDE.md 최소본, .claude 설정, app/product-catalog. infra · gitops 없음. 시연 메모: `course/1-1.md`, `course/1-2.md` |
| 2-1 (실습 시작) | `p3-ch1-end` | Ch1 시연 결과: 스펙, 다듬은 CLAUDE.md 와 권한 설정. infra/cluster 뼈대(versions · backend · providers) 포함 |
| 2-2 | `p3-ch2-start` | 2-1 과 같은 상태 (따로 가져올 것 없음) |
| 2-2 끝 · 2-3 | `p3-ch2-end` | infra 기준 코드 (cluster · platform), gitops 바탕 (AppProject · values), tests/smoke.sh |
| 2-3 끝 · 3-1 | `p3-ch2-3-end` | otel-demo-dev 앱 정의 (dev.yaml 이미지는 각자 ECR digest 로) |
| 3-2 | `p3-ch3-start` | 장애 시나리오(break-values) · deploy-triage 스킬 |
| 4-1 · 4-2 | `p3-ch4-start` | 3-2 끝 상태 (HPA 없음) |
| 5-1 ~ 5-3 | `p3-ch5-start` | 4-1 결과(frontend HPA) + 장애 시나리오(break-env · break-oom) |
| 6-1 | `p3-ch6-start` | 5장 끝 상태 + CI 규칙(.github/CLAUDE.md), OIDC 신뢰 브랜치 변수화 |
| 6-3 | `p3-ch6-3-start` | 6-2 끝 상태 + 승격 워크플로(promote.yml), prod 앱(otel-demo-prod, 수동 Sync), prod.yaml 정리. `git restore --source p3-ch6-3-start -- .github gitops` 로 가져온 뒤 PR 로 merge. GitHub Environment `prod` 는 각자 Settings 에서 만든다 |
| 6-4 · 6-5 | `p3-ch6-4-start` | 6-3 끝 상태 + AI 자동 수정 워크플로(.github/workflows/ai-fix.yml), 시연용 시나리오(scenarios/break-categories.sh). `git restore --source p3-ch6-4-start -- .github scenarios` 로 가져온 뒤 PR 로 merge. Claude GitHub App 설치와 Secret(CLAUDE_CODE_OAUTH_TOKEN 또는 ANTHROPIC_API_KEY)은 각자 한다 |
| 완성본 | `part3` (원본 저장소) | Part 3 완료 상태 |

## 장면 재현

| 스크립트 | 장면 | 클립 |
| --- | --- | --- |
| `scenarios/flag.sh productCatalogFailure on` | Pod 는 Running 인데 Smoke 실패 | 선택 (2-3 이후, 영상에는 없음) |
| `scenarios/flag.sh loadGeneratorFloodHomepage on` (또는 Locust UI `/loadgen/`) | 부하 증가 → HPA 확장 | 4-1 |
| `scenarios/break-values.sh` | 잘못된 이미지 태그 → Degraded | 3-2 |
| `scenarios/break-env.sh` | DB 설정 누락 → CrashLoopBackOff | 5-1 |
| `scenarios/break-oom.sh` | memory limit 축소 → OOMKilled | 5-1 |
| `git switch -C part3 <태그> && git push -f origin part3` | 시작 상태로 되돌리기 | 매 테이크 |


## 검증 상태

| 항목 | 결과 |
| --- | --- |
| Terraform 문법·타입 (`validate`, OpenTofu 1.10 로 대체 실행) | 통과 (cluster, platform) |
| `checkov` (infra/.checkov.yaml 예외 3건 포함) | 35 통과 / 0 실패 |
| GitHub Actions (`actionlint`) | 통과 |
| `kubeconform` (HPA) | 통과 |
| `tests/smoke.sh` (모의 서버) | 정상·실패 경로 모두 기대대로 |
| `helm template` 렌더링, 실제 `terraform plan/apply`, 클러스터 배포 | **미실행 — 1단계 환경 완주에서 확인** |
