# ai-devops-lab

쇼핑몰 서비스(OpenTelemetry Demo)의 dev 환경을 AWS EKS 에 GitOps 로 구축·운영하는 플랫폼팀 저장소다.
이 파일은 **플랫폼팀의 팀 규칙**이다. 이 저장소에서 일하는 사람과 Claude 가 함께 지킨다.

- 이 파일은 작업과 상관없이 늘 지키는 규칙이다. 작업마다 바뀌는 목적 · 범위 · 값 · 완료 기준은 작업 스펙(specs/)에 둔다.
- 작업 스펙은 이 규칙 안에서 쓴다. 규칙을 벗어나야 하는 결정은 스펙에 "예외" 로 표시하고 승인자를 적는다.
- 이 파일을 바꿀 때는 PR 로 하고 CODEOWNERS 승인을 받는다.

## 환경 값 (이 파일에 적지 않는다)

- 계정 · 리전 · 클러스터 · 네임스페이스 · 차트 버전 · 직접 빌드 대상은 현재 작업 스펙의 "환경" · "범위" 에만 둔다.
- 스펙에 없는 값은 추정하지 말고 질문한다 (아래 규칙 5).

## 작업 스펙 (현재 작업의 목적 · 환경 · 범위 · 제약 · 완료 증거)

@specs/observability.md

(이전 작업: specs/eks-demo.md — 환경 값은 그 문서를 따른다)

- 스펙과 다른 요청(범위 밖, 제약 위반)을 받으면 작업 전에 차이를 알리고 확인받는다.
- 스펙 변경은 PR 로만 한다. 작업이 바뀌면 위 import 를 해당 스펙으로 바꾼다.

## 리소스 관리 주체 (한 리소스는 한 도구만 관리한다)

| 대상 | 관리 주체 | 위치 |
| --- | --- | --- |
| VPC, EKS, ECR, IAM, 기반 애드온 | Terraform | infra/cluster |
| Argo CD 와 root Application | Terraform | infra/platform |
| OTel Demo 설정, HPA 등 앱 리소스 | GitOps (Argo CD) | gitops/ |
| 관측 스택, 대시보드, 알람 룰 | GitOps (Argo CD) | gitops/ (observability) |
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
- 관측: 알람 룰은 `./tests/promtool.sh`, 수집 연결은 `./tests/signals.sh`
- 배포: 현재 작업 스펙의 "완료 증거" 를 모두 통과한다. Pod 가 Running 인 것만으로는 완료가 아니다
- 보고: 무엇을 바꿨는지, 어떤 검증을 통과했는지, 확인하지 못한 것이 무엇인지

## 관측 데이터 조회 (Grafana MCP · Prometheus · Loki · Tempo)

- Grafana 는 MCP(`grafana`, Viewer 서비스 계정, 쓰기 도구 없음)로만 조회한다. 대시보드 · 알람 · 데이터소스 변경은 `gitops/` PR 로 한다.
- 모든 답에 근거 세 가지를 붙인다: **실행한 쿼리**, **시간 범위**(절대 시각, KST), **데이터소스**. 숫자만 말하지 않는다.
- 빈 결과는 "정상" 이 아니다. 메트릭 · 라벨 이름부터 목록 조회(`list_prometheus_metric_names`, `list_prometheus_label_values`, `list_loki_label_names`)로 확인하고, 그래도 비면 "데이터 없음" 으로 보고한다.
- 메트릭 이름을 추측하지 않는다. OTLP 로 들어온 이름은 점이 밑줄로, 단위 접미사(`_seconds`, `_milliseconds`, `_total`)가 붙는다.
- 조회 범위는 기본 1시간, 최대 24시간. 더 길게 볼 때는 이유를 먼저 말한다. 로그는 서비스 라벨(`service_name`)을 반드시 건다.
- 조회 실패(연결 오류 · 권한 · 타임아웃)는 "확인 필요" 로 보고한다. 실패를 "이상 없음" 으로 바꾸지 않는다.
- 로그 · 트레이스에 개인정보(이메일, 카드 번호)가 보이면 인용하지 않고 "민감 정보 있음" 으로만 적는다.

