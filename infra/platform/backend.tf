terraform {
  backend "s3" {
    key          = "ai-devops-lab/platform/terraform.tfstate"
    use_lockfile = true
    encrypt      = true
  }
}
