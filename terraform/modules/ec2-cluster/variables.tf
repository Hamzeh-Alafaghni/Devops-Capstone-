variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "k3s_sg_id" {
  description = "Security group ID for the K3s cluster"
  type        = string
}
