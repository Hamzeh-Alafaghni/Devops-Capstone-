variable "private_subnet_ids" {}
variable "rds_sg_id" {}

resource "aws_db_subnet_group" "main" {
  name       = "marketly-db-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_db_instance" "postgres" {
  identifier             = "marketly-db"
  instance_class         = "db.t3.micro"
  engine                 = "postgres"
  engine_version         = "15"
  allocated_storage      = 20
  db_name                = "marketly"
  username               = "admin"
  password               = "password123"
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  skip_final_snapshot    = true
}
