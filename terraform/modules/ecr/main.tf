resource "aws_ecr_repository" "repos" {
  for_each     = toset(["devops-auth", "devops-catalog", "devops-orders", "devops-frontend"])
  name         = each.key
  force_delete = true
}
