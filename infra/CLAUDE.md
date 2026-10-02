# infra/ 규칙 (Terraform)

- 루트는 두 개다: `cluster`(VPC·EKS·ECR·IAM) → `platform`(Argo CD). 순서대로 적용한다.
- provider·모듈 버전은 고정한다. 버전을 올리는 변경은 단독 PR 로 만든다.
- 새 리소스에는 공통 태그(default_tags)가 붙는지 확인한다.
- 정책 예외는 `infra/.checkov.yaml` 에 근거와 함께만 추가한다. 근거 없는 skip 은 금지.
- 0.0.0.0/0 인바운드, `*` IAM Action/Resource(ECR 로그인 제외)는 만들지 않는다.

## plan 을 요약할 때 형식

1. 생성 / 변경 / 교체(-/+) / 삭제 개수
2. 교체·삭제되는 리소스와 그 이유 (데이터 손실, 다운타임 가능성)
3. 권한이 넓어지는 변경 (IAM, 보안 그룹, 접근 엔트리)
4. 비용에 영향을 주는 변경 (노드 타입·수, NAT, LB, 로그 보존)
5. 사람이 결정해야 할 질문
