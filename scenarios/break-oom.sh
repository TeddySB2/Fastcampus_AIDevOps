#!/usr/bin/env bash
# 5-1: product-catalog memory limit 을 과하게 줄이는 PR → OOMKilled 반복
source "$(dirname "$0")/_pr.sh"
B=scenario/tight-memory
open_pr $B
yq -i '.components."product-catalog".resources.limits.memory = "8Mi"' "$VALUES"
push_pr $B "perf(dev): reduce product-catalog memory limit" "비용 절감 (시나리오: 5-1 OOM)"
