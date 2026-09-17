data "aws_caller_identity" "current" {}
resource "aws_iam_openid_connect_provider" "github" {
  count          = var.oidc_provider_arn == null ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}
locals {
  provider_arn   = var.oidc_provider_arn != null ? var.oidc_provider_arn : aws_iam_openid_connect_provider.github[0].arn
  subject_prefix = var.github_oidc_subject_prefix != "" ? var.github_oidc_subject_prefix : "repo:${var.github_repository}"
  subjects = {
    ci        = "${local.subject_prefix}:ref:refs/heads/main"
    terraform = "${local.subject_prefix}:environment:terraform-apply"
    plan      = "${local.subject_prefix}:environment:terraform-plan"
  }
}
resource "aws_iam_role" "github" {
  for_each = local.subjects
  name     = "${var.project}-github-${each.key}"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Allow", Action = "sts:AssumeRoleWithWebIdentity", Principal = { Federated = local.provider_arn },
    Condition = { StringEquals = {
      "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com",
      "token.actions.githubusercontent.com:sub" = each.value
    } }
  }] })
}
resource "aws_iam_role_policy" "ci" {
  role = aws_iam_role.github["ci"].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
    { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:DescribeImages"], Resource = var.repository_arns }
  ] })
}
# The read role can refresh Terraform state and lock it, but cannot apply changes.
resource "aws_iam_role_policy" "read" {
  for_each = toset(["plan", "terraform"])
  role     = aws_iam_role.github[each.key].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ec2:Describe*", "autoscaling:Describe*", "elasticloadbalancing:Describe*", "rds:Describe*", "rds:ListTagsForResource", "ecr:Describe*", "ecr:GetLifecyclePolicy", "ecr:ListTagsForResource", "ssm:DescribeParameters"], Resource = "*" },
    { Effect = "Allow", Action = ["iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:GetInstanceProfile", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:GetOpenIDConnectProvider", "iam:ListInstanceProfilesForRole"], Resource = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-*", "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${var.project}-*", local.provider_arn, "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"] },
    { Effect = "Allow", Action = ["ssm:GetParameter", "ssm:ListTagsForResource"], Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/*" },
    { Effect = "Allow", Action = ["s3:ListBucket"], Resource = "arn:aws:s3:::${var.state_bucket}" },
    { Effect = "Allow", Action = ["s3:GetObject"], Resource = "arn:aws:s3:::${var.state_bucket}/${var.project}/*" },
    { Effect = "Allow", Action = ["dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"], Resource = "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.state_lock_table}" }
  ] })
}
# Provisioning needs creation APIs that cannot all be resource-scoped. Limit
# those to the selected region; IAM mutation is restricted to project names.
resource "aws_iam_role_policy" "terraform" {
  role = aws_iam_role.github["terraform"].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = [
      "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute", "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute", "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway", "ec2:DetachInternetGateway", "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable", "ec2:ReplaceRouteTableAssociation", "ec2:CreateRoute", "ec2:DeleteRoute", "ec2:ReplaceRoute", "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupEgress", "ec2:RunInstances", "ec2:TerminateInstances", "ec2:StopInstances", "ec2:StartInstances", "ec2:ModifyInstanceAttribute", "ec2:CreateLaunchTemplate", "ec2:DeleteLaunchTemplate", "ec2:CreateLaunchTemplateVersion", "ec2:DeleteLaunchTemplateVersions", "ec2:ModifyLaunchTemplate", "ec2:CreateTags", "ec2:DeleteTags",
      "autoscaling:CreateAutoScalingGroup", "autoscaling:UpdateAutoScalingGroup", "autoscaling:DeleteAutoScalingGroup", "autoscaling:CreateOrUpdateTags", "autoscaling:DeleteTags", "autoscaling:AttachLoadBalancerTargetGroups", "autoscaling:DetachLoadBalancerTargetGroups", "autoscaling:StartInstanceRefresh", "autoscaling:CancelInstanceRefresh",
      "elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:DeleteLoadBalancer", "elasticloadbalancing:ModifyLoadBalancerAttributes", "elasticloadbalancing:SetSecurityGroups", "elasticloadbalancing:SetSubnets", "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DeleteTargetGroup", "elasticloadbalancing:ModifyTargetGroup", "elasticloadbalancing:ModifyTargetGroupAttributes", "elasticloadbalancing:CreateListener", "elasticloadbalancing:DeleteListener", "elasticloadbalancing:ModifyListener", "elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags",
      "rds:CreateDBInstance", "rds:ModifyDBInstance", "rds:DeleteDBInstance", "rds:CreateDBSubnetGroup", "rds:ModifyDBSubnetGroup", "rds:DeleteDBSubnetGroup", "rds:CreateDBParameterGroup", "rds:ModifyDBParameterGroup", "rds:DeleteDBParameterGroup", "rds:ResetDBParameterGroup", "rds:AddTagsToResource", "rds:RemoveTagsFromResource", "secretsmanager:CreateSecret", "secretsmanager:TagResource", "secretsmanager:RotateSecret", "secretsmanager:DescribeSecret", "kms:DescribeKey"
    ], Resource = "*", Condition = { StringEquals = { "aws:RequestedRegion" = var.region } } },
    { Effect = "Allow", Action = ["ecr:CreateRepository", "ecr:DeleteRepository", "ecr:PutImageScanningConfiguration", "ecr:PutImageTagMutability", "ecr:PutLifecyclePolicy", "ecr:DeleteLifecyclePolicy", "ecr:TagResource", "ecr:UntagResource"], Resource = "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/${var.project}/*" },
    { Effect = "Allow", Action = ["ssm:PutParameter", "ssm:DeleteParameter", "ssm:AddTagsToResource", "ssm:RemoveTagsFromResource"], Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/*" },
    { Effect = "Allow", Action = ["iam:CreateRole", "iam:DeleteRole", "iam:UpdateAssumeRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:TagRole", "iam:UntagRole", "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile", "iam:TagInstanceProfile", "iam:UntagInstanceProfile"], Resource = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-*", "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${var.project}-*"] },
    { Effect = "Allow", Action = ["iam:PassRole"], Resource = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-node", "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-control-plane"], Condition = { StringEquals = { "iam:PassedToService" = "ec2.amazonaws.com" } } },
    { Effect = "Allow", Action = ["iam:CreateServiceLinkedRole"], Resource = "arn:aws:iam::*:role/aws-service-role/*", Condition = { StringEquals = { "iam:AWSServiceName" = ["autoscaling.amazonaws.com", "elasticloadbalancing.amazonaws.com", "rds.amazonaws.com"] } } },
    { Effect = "Allow", Action = ["s3:PutObject"], Resource = "arn:aws:s3:::${var.state_bucket}/${var.project}/*" }
  ] })
}
