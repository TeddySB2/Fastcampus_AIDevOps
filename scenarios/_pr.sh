#!/usr/bin/env bash
# 시나리오용 PR 을 만드는 공통 함수. 다른 스크립트에서 source 한다.
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel)
VALUES="$ROOT/gitops/values/otel-demo/dev.yaml"

need() { command -v "$1" >/dev/null || { echo "필요한 도구가 없습니다: $1" >&2; exit 1; }; }
need git; need gh; need yq

# PR 을 올릴 브랜치 = Argo CD 가 읽는 브랜치 (dev 앱의 values 소스 targetRevision, 실습: part3)
# 어느 브랜치에서 실행해도 같은 곳으로 간다. 직접 정하려면 BASE=main ./scenarios/...
BASE="${BASE:-$(yq '.spec.sources[] | select(.ref == "values") | .targetRevision' "$ROOT/gitops/apps/otel-demo-dev.yaml")}"
[[ -n "$BASE" && "$BASE" != null ]] || { echo "BASE 브랜치를 찾지 못했습니다. BASE=part3 처럼 지정하세요" >&2; exit 1; }

open_pr() { # branch
  local branch=$1
  git -C "$ROOT" checkout -q "$BASE" && git -C "$ROOT" pull -q --ff-only origin "$BASE"
  git -C "$ROOT" checkout -q -B "$branch"
}

push_pr() { # branch title body
  local branch=$1 title=$2 body=$3
  git -C "$ROOT" add -A gitops/
  git -C "$ROOT" diff --cached --quiet && { echo "바뀐 내용이 없습니다. 이미 장애가 들어간 상태인지 확인하세요" >&2; git -C "$ROOT" checkout -q "$BASE"; exit 1; }
  git -C "$ROOT" commit -q -m "$title"
  git -C "$ROOT" push -q -u origin "$branch" --force-with-lease
  gh pr create --base "$BASE" --head "$branch" --title "$title" --body "$body" \
    || { echo "PR 생성 실패: gh auth status 로 계정을 확인하세요" >&2; git -C "$ROOT" checkout -q "$BASE"; exit 1; }
  git -C "$ROOT" checkout -q "$BASE"
}
