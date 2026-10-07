module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.26.0"

  name               = local.cluster_name
  kubernetes_version = var.kubernetes_version

  # API 엔드포인트: 퍼블릭으로 열되 허용 CIDR 을 제한한다
  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  # terraform apply 를 실행한 사람(관리자)에게 클러스터 관리자 권한을 준다
  enable_cluster_creator_admin_permissions = true

  # 컨트롤 플레인 로그: 학습 환경이고 7일 안에 destroy 하므로 보존은 7일
  enabled_log_types                      = ["api", "audit", "authenticator"]
  cloudwatch_log_group_retention_in_days = 7

  # secrets 암호화 KMS 키: destroy 후 삭제 대기 기간을 최소(7일)로 (스펙 5장 "state 버킷만 남는다")
  kms_key_deletion_window_in_days = 7

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  # 기반 애드온은 Terraform 이 관리한다. 버전은 1.36 용으로 조회해 고정한다
  # (aws eks describe-addon-versions --kubernetes-version 1.36, 2026-10-07). 업그레이드는 단독 PR 로
  addons = {
    vpc-cni = {
      before_compute = true
      addon_version  = "v1.23.2-eksbuild.1"
    }
    eks-pod-identity-agent = {
      before_compute = true
      addon_version  = "v1.4.0-eksbuild.3"
    }
    coredns = {
      addon_version = "v1.14.7-eksbuild.10"
    }
    kube-proxy = {
      addon_version = "v1.36.0-eksbuild.25"
    }
    metrics-server = {
      addon_version = "v0.9.0-eksbuild.11" # HPA 가 CPU 사용률을 읽는 데 필요
    }
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      desired_size = var.node_desired_size
      max_size     = var.node_max_size

      # 이미지가 많은 Demo 를 위해 루트 볼륨 50GiB (gp3, 암호화)
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      # provider default_tags 는 노드 EC2 · EBS · ENI 에 전파되지 않으므로 launch template 으로 붙인다
      launch_template_tags = local.tags
      tag_specifications   = ["instance", "volume", "network-interface"]
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
