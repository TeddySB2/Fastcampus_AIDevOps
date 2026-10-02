#!/usr/bin/env bash
# 3-2: 존재하지 않는 이미지 태그로 바꾸는 "잘못된 values" PR → merge 하면 Argo CD 가 Degraded
source "$(dirname "$0")/_pr.sh"
B=scenario/bad-image-tag
open_pr $B
yq -i '.components."product-catalog".imageOverride.tag = "does-not-exist"' "$VALUES"
# repository 가 비어 있으면 업스트림 레지스트리로 채운다
yq -i '.components."product-catalog".imageOverride.repository |= (. // "ghcr.io/open-telemetry/demo")' "$VALUES"
push_pr $B "chore(dev): bump product-catalog image" "버전 올림 (시나리오: 3-2 잘못된 values)"
