# 직접 빌드하는 서비스 1개(product-catalog)의 이미지 저장소.
# 태그는 불변(IMMUTABLE)으로 두고, 배포는 digest 로 고정한다.
resource "aws_ecr_repository" "product_catalog" {
  name                 = "${var.name}/product-catalog"
  image_tag_mutability = "IMMUTABLE"

  # 실습 종료 시 destroy 가 이미지 때문에 막히지 않도록 한다 (운영에서는 false)
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "product_catalog" {
  repository = aws_ecr_repository.product_catalog.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "태그 없는 이미지는 7일 뒤 삭제"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "최근 20개 이미지만 보관"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = { type = "expire" }
      }
    ]
  })
}
