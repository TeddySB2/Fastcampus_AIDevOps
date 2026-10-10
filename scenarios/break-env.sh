#!/usr/bin/env bash
# 장애 훈련: product-catalog 의 DB 연결 문자열을 비우는 "설정 누락" PR → CrashLoopBackOff
source "$(dirname "$0")/_pr.sh"
B=scenario/missing-db-env
open_pr $B
yq -i '.components."product-catalog".envOverrides = [{"name":"DB_CONNECTION_STRING","value":""}]' "$VALUES"
push_pr $B "refactor(dev): move product-catalog DB settings" "설정 정리 (장애 훈련: env 누락)"
