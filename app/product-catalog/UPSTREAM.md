# product-catalog (vendored)

- 출처: https://github.com/open-telemetry/opentelemetry-demo/tree/3.1.0/src/product-catalog
- 버전: 3.1.0 (gitops 의 opentelemetry-demo 차트 0.42.1 의 appVersion 과 동일)
- 라이선스: Apache-2.0 (원본 파일의 헤더 유지)

이 강의에서 직접 빌드·배포하는 유일한 서비스다. 나머지 서비스는 차트 기본 이미지를 쓴다.

변경 사항
- `Dockerfile`: 빌드 컨텍스트를 이 디렉터리로 바꾸면서 COPY 경로만 수정

로컬 확인
```bash
cd app/product-catalog
go test ./...
docker build -t product-catalog:local .
```
