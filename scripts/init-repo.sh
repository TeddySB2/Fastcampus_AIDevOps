#!/usr/bin/env bash
# 저장소를 fork 해서 clone 한 뒤 한 번 실행한다. 원본(TeddySB2) 주소를 내 fork 로 바꾼다.
#   ./scripts/init-repo.sh <github-owner> [repo-name]
#   예) ./scripts/init-repo.sh my-github-id            # repo-name 기본값: Fastcampus_AIDevOps
# 바꾸는 것: GitOps 저장소 주소(gitops/apps, platform.tfvars.example), GitHub OIDC 대상 저장소(dev.tfvars.example),
#            CODEOWNERS·스펙·요구사항의 승인자(@TeddySB2)
# 바꾸지 않는 것: AWS 리소스 이름(ai-devops-lab-dev 등), course/ (강의 자료)
# 여러 번 실행해도 된다. 태그에서 gitops/ 등을 restore 한 뒤에는 다시 실행한다.
set -euo pipefail
OWNER=${1:?usage: init-repo.sh <github-owner> [repo-name]}
REPO=${2:-Fastcampus_AIDevOps}
SRC_OWNER=TeddySB2
SRC_REPO=Fastcampus_AIDevOps
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"

if [ "$OWNER/$REPO" = "$SRC_OWNER/$SRC_REPO" ]; then
  echo "원본 저장소와 같은 값이라 바꿀 것이 없다." ; exit 0
fi

changed=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  sed -i.bak \
    -e "s#${SRC_OWNER}/${SRC_REPO}#${OWNER}/${REPO}#g" \
    -e "s#@${SRC_OWNER}#@${OWNER}#g" \
    "$f"
  if cmp -s "$f" "$f.bak"; then rm -f "$f.bak"; else rm -f "$f.bak"; echo "updated: $f"; changed=1; fi
done < <(grep -rlIF --exclude-dir=.terraform --exclude-dir=.git "${SRC_OWNER}" gitops infra .github specs docs 2>/dev/null || true)

if [ "$changed" = 0 ]; then
  echo "이미 ${OWNER}/${REPO} 기준이다 (바꿀 것 없음)."
else
  echo
  echo "다음 단계: git diff 로 확인한 뒤 커밋해서 part3 에 push 한다."
  echo "  git commit -am \"chore: 저장소 주소를 ${OWNER}/${REPO} 로\" && git push origin part3"
fi
