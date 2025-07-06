resource "aws_ecr_repository" "flask_repo" {
  name = var.app_name

  image_scanning_configuration {
    scan_on_push = true
  }

  image_tag_mutability = "MUTABLE"
}
