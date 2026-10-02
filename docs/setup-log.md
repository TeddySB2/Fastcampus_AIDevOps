# 환경 구축 기록

촬영 전 완주(1회차·2회차) 때 실제로 실행한 명령과 결과, 걸린 시간을 남긴다.
이 기록이 수강생용 사전 준비 가이드의 원본이 된다.

| 날짜 | 회차 | 단계 | 명령 | 결과 | 소요 | 메모 |
| --- | --- | --- | --- | --- | --- | --- |
|  | 1 | cluster apply | `terraform -chdir=infra/cluster apply -var-file=dev.tfvars` |  |  |  |
|  | 1 | platform apply | `terraform -chdir=infra/platform apply -var-file=platform.tfvars` |  |  |  |
|  | 1 | Demo Healthy | Argo CD `otel-demo-dev` |  |  |  |
|  | 1 | smoke | `./tests/smoke.sh` |  |  |  |
|  | 1 | CI → 배포 PR | `.github/workflows/ci.yml` |  |  |  |
|  | 1 | destroy | `docs/teardown.md` 순서 |  |  |  |

## 실측값

- 노드 타입·수:
- Demo 전체가 Healthy 가 될 때까지:
- 시간당 비용(추정):
