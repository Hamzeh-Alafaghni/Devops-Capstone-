output "ci_role_arn" { value = aws_iam_role.github["ci"].arn }
output "terraform_role_arn" { value = aws_iam_role.github["terraform"].arn }
output "plan_role_arn" { value = aws_iam_role.github["plan"].arn }
output "trust_subjects" { value = local.subjects }
