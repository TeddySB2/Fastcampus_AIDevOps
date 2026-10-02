#!/usr/bin/env bash
# flagd 플래그의 defaultVariant (와 targeting 의 조건 일치 결과) 를 바꾼다 (장애·부하 재현용).
#   ./scenarios/flag.sh productCatalogFailure on
#   ./scenarios/flag.sh loadGeneratorFloodHomepage on
#   ./scenarios/flag.sh --list          # 플래그와 variant 목록 (차트 0.42.1 기준 18개)
# flagd 는 emptyDir 의 파일을 읽으므로 Argo CD 의 selfHeal 과 충돌하지 않는다.
# 초기화: kubectl -n $NS rollout restart deploy/flagd  (init 컨테이너가 ConfigMap 을 다시 복사)
set -euo pipefail
NS="${NS:-otel-demo-dev}"
FILE=/app/data/demo.flagd.json   # flagd-ui 사이드카에서 본 경로
POD=$(kubectl -n "$NS" get pod -l app.kubernetes.io/component=flagd -o jsonpath='{.items[0].metadata.name}')

current=$(kubectl -n "$NS" exec "$POD" -c flagd-ui -- cat "$FILE")

if [[ "${1:-}" == "--list" || $# -lt 2 ]]; then
  echo "$current" | python3 -c '
import json,sys
for k,v in json.load(sys.stdin)["flags"].items():
    print(f"{k:32} default={v.get(\"defaultVariant\")!s:10} variants={list(v.get(\"variants\",{}).keys())}")'
  exit 0
fi

name=$1 variant=$2
updated=$(echo "$current" | python3 -c '
import json,sys
name,variant=sys.argv[1],sys.argv[2]
d=json.load(sys.stdin)
f=d["flags"].get(name) or sys.exit(f"unknown flag: {name}")
if variant not in f.get("variants",{}): sys.exit(f"unknown variant {variant}; choose from {list(f[\"variants\"])}")
f["defaultVariant"]=variant
# targeting 이 있으면 defaultVariant 보다 우선한다. 차트 0.42.1 의 productCatalogFailure 는
# {"if":[product_id == OLJCESPC7Z, "off", "off"]} 라서 조건이 맞는 쪽 결과도 같이 바꿔야 실제로 실패한다.
t=f.get("targeting")
if isinstance(t,dict) and isinstance(t.get("if"),list) and len(t["if"])>=2:
    t["if"][1]=variant
print(json.dumps(d,indent=2))' "$name" "$variant")

echo "$updated" | kubectl -n "$NS" exec -i "$POD" -c flagd-ui -- sh -c "cat > $FILE"
echo "[$NS] $name -> $variant"
