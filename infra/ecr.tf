resource "aws_ecr_repository" "api_service" {
  name                 = "${var.project_name}/api-service"
  image_tag_mutability = "IMMUTABLE" # prevents accidental tag overwrite of a deployed image

  image_scanning_configuration {
    scan_on_push = true # native ECR scan-on-push, in addition to Trivy in CI
  }
}

resource "aws_ecr_repository" "worker_service" {
  name                 = "${var.project_name}/worker-service"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Free tier gives 500MB/month ECR storage. This lifecycle policy keeps
# only the 5 most recent images per repo so you don't quietly exceed it.
resource "aws_ecr_lifecycle_policy" "api_service" {
  repository = aws_ecr_repository.api_service.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "worker_service" {
  repository = aws_ecr_repository.worker_service.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}
