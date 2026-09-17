variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "project" {
  type    = string
  default = "marketly"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.project))
    error_message = "Use 3–20 lowercase letters, digits or hyphens."
  }
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "github_repository" {
  type        = string
  description = "GitHub owner/repository, case sensitive."
  default     = "Hamzeh-Alafaghni/Devops-Capstone-"
}
variable "state_bucket" { type = string }
variable "github_oidc_subject_prefix" {
  type        = string
  default     = ""
  description = "sub_claim_prefix from GitHub's OIDC customization API for immutable subjects; empty uses legacy repo:owner/name."
}
variable "existing_vpc_id" {
  type        = string
  default     = null
  description = "Optional existing VPC; it and its gateway remain outside this state and survive teardown."
}
variable "subnet_offset" {
  type        = number
  default     = 0
  description = "First /24 subnet index in the /16 VPC; reserve four consecutive unused ranges."
}
variable "state_lock_table" { type = string }
variable "k3s_version" {
  type    = string
  default = "v1.32.13+k3s1"
}
variable "oidc_provider_arn" {
  type        = string
  default     = null
  description = "Existing GitHub OIDC provider ARN, if already present in this account."
}
