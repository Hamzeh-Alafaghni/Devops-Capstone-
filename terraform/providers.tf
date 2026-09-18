provider "aws" {
  region = var.aws_region
  default_tags { tags = { Project = var.project, ManagedBy = "Terraform" } }
}
data "aws_caller_identity" "current" {}
data "aws_ami" "amazon_linux" {
  owners = ["amazon"]
  filter {
    name   = "name"
    values = [var.amazon_linux_ami_name]
  }
}
