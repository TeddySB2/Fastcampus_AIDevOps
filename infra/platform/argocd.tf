# Argo CD 는 "합의한 기반 애드온" 이므로 Terraform 이 설치한다.
# 그 위의 애플리케이션(OTel Demo)은 GitOps 저장소가 관리한다.
#
# 설치는 두 단계다.
#   1) argo-cd 차트: Argo CD 본체와 CRD(Application 등)
#   2) argocd-apps 차트: root Application (app-of-apps)
# root 를 argo-cd 차트의 extraObjects 로 같이 넣으면, 설치 시점에 Application CRD 가
# 아직 없어서 "no matches for kind Application" 으로 실패한다. 그래서 CRD 가 생긴 뒤에 만든다.

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  values = [file("${path.module}/values/argocd.yaml")]
}

# root Application: gitops/apps 를 읽어 그 안의 Application 들을 만든다.
# 이후 모든 변경은 Git 으로만 들어간다.
resource "helm_release" "argocd_root" {
  name      = "argocd-root"
  namespace = "argocd"

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version

  values = [
    yamlencode({
      applications = {
        root = {
          namespace  = "argocd"
          finalizers = ["resources-finalizer.argocd.argoproj.io"]
          project    = "default"
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
    })
  ]

  depends_on = [helm_release.argocd]
}
