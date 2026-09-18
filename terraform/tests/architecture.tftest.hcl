mock_provider "aws" {
  mock_resource "aws_lb" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/marketly/1234567890abcdef" }
  }
  mock_resource "aws_lb_target_group" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/marketly/1234567890abcdef" }
  }
  mock_resource "aws_launch_template" {
    defaults = { id = "lt-0123456789abcdef0" }
  }
  mock_data "aws_availability_zones" {
    defaults = { names = ["us-east-1a", "us-east-1b"] }
  }
  mock_data "aws_ami" {
    defaults = { id = "ami-0123456789abcdef0" }
  }
  mock_data "aws_vpc" {
    defaults = { id = "vpc-0123456789abcdef0", cidr_block = "10.0.0.0/16" }
  }
  mock_data "aws_internet_gateway" {
    defaults = { id = "igw-0123456789abcdef0" }
  }
  mock_resource "aws_db_instance" {
    defaults = { master_user_secret = [{ secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:marketly-test", secret_status = "active", kms_key_id = "test" }] }
  }
}

run "reuse_existing_vpc" {
  command = plan
  variables {
    existing_vpc_id            = "vpc-0123456789abcdef0"
    subnet_offset              = 10
    github_oidc_subject_prefix = "repo:example@123/marketly@456"
  }
  assert {
    condition     = module.vpc.vpc_id == "vpc-0123456789abcdef0" && module.vpc.vpc_cidr == "10.0.0.0/16"
    error_message = "Existing VPC deployments must retain the supplied VPC and its CIDR."
  }
  assert {
    condition     = module.iam_oidc.trust_subjects.ci == "repo:example@123/marketly@456:ref:refs/heads/main" && module.iam_oidc.trust_subjects.terraform == "repo:example@123/marketly@456:environment:terraform-apply"
    error_message = "Immutable repository IDs must be preserved in both branch and environment trust subjects."
  }
}
mock_provider "random" {}
variables {
  github_repository          = "example/marketly"
  state_bucket               = "marketly-test-state"
  state_lock_table           = "marketly-terraform-locks"
  existing_vpc_id            = null
  subnet_offset              = 0
  oidc_provider_arn          = null
  github_oidc_subject_prefix = ""
}
run "architecture" {
  command = apply
  assert {
    condition     = module.iam_oidc.trust_subjects.ci == "repo:example/marketly:ref:refs/heads/main"
    error_message = "Legacy repositories must retain their branch-scoped subject format."
  }
  assert {
    condition     = length(module.ecr.repository_urls) == 4
    error_message = "Every component needs an ECR repository."
  }
  assert {
    condition     = length(module.vpc.private_subnet_ids) == 2 && length(module.vpc.public_subnet_ids) == 2
    error_message = "Public and private subnets must span two AZs."
  }
  assert {
    condition     = startswith(output.alb_url, "http://") && output.control_plane_id != ""
    error_message = "Deployment must expose the ALB URL and SSM target."
  }
}

run "reject_unpinned_machine_image" {
  command = plan
  variables {
    amazon_linux_ami_name = "al2023-ami-2023.*-x86_64"
  }
  expect_failures = [var.amazon_linux_ami_name]
}
