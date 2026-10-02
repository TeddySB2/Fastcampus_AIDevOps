module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.26"

  name               = local.cluster_name
  kubernetes_version = var.kubernetes_version

  # API 엔드포인트: 퍼블릭으로 열되 허용 CIDR 을 제한한다
  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  # terraform apply 를 실행한 사람(관리자)에게 클러스터 관리자 권한을 준다
  enable_cluster_creator_admin_permissions = true

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  addons = {
    vpc-cni = {
      before_compute = true
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    coredns        = {}
    kube-proxy     = {}
    metrics-server = {} # HPA 가 CPU 사용률을 읽는 데 필요
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types

      min_size     = var.node_min_size
      desired_size = var.node_desired_size
      max_size     = var.node_max_size
    }
  }

  # 읽기 전용 접근: Claude Code / MCP 용 프로파일.
  # AmazonEKSViewPolicy 는 Secret 조회를 포함하지 않는다.
  access_entries = {
    for idx, arn in var.readonly_principal_arns : "readonly-${idx}" => {
      principal_arn = arn

      policy_associations = {
        view = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}
