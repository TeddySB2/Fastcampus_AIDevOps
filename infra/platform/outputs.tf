output "argocd_port_forward" {
  value = "kubectl -n argocd port-forward svc/argocd-server 8080:80"
}

output "argocd_initial_password" {
  value = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "argocd_mcp_token" {
  description = "Argo CD MCP 용 읽기 전용 토큰 발급 명령 (argocd CLI 로그인 후)"
  value       = "argocd account generate-token --account mcp-readonly"
}
