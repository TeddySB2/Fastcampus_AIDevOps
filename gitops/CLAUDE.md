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

## 관측 스택 (observability)

- `apps/observability.yaml`: AppProject `observability` + Application 4개 (kube-prometheus-stack · Loki · Tempo · obs-config).
- values 는 `values/observability/`, 대시보드 · 알람 룰은 `manifests/observability/` (obs-config 가 읽는다).
- 대시보드는 `grafana_dashboard: "1"` 라벨의 ConfigMap 으로만 추가한다. 데이터소스 uid 는 `prometheus`, `loki`, `tempo`.
- 알람 룰은 PrometheusRule 로 쓰고 `severity` 는 `page` · `ticket` 중 하나, `runbook_url` · `summary` 필수 (specs/observability.md 6장).
- Collector 설정은 Demo 차트 안에 있다 (`values/otel-demo/dev.yaml` 의 `opentelemetry-collector.config`). 기본 exporter 는 null 로 지우지 않는다(렌더링 결과에 빈 값이 남아 Collector 가 시작하지 못한다). pipeline 에서 빼기만 한다.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm template kps prometheus-community/kube-prometheus-stack --version 92.10.0 -n observability \
  -f gitops/values/observability/kube-prometheus-stack.yaml > /tmp/kps.yaml
helm template loki grafana-community/loki --version 18.16.1 -n observability -f gitops/values/observability/loki.yaml > /tmp/loki.yaml
helm template tempo grafana-community/tempo --version 3.2.0 -n observability -f gitops/values/observability/tempo.yaml > /tmp/tempo.yaml
kubeconform -summary -ignore-missing-schemas /tmp/kps.yaml /tmp/loki.yaml /tmp/tempo.yaml
./tests/promtool.sh

# Collector 설정 검사 (Demo 차트가 렌더링한 설정을 꺼내 Demo 와 같은 버전의 collector 로 validate)
helm template otel-demo open-telemetry/opentelemetry-demo --version 0.42.1 \
  -f gitops/values/otel-demo/common.yaml -f gitops/values/otel-demo/dev.yaml \
  | yq 'select(.kind == "ConfigMap" and .metadata.name == "otel-collector-agent") | .data.relay' > /tmp/collector.yaml
podman run --rm -e K8S_NODE_NAME=local -v /tmp/collector.yaml:/c.yaml:ro \
  otel/opentelemetry-collector-contrib:0.160.0 validate --feature-gates=service.profilesSupport --config=/c.yaml
# kubeletstats · hostmetrics 의 경로 오류는 클러스터 밖이라 나는 것이다. exporter · pipeline 오류만 본다
```
