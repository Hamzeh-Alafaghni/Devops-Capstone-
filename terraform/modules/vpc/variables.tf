variable "vpc_cidr" { type = string }
variable "existing_vpc_id" {
  type    = string
  default = null
}
variable "subnet_offset" {
  type    = number
  default = 0
  validation {
    condition     = var.subnet_offset >= 0 && var.subnet_offset <= 252 && floor(var.subnet_offset) == var.subnet_offset
    error_message = "Choose an integer subnet offset from 0 through 252."
  }
}
