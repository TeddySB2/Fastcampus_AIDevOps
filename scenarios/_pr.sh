#!/usr/bin/env bash
# 시나리오용 PR 을 만드는 공통 함수. 다른 스크립트에서 source 한다.
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel)
VALUES="$ROOT/gitops/values/otel-demo/dev.yaml"

need() { command -v "$1" >/dev/null || { echo "필요한 도구가 없습니다: $1" >&2; exit 1; }; }
need git; need gh; need yq

open_pr() { # branch title body
  local branch=$1 title=$2 body=$3
  git -C "$ROOT" checkout -q main && git -C "$ROOT" pull -q --ff-only
  git -C "$ROOT" checkout -q -B "$branch"
}

push_pr() { # branch title body
  local branch=$1 title=$2 body=$3
  git -C "$ROOT" add -A gitops/
  git -C "$ROOT" commit -q -m "$title"
  git -C "$ROOT" push -q -u origin "$branch" --force-with-lease
  gh pr create --base main --head "$branch" --title "$title" --body "$body"
  git -C "$ROOT" checkout -q main
}
