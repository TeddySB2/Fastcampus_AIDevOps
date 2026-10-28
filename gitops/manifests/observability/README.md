# gitops/manifests/observability

Argo CD Application `obs-config` 가 이 디렉터리를 읽는다 (`gitops/apps/observability.yaml`, wave 2).

- `dashboards/` — Grafana 대시보드 ConfigMap (`grafana_dashboard: "1"` 라벨). sidecar 가 등록한다.
- `rules/` — PrometheusRule. 알람 계약은 `specs/observability.md` 6장.
- `tests/` — promtool 단위 테스트. `./tests/promtool.sh` 로 실행한다. Argo CD 는 이 디렉터리와 `*.md` 를 배포하지 않는다.
