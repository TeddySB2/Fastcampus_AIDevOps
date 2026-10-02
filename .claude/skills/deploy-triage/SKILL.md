---
name: deploy-triage
description: 배포 직후 Pod 가 CrashLoopBackOff·ImagePullBackOff·OOMKilled·NotReady 이거나 Argo CD 앱이 Degraded 일 때, 읽기 전용으로 증거를 모아 원인 가설과 복구안을 제시한다. 클러스터를 바꾸지 않는다.
---

# 배포 장애 Triage (읽기 전용)

목표는 원인을 "맞히는 것"이 아니라 **근거로 가설을 좁히고, 사람이 승인할 복구안을 준비하는 것**이다.

## 0. 범위 확인

- `kubectl config current-context` 와 대상 네임스페이스를 먼저 출력한다. CLAUDE.md 의 환경 사실과 다르면 멈춘다.
- 대상 앱(예: otel-demo-dev)과 의심 워크로드를 사용자에게서 받는다. 없으면 Degraded 리소스부터 찾는다.

## 1. 증거 수집 (이 순서로, 모두 읽기 전용)

1. 변경 이력: `argocd app history <app>`, `git log --oneline -10 -- gitops/` — 장애 직전에 무엇이 바뀌었나
2. 현재 상태: `argocd app get <app>`, `kubectl -n <ns> get deploy,rs,pods -o wide`
3. Pod 상세: `kubectl -n <ns> describe pod <pod>` — State, Last State, Reason, Exit Code, Events
4. 이벤트: `kubectl -n <ns> events --for pod/<pod>` 또는 `get events --sort-by=.lastTimestamp`
5. 로그: `kubectl -n <ns> logs <pod> -c <container> --previous --tail=100` (재시작된 경우 이전 컨테이너)
6. 롤아웃: `kubectl -n <ns> rollout history deploy/<name>`
7. 렌더링 차이: 의심 커밋의 values 변경을 `git show <sha> -- gitops/values/` 로 확인

Secret 내용은 조회하지 않는다. 출력이 길면 관련 줄만 인용한다.

## 2. 결과 형식

### 증상
한 문장 + 영향 범위(어떤 사용자 기능이 실패하는가)

### 타임라인
| 시각 | 사건 | 근거 |

### 가설
| 가설 | 근거(명령·출력 인용) | 반증/아직 확인 못 한 것 | 확신 |

- 최소 2개 가설을 세우고, 증거로 하나씩 제거한다.
- "Pod 재시작으로 해결" 은 원인이 아니다.

### 복구안 (실행하지 않는다)
| 안 | 방법 | 위험 | 되돌리는 법 | 검증 |

- 기본 복구 경로는 **원인 커밋의 `git revert` PR** 이다.
- 클러스터 직접 조작(`rollout undo` 등)이 필요하면 명령과 이유만 적고 사람에게 맡긴다.

### 정상화 판정 기준
- Argo CD 앱 Healthy/Synced
- `tests/smoke.sh` 통과
- 재시작 횟수가 더 늘지 않음 (5분 관찰)
