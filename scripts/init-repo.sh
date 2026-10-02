#!/usr/bin/env bash
# 저장소를 fork/clone 한 뒤 한 번 실행해 자리표시자를 바꾼다.
#   ./scripts/init-repo.sh <github-owner>
set -euo pipefail
OWNER=${1:?usage: init-repo.sh <github-owner>}
ROOT=$(git rev-parse --show-toplevel)
grep -rl "REPLACE_ME_OWNER" "$ROOT" --exclude-dir=.git | while read -r f; do
  sed -i.bak "s/REPLACE_ME_OWNER/${OWNER}/g" "$f" && rm -f "$f.bak"
  echo "updated: ${f#$ROOT/}"
done
