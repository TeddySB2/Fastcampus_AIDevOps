terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.67"
    }
    # eks 모듈이 쓰는 provider. 버전을 고정해 lock 파일 변화를 PR 에서 보이게 한다
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.4"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14"
    }
  }
}
