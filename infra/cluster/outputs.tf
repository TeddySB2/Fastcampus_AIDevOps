output "cluster_name" {
  value = module.eks.cluster_name
}

output "region" {
  value = var.region
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_repository_url" {
  description = "gitops/values/otel-demo/*.yaml 의 product-catalog imageOverride.repository 값"
  value       = aws_ecr_repository.product_catalog.repository_url
}

output "github_ci_role_arn" {
  description = "GitHub 저장소 변수 AWS_CI_ROLE_ARN 에 넣는다"
  value       = aws_iam_role.github_ci.arn
}

output "vpc_id" {
  value = local.vpc_id
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name} --alias ${module.eks.cluster_name}"
}
