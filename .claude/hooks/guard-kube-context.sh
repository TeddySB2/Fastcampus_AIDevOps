#!/usr/bin/env bash
# PreToolUse(Bash): prod 컨텍스트·네임스페이스를 향한 쓰기 명령을 막는다.
# settings.json 의 deny 목록이 1차 방어선이고, 이 Hook 은 우회 표현(파이프, &&, --context)을 잡는 2차 방어선이다.
# exit 2 = 차단 (stderr 내용이 Claude 에게 전달됨)
set -uo pipefail
input=$(cat)
cmd=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null || true)
[[ -z "$cmd" ]] && exit 0

# kubectl / helm / argocd 가 들어간 명령만 검사
grep -Eq '(^|[;&| ])(kubectl|helm|argocd)( |$)' <<<"$cmd" || exit 0

write_re='(kubectl|helm|argocd)[^;&|]*( apply| create| edit| patch| delete| scale| set | label| annotate| drain| cordon| rollout (restart|undo)| install| upgrade| uninstall| rollback| app (sync|set|delete|rollback))'
if grep -Eq "$write_re" <<<"$cmd"; then
  ctx=$(kubectl config current-context 2>/dev/null || echo unknown)
  if grep -Eqi 'prod' <<<"$ctx $cmd"; then
    echo "BLOCKED: prod 컨텍스트/네임스페이스에 대한 쓰기 명령입니다 (context=$ctx). 변경은 PR 로 제안하세요." >&2
    exit 2
  fi
  echo "BLOCKED: 클러스터 쓰기 명령은 이 저장소 규칙상 Claude 가 실행하지 않습니다. 명령·영향·롤백 방법을 제시하고 사람에게 맡기세요." >&2
  exit 2
fi
exit 0
