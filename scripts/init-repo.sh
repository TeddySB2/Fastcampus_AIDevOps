#!/usr/bin/env bash
# 저장소를 fork/clone 한 뒤 한 번 실행해 자리표시자를 바꾼다.
#   ./scripts/init-repo.sh <github-owner> [repo-name]
#   예) ./scripts/init-repo.sh TeddySB2 Fastcampus_AIDevOps
# 바꾸는 것: GitOps 저장소 주소(REPLACE_ME_OWNER/ai-devops-lab), CODEOWNERS(@REPLACE_ME_OWNER)
# 바꾸지 않는 것: AWS 리소스 이름(ai-devops-lab-dev 등)
set -euo pipefail
OWNER=${1:?usage: init-repo.sh <github-owner> [repo-name]}
REPO=${2:-ai-devops-lab}
ROOT=$(git rev-parse --show-toplevel)
grep -rl "REPLACE_ME_OWNER" "$ROOT" --exclude-dir=.git --exclude=init-repo.sh | while read -r f; do
  sed -i.bak -e "s#REPLACE_ME_OWNER/ai-devops-lab#${OWNER}/${REPO}#g" -e "s#REPLACE_ME_OWNER#${OWNER}#g" "$f" && rm -f "$f.bak"
  echo "updated: ${f#$ROOT/}"
done
