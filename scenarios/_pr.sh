#!/usr/bin/env bash
# 시나리오용 PR 을 만드는 공통 함수. 다른 스크립트에서 source 한다.
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel)
VALUES="$ROOT/gitops/values/otel-demo/dev.yaml"
# PR 을 올릴 브랜치 = Argo CD 가 읽는 브랜치. 기본은 실행할 때의 현재 브랜치 (실습: part3)
BASE="${BASE:-$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)}"

need() { command -v "$1" >/dev/null || { echo "필요한 도구가 없습니다: $1" >&2; exit 1; }; }
need git; need gh; need yq

open_pr() { # branch
  local branch=$1
  git -C "$ROOT" checkout -q "$BASE" && git -C "$ROOT" pull -q --ff-only origin "$BASE"
  git -C "$ROOT" checkout -q -B "$branch"
}

push_pr() { # branch title body
  local branch=$1 title=$2 body=$3
  git -C "$ROOT" add -A gitops/
  git -C "$ROOT" commit -q -m "$title"
  git -C "$ROOT" push -q -u origin "$branch" --force-with-lease
  gh pr create --base "$BASE" --head "$branch" --title "$title" --body "$body"
  git -C "$ROOT" checkout -q "$BASE"
}
