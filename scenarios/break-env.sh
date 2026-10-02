#!/usr/bin/env bash
# 5-1: product-catalog 의 DB 연결 문자열을 비우는 "설정 누락" PR → CrashLoopBackOff
source "$(dirname "$0")/_pr.sh"
B=scenario/missing-db-env
open_pr $B
yq -i '.components."product-catalog".envOverrides = [{"name":"DB_CONNECTION_STRING","value":""}]' "$VALUES"
push_pr $B "refactor(dev): move product-catalog DB settings" "설정 정리 (시나리오: 5-1 env 누락)"
