data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  count                = var.existing_vpc_id == null ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
}

data "aws_vpc" "existing" {
  count = var.existing_vpc_id == null ? 0 : 1
  id    = var.existing_vpc_id
}

data "aws_internet_gateway" "existing" {
  count = var.existing_vpc_id == null ? 0 : 1
  filter {
    name   = "attachment.vpc-id"
    values = [var.existing_vpc_id]
  }
}

locals {
  vpc_id   = var.existing_vpc_id == null ? aws_vpc.main[0].id : data.aws_vpc.existing[0].id
  vpc_cidr = var.existing_vpc_id == null ? var.vpc_cidr : data.aws_vpc.existing[0].cidr_block
  igw_id   = var.existing_vpc_id == null ? aws_internet_gateway.igw[0].id : data.aws_internet_gateway.existing[0].id
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = local.vpc_id
  cidr_block              = cidrsubnet(local.vpc_cidr, 8, var.subnet_offset + count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = local.vpc_id
  cidr_block        = cidrsubnet(local.vpc_cidr, 8, var.subnet_offset + count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

resource "aws_internet_gateway" "igw" {
  count  = var.existing_vpc_id == null ? 1 : 0
  vpc_id = local.vpc_id
}

resource "aws_route_table" "public" {
  vpc_id = local.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = local.igw_id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = local.vpc_id
}
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
