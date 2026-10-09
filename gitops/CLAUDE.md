# gitops/ 규칙

- dev(`otel-demo-dev`)는 Argo CD 가 추적하는 브랜치(platform 의 `gitops_revision`)에 반영되면 자동 동기화된다. prod 는 사람이 Sync 한다.
- Application 의 `repoURL` 은 Argo CD 가 읽는 원격 저장소(`git remote get-url origin`)다. 로컬 변경은 push 해야 반영된다.
- 환경 차이는 `values/otel-demo/dev.yaml`, `prod.yaml` 에만 둔다. 공통 값은 `common.yaml`.
- product-catalog 이미지는 `"<git sha>@sha256:<digest>"` 형식으로만 지정한다. `latest` 금지.
- product-catalog 의 `repository` 에는 Terraform 출력 `ecr_repository_url` 을 그대로 쓴다. ECR 주소 안의 계정 ID 는 인증 정보가 아니므로 values 에 적어도 된다 (스펙 2장의 "계정 ID 를 적지 않는다" 는 실행 전 확인용 기대값에 대한 것이다).
- 클러스터에서 직접 고친 내용은 Argo CD 가 되돌린다(selfHeal). 수정은 항상 이 디렉터리에서 한다.
- 차트 값의 키는 추측하지 말고 차트의 values.yaml 에서 확인한다.

## 변경 전 검증

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm template otel-demo open-telemetry/opentelemetry-demo --version 0.42.1 \
  -f gitops/values/otel-demo/common.yaml -f gitops/values/otel-demo/dev.yaml > /tmp/render.yaml
kubeconform -summary -ignore-missing-schemas /tmp/render.yaml
```
