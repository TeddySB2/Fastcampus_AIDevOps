# 실습 도구 설치 (2-1 부터)

2-1 은 클러스터 없이 로컬에서 product-catalog 를 빌드 · 테스트 · 스캔한다. 컨테이너 도구는 Docker 대신 **Podman** 을 쓴다.

## macOS (Homebrew)

```bash
brew install go trivy podman
podman machine init      # 처음 한 번: Podman 이 쓸 Linux VM 을 만든다
podman machine start     # 재부팅 후에는 start 만 다시
```

## Linux (Ubuntu 예)

```bash
sudo apt-get install -y golang-go podman
# trivy: https://trivy.dev/latest/getting-started/installation/ 의 apt 저장소 안내를 따른다
```

## Windows

WSL2(Ubuntu) 를 설치하고 위 Linux 절차를 따른다.

## 확인

```bash
go version                                     # go1.25 이상
trivy --version
podman version --format '{{.Server.Version}}'  # 값이 나오면 VM 이 실행 중
```

## Podman 으로 바뀌는 명령

| Docker | Podman (이 강의) |
| --- | --- |
| `docker build -t product-catalog:local .` | `podman build -t product-catalog:local .` |
| `docker images` / `docker inspect` | `podman images` / `podman inspect` |
| `trivy image product-catalog:local` | `podman save -o /tmp/pc.tar product-catalog:local` → `trivy image --input /tmp/pc.tar` |
| `docker login` / `docker push` (2-3, ECR) | `podman login` / `podman push` |

Trivy 는 기본으로 Docker 데몬에서 이미지를 찾는다. Podman 이미지는 tar 로 저장해 `--input` 으로 넘기면 OS 와 상관없이 같은 방법으로 스캔된다.
