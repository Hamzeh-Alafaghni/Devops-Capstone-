variable "project" { type = string }
variable "region" { type = string }
variable "github_repository" { type = string }
variable "repository_arns" { type = list(string) }
variable "state_bucket" { type = string }
variable "state_lock_table" { type = string }
variable "oidc_provider_arn" { type = string }
