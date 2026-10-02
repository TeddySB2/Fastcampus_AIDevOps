# gitops/ 규칙

- dev(`otel-demo-dev`)는 main 에 merge 되면 자동 동기화된다. prod 는 사람이 Sync 한다.
- 환경 차이는 `values/otel-demo/dev.yaml`, `prod.yaml` 에만 둔다. 공통 값은 `common.yaml`.
- product-catalog 이미지는 `"<git sha>@sha256:<digest>"` 형식으로만 지정한다. `latest` 금지.
- 클러스터에서 직접 고친 내용은 Argo CD 가 되돌린다(selfHeal). 수정은 항상 이 디렉터리에서 한다.
- 차트 값의 키는 추측하지 말고 차트의 values.yaml 에서 확인한다.

## 변경 전 검증

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm template otel-demo open-telemetry/opentelemetry-demo --version 0.42.1 \
  -f gitops/values/otel-demo/common.yaml -f gitops/values/otel-demo/dev.yaml > /tmp/render.yaml
kubeconform -summary -ignore-missing-schemas /tmp/render.yaml gitops/manifests/dev/
```
