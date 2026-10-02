# 강의 진행 자료 (「AI DevOps 구축과 운영」 Part 3)

이 디렉터리는 강사·수강생용이다. 저장소 자체는 "플랫폼팀이 dev 환경을 구축한다" 는 설정으로 작성돼 있고,
Claude 가 강의 맥락에 끌려가지 않도록 `.claude/settings.json` 에서 이 디렉터리 읽기를 막아 두었다.

## 진행 방식

- **Ch1 (1-1, 1-2) 은 강사 시연이다.** 스펙을 쓰고 규칙을 다듬는 과정을 보여주고, 그 결과를 `p3-ch1-end` 태그로 제공한다.
- **2-1 부터 직접 실습한다.** 처음 한 번 `p3-ch1-end` 에서 작업 브랜치를 만들고, 이후 클립은 같은 브랜치에서 이어간다.
  ```bash
  git clone https://github.com/TeddySB2/Fastcampus_AIDevOps.git
  cd Fastcampus_AIDevOps
  git switch -c part3 p3-ch1-end
  ```
- 태그는 "기준 상태" 다. 막히면 브랜치를 바꾸지 말고 필요한 경로만 비교하거나 가져온다.
  ```bash
  git diff p3-ch2-end -- infra/cluster                       # 차이부터 본다
  git restore --source p3-ch2-end -- infra/cluster           # 기준 코드로 맞춘다
  ```
- 처음부터 다시 하거나 중간 클립부터 시작하려면 그 클립의 시작 태그에서 새 브랜치를 만든다.

## 클립별 시작 상태 (태그)

| 클립 | 태그 | 상태 |
| --- | --- | --- |
| 1-1 · 1-2 (시연) | `p3-ch1-start` | 요구사항 메모, 스펙 템플릿, CLAUDE.md 최소본, .claude 설정, app/product-catalog. infra · gitops 없음. 시연 메모: `course/1-1.md`, `course/1-2.md` |
| 2-1 (실습 시작) | `p3-ch1-end` | Ch1 시연 결과: 스펙, 다듬은 CLAUDE.md 와 권한 설정 |
| 2-2 | `p3-ch2-start` | infra/cluster 에 versions · backend · providers · github-oidc 만 |
| 2-2 끝 | `p3-ch2-end` | infra 기준 코드 |
| 그 외 | `main` (p3-end) | Part 3 완료 상태 |

## 장면 재현

| 스크립트 | 장면 | 클립 |
| --- | --- | --- |
| `scenarios/flag.sh productCatalogFailure on` | Pod 는 Running 인데 Smoke 실패 | 2-3 |
| `scenarios/flag.sh loadGeneratorFloodHomepage on` (또는 Locust UI `/loadgen/`) | 부하 증가 → HPA 확장 | 4-1 |
| `scenarios/break-values.sh` | 잘못된 이미지 태그 → Degraded | 3-2 |
| `scenarios/break-env.sh` | DB 설정 누락 → CrashLoopBackOff | 5-1 |
| `scenarios/break-oom.sh` | memory limit 축소 → OOMKilled | 5-1 |
| `scenarios/reset.sh <tag>` | 시작 상태로 되돌리기 | 매 테이크 |


## 검증 상태

| 항목 | 결과 |
| --- | --- |
| Terraform 문법·타입 (`validate`, OpenTofu 1.10 로 대체 실행) | 통과 (cluster, platform) |
| `checkov` (infra/.checkov.yaml 예외 3건 포함) | 35 통과 / 0 실패 |
| GitHub Actions (`actionlint`) | 통과 |
| `kubeconform` (HPA) | 통과 |
| `tests/smoke.sh` (모의 서버) | 정상·실패 경로 모두 기대대로 |
| `helm template` 렌더링, 실제 `terraform plan/apply`, 클러스터 배포 | **미실행 — 1단계 환경 완주에서 확인** |
