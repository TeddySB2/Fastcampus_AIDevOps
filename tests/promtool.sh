#!/usr/bin/env bash
# 알람 룰 검증: PrometheusRule(CRD)에서 spec 만 꺼내 promtool 로 문법 검사와 단위 테스트를 한다.
#   ./tests/promtool.sh            # gitops/manifests/observability/rules 전체
# 필요 도구: promtool (Prometheus 배포판에 포함), python3 + PyYAML
# CI(.github/workflows/ci-observability.yml)도 이 스크립트를 그대로 실행한다.
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel)
RULES="$ROOT/gitops/manifests/observability/rules"
TESTS="$ROOT/gitops/manifests/observability/tests"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

command -v promtool >/dev/null || { echo "promtool 이 없다 (brew install prometheus 또는 Prometheus 릴리스의 promtool)"; exit 1; }

shopt -s nullglob
files=("$RULES"/*.yaml)
[ ${#files[@]} -gt 0 ] || { echo "룰 파일이 없다: $RULES"; exit 0; }

for f in "${files[@]}"; do
  name=$(basename "$f" .yaml)
  python3 - "$f" "$WORK/$name.rules.yaml" <<'PY'
import sys, yaml
src, dst = sys.argv[1], sys.argv[2]
docs = [d for d in yaml.safe_load_all(open(src)) if d]
groups = []
for d in docs:
    if d.get("kind") != "PrometheusRule":
        sys.exit(f"{src}: PrometheusRule 이 아닌 문서가 있다 ({d.get('kind')})")
    groups += d["spec"]["groups"]
yaml.safe_dump({"groups": groups}, open(dst, "w"), allow_unicode=True, sort_keys=False)
PY
  echo "== check: $(basename "$f")"
  promtool check rules "$WORK/$name.rules.yaml"
done

tests=("$TESTS"/*.test.yaml)
for t in "${tests[@]}"; do
  cp "$t" "$WORK/"
  echo "== test: $(basename "$t")"
  (cd "$WORK" && promtool test rules "$(basename "$t")")
done
echo "OK: 룰 ${#files[@]}개, 테스트 ${#tests[@]}개"
