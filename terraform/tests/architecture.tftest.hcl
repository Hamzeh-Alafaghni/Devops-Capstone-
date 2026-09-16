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
  mock_resource "aws_db_instance" {
    defaults = { master_user_secret = [{ secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:marketly-test", secret_status = "active", kms_key_id = "test" }] }
  }
}
mock_provider "random" {}
variables {
  github_repository = "example/marketly"
  state_bucket      = "marketly-test-state"
  state_lock_table  = "marketly-terraform-locks"
}
run "architecture" {
  command = apply
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
