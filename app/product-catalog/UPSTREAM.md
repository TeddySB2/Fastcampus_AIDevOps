# product-catalog (vendored)

- 출처: https://github.com/open-telemetry/opentelemetry-demo/tree/3.1.0/src/product-catalog
- 버전: 3.1.0 (gitops 의 opentelemetry-demo 차트 0.42.1 의 appVersion 과 동일)
- 라이선스: Apache-2.0 (원본 파일의 헤더 유지)

이 저장소에서 직접 빌드·배포하는 유일한 서비스다. 나머지 서비스는 차트 기본 이미지를 쓴다.

변경 사항
- `Dockerfile`: 빌드 컨텍스트를 이 디렉터리로 바꾸면서 COPY 경로만 수정
- 보안 수정 (CI Trivy HIGH: CVE-2026-78667, CVE-2026-78669, CVE-2026-97031)
  - `Dockerfile`: 빌더 `golang:1.27.1` → `1.27.2`, `grpc-health-probe` `v0.4.57` → `v0.4.59` (digest 고정)
  - `go.mod`: `golang.org/x/net` v0.58.0 → v0.60.0 (이에 따라 `go` 1.25.0 → 1.26.0, x/sys · x/text · x/mod 동반 상향)

로컬 확인
```bash
cd app/product-catalog
go test ./...
docker build -t product-catalog:local .
```
