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

관측 스택(`values/observability`, `apps/{kube-prometheus-stack,loki,tempo}.yaml`)을 바꿀 때. 차트 버전은 Application 의 `targetRevision` 과 같게:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm template kube-prometheus-stack prometheus-community/kube-prometheus-stack --version 92.14.1 \
  -n observability --include-crds -f gitops/values/observability/kube-prometheus-stack.yaml > /tmp/kps.yaml
helm template loki grafana-community/loki --version 20.0.2 -n observability \
  -f gitops/values/observability/loki.yaml > /tmp/loki.yaml
helm template tempo grafana-community/tempo --version 3.2.1 -n observability \
  -f gitops/values/observability/tempo.yaml > /tmp/tempo.yaml
kubeconform -summary -ignore-missing-schemas -skip CustomResourceDefinition /tmp/kps.yaml /tmp/loki.yaml /tmp/tempo.yaml
kubeconform -summary -strict gitops/manifests/observability/*.yaml
```

- 관측 스택의 Helm 서브차트 값은 `null` 로 지워지지 않는다(그대로 `null` 로 렌더링된다). Demo Collector 의 안 쓰는 exporter 는 정의만 두고 파이프라인에서 뺀다.
- 대시보드는 `manifests/observability` 의 ConfigMap(label `grafana_dashboard=1`)만 인정한다. Grafana UI 에서 고친 것은 저장되지 않는다.
