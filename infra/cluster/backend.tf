# 상태 파일은 S3에 두고, S3 네이티브 잠금(use_lockfile)을 사용한다.
# bucket / region 은 backend.hcl 로 주입한다 (backend.hcl.example 참고).
terraform {
  backend "s3" {
    key          = "ai-devops-lab/cluster/terraform.tfstate"
    use_lockfile = true
    encrypt      = true
  }
}
