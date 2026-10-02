#!/usr/bin/env bash
# PostToolUse(Edit|Write): Claude 가 파일을 고칠 때마다 결정론적 검사를 돌린다.
# 실패하면 exit 2 로 결과를 Claude 에게 돌려줘 스스로 고치게 한다.
set -uo pipefail
input=$(cat)
file=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)
[[ -z "$file" || ! -f "$file" ]] && exit 0

errors=""
case "$file" in
  *.tf)
    dir=$(dirname "$file")
    if command -v terraform >/dev/null; then
      terraform fmt "$file" >/dev/null 2>&1
      if [[ -d "$dir/.terraform" ]]; then
        out=$(terraform -chdir="$dir" validate -no-color 2>&1) || errors+="terraform validate 실패 ($dir):\n$out\n"
      fi
    fi
    ;;
  *.yaml|*.yml)
    # YAML 파서: PyYAML → ruby(Psych) → yq 순서로 있는 것을 쓴다 (도구가 하나도 없으면 건너뜀)
    if python3 -c 'import yaml' 2>/dev/null; then
      out=$(python3 -c '
import sys,yaml
try: list(yaml.safe_load_all(open(sys.argv[1])))
except Exception as e: print(e); sys.exit(1)' "$file" 2>&1) || errors+="YAML 파싱 실패 ($file):\n$out\n"
    elif command -v ruby >/dev/null; then
      out=$(ruby -e 'require "yaml"; begin; YAML.load_stream(File.read(ARGV[0])); rescue => e; puts e.message; exit 1; end' "$file" 2>&1) || errors+="YAML 파싱 실패 ($file):\n$out\n"
    elif command -v yq >/dev/null; then
      out=$(yq eval '.' "$file" 2>&1 >/dev/null) || errors+="YAML 파싱 실패 ($file):\n$out\n"
    else
      echo "참고: YAML 검사 도구(PyYAML · ruby · yq)가 없어 검사를 건너뜁니다." >&2
    fi
    if [[ -z "$errors" && "$file" == *gitops/manifests/* ]] && command -v kubeconform >/dev/null; then
      out=$(kubeconform -summary -ignore-missing-schemas "$file" 2>&1) || errors+="kubeconform 실패 ($file):\n$out\n"
    fi
    ;;
esac

if [[ -n "$errors" ]]; then
  printf "%b" "$errors" >&2
  exit 2
fi
exit 0
