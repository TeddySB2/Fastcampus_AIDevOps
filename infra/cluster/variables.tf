variable "name" {
  description = "모든 리소스 이름의 접두사"
  type        = string
  default     = "ai-devops-lab"
}

variable "environment" {
  description = "환경 이름 (태그와 이름에 사용)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS 리전. 작업 계약서(contracts/eks-demo.md)의 값과 같아야 한다"
  type        = string
  default     = "ap-northeast-2"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes 버전. 촬영 기간 동안 고정한다"
  type        = string
  default     = "1.36"
}

# ---------------------------------------------------------------------------
# 네트워크: Part 2 에서 만든 VPC 를 쓰거나, 여기서 새로 만든다
# ---------------------------------------------------------------------------
variable "create_vpc" {
  description = "true 면 이 루트에서 VPC 를 만든다. Part 2 VPC 를 재사용하면 false"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "create_vpc = true 일 때 사용할 CIDR"
  type        = string
  default     = "10.30.0.0/16"
}

variable "existing_vpc_id" {
  description = "create_vpc = false 일 때 재사용할 VPC ID"
  type        = string
  default     = null
}

variable "existing_private_subnet_ids" {
  description = "create_vpc = false 일 때 노드와 컨트롤 플레인 ENI 를 둘 프라이빗 서브넷"
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# 클러스터 접근
# ---------------------------------------------------------------------------
variable "endpoint_public_access_cidrs" {
  description = "퍼블릭 API 엔드포인트에 접근 가능한 CIDR. 0.0.0.0/0 은 정책 검사에서 실패한다"
  type        = list(string)
}

variable "readonly_principal_arns" {
  description = "읽기 전용(AmazonEKSViewPolicy) 접근을 받을 IAM 역할. Claude Code / MCP 가 쓰는 프로파일"
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# 노드
# ---------------------------------------------------------------------------
variable "node_instance_types" {
  description = "매니지드 노드그룹 인스턴스 타입. 촬영 전 실측으로 확정한다"
  type        = list(string)
  default     = ["m6i.xlarge"]
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  description = "비용 상한. 작업 계약서의 최대 노드 수와 같아야 한다"
  type        = number
  default     = 4
}

# ---------------------------------------------------------------------------
# CI (GitHub Actions OIDC)
# ---------------------------------------------------------------------------
variable "github_repository" {
  description = "OIDC 신뢰 대상 저장소 (owner/repo)"
  type        = string
}

variable "create_github_oidc_provider" {
  description = "계정에 GitHub OIDC provider 가 이미 있으면 false"
  type        = bool
  default     = true
}
