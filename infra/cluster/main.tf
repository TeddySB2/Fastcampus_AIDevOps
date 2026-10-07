locals {
  cluster_name = "${var.name}-${var.environment}"

  tags = {
    Project     = var.name
    Environment = var.environment
    ManagedBy   = "terraform"
    Course      = "ai-devops-part3"
    expires     = var.expires # 스펙 4장: 모든 리소스에 expires 태그 (생성 후 최대 7일)
  }

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  vpc_id             = var.create_vpc ? module.vpc[0].vpc_id : var.existing_vpc_id
  private_subnet_ids = var.create_vpc ? module.vpc[0].private_subnets : var.existing_private_subnet_ids
}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# VPC (기존 VPC 를 재사용하면 create_vpc = false)
# 학습 환경 비용을 위해 NAT 게이트웨이는 1개만 둔다. 이 선택은 AZ 장애 시
# 아웃바운드가 끊길 수 있다는 trade-off 가 있으며, 작업 스펙에 명시한다.
# ---------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7.3"
  count   = var.create_vpc ? 1 : 0

  name = local.cluster_name
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, 48 + i)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}
