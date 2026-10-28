#!/usr/bin/env bash
# Grafana 에 Claude 용 Viewer 서비스 계정을 만들고 토큰을 발급한다 (사람이 실행, 2-1).
#   kubectl -n observability port-forward svc/kps-grafana 3000:80 &
#   source <(./scripts/grafana-sa-token.sh)      # GRAFANA_URL · GRAFANA_SERVICE_ACCOUNT_TOKEN 을 현재 셸에 export
# - admin 비밀번호는 Secret 에서 읽어 이 스크립트 안에서만 쓴다. 화면에 출력하지 않는다.
# - Grafana 에 PV 가 없어서 Pod 가 재시작되면 서비스 계정이 사라진다. 그때 다시 실행한다.
# - 토큰은 파일 · Git 에 저장하지 않는다. 셸 환경 변수로만 둔다. 만료 기본 8시간.
set -euo pipefail
NS=${NS:-observability}
URL=${GRAFANA_URL:-http://localhost:3000}
SA_NAME=${SA_NAME:-claude-readonly}
TTL=${TTL_SECONDS:-28800}

user=$(kubectl -n "$NS" get secret grafana-admin -o jsonpath='{.data.admin-user}' | base64 -d)
pass=$(kubectl -n "$NS" get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d)
api() { curl -sSf -u "$user:$pass" -H 'Content-Type: application/json' "$@"; }

id=$(api "$URL/api/serviceaccounts/search?query=$SA_NAME" | python3 -c '
import json,sys
for a in json.load(sys.stdin).get("serviceAccounts",[]):
    if a["name"]==sys.argv[1]: print(a["id"]); break' "$SA_NAME")
if [[ -z "$id" ]]; then
  id=$(api -X POST "$URL/api/serviceaccounts" -d "{\"name\":\"$SA_NAME\",\"role\":\"Viewer\",\"isDisabled\":false}" | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')
  echo "# 서비스 계정 생성: $SA_NAME (Viewer, id=$id)" >&2
fi
role=$(api "$URL/api/serviceaccounts/$id" | python3 -c 'import json,sys;print(json.load(sys.stdin)["role"])')
[[ "$role" == "Viewer" ]] || { echo "# $SA_NAME 의 역할이 $role 이다. Viewer 가 아니면 멈춘다" >&2; exit 1; }

token=$(api -X POST "$URL/api/serviceaccounts/$id/tokens" -d "{\"name\":\"claude-$(date +%Y%m%d%H%M%S)\",\"secondsToLive\":$TTL}" | python3 -c 'import json,sys;print(json.load(sys.stdin)["key"])')
echo "# 토큰 발급 (만료 ${TTL}초). 아래 두 줄이 현재 셸에 적용된다" >&2
echo "export GRAFANA_URL=$URL"
echo "export GRAFANA_SERVICE_ACCOUNT_TOKEN=$token"
