#!/usr/bin/env bash
# 테이크를 다시 갈 때 시작 상태로 되돌린다. (강사 리허설·촬영 전용)
#   ./scenarios/reset.sh p3-ch5-start
# 1) 시나리오 PR 닫기와 브랜치 삭제  2) main 을 태그로 되돌리기(강제 push, 확인 필요)
# 3) flagd 초기화  4) Argo CD 동기화 대기
set -euo pipefail
TAG=${1:?usage: reset.sh <tag>}
NS=${NS:-otel-demo-dev}
ROOT=$(git rev-parse --show-toplevel)

for pr in $(gh pr list --search "head:scenario/" --json number -q '.[].number'); do
  gh pr close "$pr" --delete-branch
done

read -r -p "main 을 $TAG 로 강제 되돌립니다. 계속할까요? [y/N] " ok
[[ "$ok" == "y" ]] || { echo "중단"; exit 1; }
git -C "$ROOT" fetch -q --tags origin
git -C "$ROOT" checkout -q main
git -C "$ROOT" reset -q --hard "$TAG"
git -C "$ROOT" push -q --force-with-lease origin main

kubectl -n "$NS" rollout restart deploy/flagd
if command -v argocd >/dev/null; then
  argocd app sync otel-demo-dev --prune && argocd app wait otel-demo-dev --health --timeout 600
else
  echo "argocd CLI 가 없으면 UI 에서 Refresh/Sync 하세요"
fi
echo "reset 완료: $TAG"
