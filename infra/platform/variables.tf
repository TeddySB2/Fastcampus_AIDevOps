variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "cluster_name" {
  description = "infra/cluster 출력값 cluster_name"
  type        = string
  default     = "ai-devops-lab-dev"
}

variable "argocd_chart_version" {
  description = "argo-helm 의 argo-cd 차트 버전. 업그레이드는 단독 PR 로"
  type        = string
  default     = "10.9.6"
}

variable "argocd_apps_chart_version" {
  description = "argo-helm 의 argocd-apps 차트 버전 (root Application 용). helm search repo argo/argocd-apps 로 확인해 고정"
  type        = string
  default     = "2.0.2"
}

variable "gitops_repo_url" {
  description = "Argo CD 가 바라보는 GitOps 저장소 (이 저장소)"
  type        = string
}

variable "gitops_revision" {
  description = "Argo CD 가 추적할 브랜치"
  type        = string
  default     = "main"
}
