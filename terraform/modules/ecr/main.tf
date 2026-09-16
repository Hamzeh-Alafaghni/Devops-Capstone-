resource "aws_ecr_repository" "repos" {
  for_each             = toset(["auth-service", "catalog-service", "orders-service", "frontend"])
  name                 = "${var.project}/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  force_delete = true
}
resource "aws_ecr_lifecycle_policy" "images" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name
  policy     = jsonencode({ rules = [{ rulePriority = 1, description = "Expire untagged images", selection = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 7 }, action = { type = "expire" } }] })
}
