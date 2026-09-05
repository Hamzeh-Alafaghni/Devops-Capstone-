resource "aws_ecr_repository" "frontend" {
  name         = "devops-frontend"
  force_delete = true
}

resource "aws_ecr_repository" "catalog" {
  name         = "devops-catalog"
  force_delete = true
}

resource "aws_ecr_repository" "orders" {
  name         = "devops-orders"
  force_delete = true
}

resource "aws_ecr_repository" "auth" {
  name         = "devops-auth"
  force_delete = true
}
