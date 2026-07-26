# ==================== ECR — Microsserviços Fase 4 ====================
# Repos de imagem para ms-os, ms-billing e ms-execution.
# Mantém aws_ecr_repository.api (legado Fase 3) em ecr.tf.

locals {
  microservice_ecr = toset(["os", "billing", "execution"])
}

resource "aws_ecr_repository" "microservice" {
  for_each = local.microservice_ecr

  name                 = "${var.project_name}-${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${each.key}"
    Service = each.key
    Phase   = "4"
  })
}

resource "aws_ecr_lifecycle_policy" "microservice" {
  for_each = local.microservice_ecr

  repository = aws_ecr_repository.microservice[each.key].name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Manter apenas as 10 últimas imagens"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
