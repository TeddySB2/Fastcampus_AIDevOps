#!/usr/bin/env bash
# 6-5 시연: "카테고리 파싱 단순화" 라는 그럴듯한 PR 로 product-catalog 테스트를 깨뜨린다.
#   DB 값이 항상 ", " 로 구분된다고 가정하고 TrimSpace 와 빈 항목 처리를 지운다
#   → catalog_test.go 의 trim · no_space · empty_item 이 실패 → CI 실패 → ai-fix 워크플로가 깨어난다
source "$(dirname "$0")/_pr.sh"
B=perf-categories
F="$ROOT/app/product-catalog/main.go"
open_pr $B
perl -0pi -e 's{\t\t// Trim whitespace from each category and drop empty items \(e\.g\. "a,,b"\)\n\t\tfor _, cat := range strings\.Split\(categoriesStr, ","\) \{\n\t\t\tif c := strings\.TrimSpace\(cat\); c != "" \{\n\t\t\t\tcategories = append\(categories, c\)\n\t\t\t\}\n\t\t\}\n}{\t\t// DB 값은 항상 ", " 로 구분되므로 한 번에 자른다 (반복문 · TrimSpace 제거)\n\t\tcategories = strings.Split(categoriesStr, ", ")\n}' "$F"
git -C "$ROOT" diff --quiet -- "$F" && { echo "main.go 가 바뀌지 않았습니다. 이미 적용됐거나 코드가 예상과 다릅니다" >&2; git -C "$ROOT" checkout -q "$BASE"; exit 1; }
git -C "$ROOT" add "$F"
git -C "$ROOT" commit -q -m "perf(product-catalog): 카테고리 파싱 단순화"
git -C "$ROOT" push -q -u origin "$B" --force-with-lease
gh pr create --base "$BASE" --head "$B" --title "perf(product-catalog): 카테고리 파싱 단순화" \
  --body "DB 의 categories 값은 항상 \", \" 로 구분되므로 반복문과 TrimSpace 를 빼고 한 번에 자릅니다." \
  || { echo "PR 생성 실패: gh auth status 로 계정을 확인하세요" >&2; git -C "$ROOT" checkout -q "$BASE"; exit 1; }
git -C "$ROOT" checkout -q "$BASE"
