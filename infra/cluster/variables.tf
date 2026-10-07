variable "name" {
  description = "모든 리소스 이름의 접두사"
  type        = string
  default     = "ai-devops-lab"
}

variable "environment" {
  description = "환경 이름 (태그와 이름에 사용)"
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "스펙의 환경은 dev 다."
  }
}

variable "region" {
  description = "AWS 리전. 작업 스펙(specs/eks-demo.md)의 값과 같아야 한다"
  type        = string
  default     = "ap-northeast-2"

  validation {
    condition     = var.region == "ap-northeast-2"
    error_message = "스펙의 리전은 ap-northeast-2 다. 다른 리전은 스펙 변경 PR 이 먼저다."
  }
}

variable "expires" {
  description = "모든 리소스에 붙일 expires 태그 (YYYY-MM-DD). 스펙 4장: 생성 후 최대 7일. 커밋하지 않는 dev.tfvars 로 넣는다"
  type        = string

  validation {
    condition     = can(regex("^\\d{4}-\\d{2}-\\d{2}$", var.expires))
    error_message = "expires 는 YYYY-MM-DD 형식이다."
  }
}

variable "kubernetes_version" {
  description = "EKS Kubernetes 버전. 업그레이드는 단독 PR 로 한다"
  type        = string
  default     = "1.36"
}

# ---------------------------------------------------------------------------
# 네트워크: 기존 VPC 를 쓰거나, 여기서 새로 만든다
# ---------------------------------------------------------------------------
variable "create_vpc" {
  description = "true 면 이 루트에서 VPC 를 만든다. 기존 VPC 를 재사용하면 false"
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
  description = "퍼블릭 API 엔드포인트에 접근 가능한 CIDR. 본인 공인 IP/32 처럼 좁게"
  type        = list(string)

  # checkov 는 변수 값과 레지스트리 모듈 내부를 보지 못해 넓은 대역을 잡지 못한다 → 변수 검증으로 막는다
  # 스펙 4장: 작업자 IP/32 로만 제한
  validation {
    condition     = length(var.endpoint_public_access_cidrs) > 0 && alltrue([for c in var.endpoint_public_access_cidrs : endswith(c, "/32") && can(cidrhost(c, 0))])
    error_message = "endpoint_public_access_cidrs 에는 작업자 IP/32 만 넣는다. 0.0.0.0/0 이나 넓은 대역은 허용하지 않는다."
  }
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
  description = "매니지드 노드그룹 인스턴스 타입. 실측 사용량으로 조정한다"
  type        = list(string)
  default     = ["m6i.xlarge"]
}

variable "node_min_size" {
  description = "스펙 4장: 최소 2대"
  type        = number
  default     = 2

  validation {
    condition     = var.node_min_size >= 2
    error_message = "스펙의 최소 노드 수는 2대다."
  }
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  description = "비용 상한. 작업 스펙의 최대 노드 수와 같아야 한다"
  type        = number
  default     = 4

  validation {
    condition     = var.node_max_size <= 4
    error_message = "스펙의 최대 노드 수는 4대다. 늘리려면 스펙 변경 PR 이 먼저다."
  }
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
