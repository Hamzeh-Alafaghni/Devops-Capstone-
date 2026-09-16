variable "project" { type = string }
variable "region" { type = string }
variable "k3s_version" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "k3s_sg_id" { type = string }
variable "ecr_arns" { type = list(string) }
variable "database_secret_arn" { type = string }
variable "worker_instance_type" {
  type    = string
  default = "t3.micro"
}
