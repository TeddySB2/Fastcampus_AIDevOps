# .github/ 규칙 (CI)

- CI 는 검사하고, 이미지를 올리고, 배포 PR 을 만드는 데까지만 한다. 클러스터에 직접 배포하지 않는다 (`kubectl` · `helm` · `argocd` 금지).
- PR 은 Argo CD 가 읽는 브랜치(platform 의 `gitops_revision`)로 열린다. `pull_request` 트리거에 `branches` 필터를 걸지 않는다.
- 워크플로는 대상 디렉터리와 워크플로 파일이 바뀔 때만 돌도록 `paths` 를 건다.

## PR 에서 하는 일 (리뷰 전 코드)

- 순서: 테스트 → 이미지 빌드(push 하지 않음) → Trivy 스캔 → SBOM.
- Trivy 는 CRITICAL · HIGH 중 수정 버전이 있는 것만 실패시킨다 (`ignore-unfixed: true`, `exit-code: "1"`).
- 스캔 예외는 `.trivyignore` 에 근거와 만료일을 함께 적을 때만 추가한다.
- SBOM 은 SPDX JSON 으로 만들어 워크플로 아티팩트로 남긴다.
- PR 에서는 클라우드 자격 증명을 받지 않는다.

## 권한과 자격 증명

- 워크플로 최상단에 `permissions: contents: read` 를 두고, 더 필요한 job 에서만 올린다.
- AWS 는 OIDC 역할로만 인증한다. 장기 액세스 키를 secret 으로 쓰지 않는다.
- 이미지 태그는 git sha 다. `latest` 금지 (ECR 은 태그 불변).

## 완료 조건

- `actionlint` 통과.
- PR 에서 실제로 돌린 체크 이름과 결과를 보고한다. 확인하지 못한 것도 적는다.
