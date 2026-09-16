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
  default     = "Hamzeh-Alafaghni/Devops-Capstone"
}
variable "state_bucket" { type = string }
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
