variable "public_subnet_id" {
  description = "The ID of the public subnet where the NAT instance will reside"
  type        = string
}

variable "nat_sg_id" {
  description = "The ID of the NAT security group"
  type        = string
}

variable "private_route_table_id" {
  description = "The ID of the private route table"
  type        = string
}
