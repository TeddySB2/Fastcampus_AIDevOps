# GitHub Actions 가 장기 액세스 키 없이 ECR 에 push 하기 위한 OIDC 신뢰 관계.
# 배포 브랜치(var.github_deploy_branch, Argo CD 가 읽는 브랜치)의 워크플로만 이 역할을 맡을 수 있다 (PR 에서는 빌드·스캔만).

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  github_owner             = split("/", var.github_repository)[0]
  github_repo              = split("/", var.github_repository)[1]
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

data "aws_iam_policy_document" "github_ci_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # GitHub 는 2026-07-15 이후 만들거나 이름을 바꾼 저장소(fork 포함)의 sub 에 owner·repo ID 를 붙인다.
    #   예전 형식: repo:OWNER/REPO:ref:refs/heads/BRANCH
    #   새 형식:   repo:OWNER@OWNER_ID/REPO@REPO_ID:ref:refs/heads/BRANCH
    # 두 형식을 모두 받는다. ID 까지 고정하려면 gh api repos/OWNER/REPO/actions/oidc/customization/sub 의
    # sub_claim_prefix 값을 그대로 적는다.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repository}:ref:refs/heads/${var.github_deploy_branch}",
        "repo:${local.github_owner}@*/${local.github_repo}@*:ref:refs/heads/${var.github_deploy_branch}",
      ]
    }
  }
}

resource "aws_iam_role" "github_ci" {
  name               = "${local.cluster_name}-github-ci"
  assume_role_policy = data.aws_iam_policy_document.github_ci_assume.json
}

data "aws_iam_policy_document" "github_ci_ecr" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPushProductCatalog"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.product_catalog.arn]
  }
}

resource "aws_iam_role_policy" "github_ci_ecr" {
  name   = "ecr-push-product-catalog"
  role   = aws_iam_role.github_ci.id
  policy = data.aws_iam_policy_document.github_ci_ecr.json
}
