output "repository_urls" { value = { for k, repo in aws_ecr_repository.repos : k => repo.repository_url } }
output "repository_arns" { value = [for repo in aws_ecr_repository.repos : repo.arn] }
