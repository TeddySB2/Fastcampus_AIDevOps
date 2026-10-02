# Argo CD 는 "합의한 기반 애드온" 이므로 Terraform 이 설치한다.
# 그 위의 애플리케이션(OTel Demo)은 GitOps 저장소가 관리한다.
# root Application(app-of-apps)도 함께 만들어, 이후 모든 변경은 Git 으로만 들어간다.
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  values = [
    file("${path.module}/values/argocd.yaml"),
    yamlencode({
      extraObjects = [
        {
          apiVersion = "argoproj.io/v1alpha1"
          kind       = "Application"
          metadata = {
            name       = "root"
            namespace  = "argocd"
            finalizers = ["resources-finalizer.argocd.argoproj.io"]
          }
          spec = {
            project = "default"
            source = {
              repoURL        = var.gitops_repo_url
              targetRevision = var.gitops_revision
              path           = "gitops/apps"
            }
            destination = {
              server    = "https://kubernetes.default.svc"
              namespace = "argocd"
            }
            syncPolicy = {
              automated = {
                prune    = true
                selfHeal = true
              }
            }
          }
        }
      ]
    })
  ]
}
