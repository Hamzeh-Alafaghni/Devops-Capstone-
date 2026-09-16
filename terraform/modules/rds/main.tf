resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db"
  subnet_ids = var.private_subnet_ids
}
resource "aws_db_parameter_group" "postgres" {
  name_prefix = "${var.project}-"
  family      = "postgres15"
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}
resource "aws_db_instance" "postgres" {
  identifier                  = "${var.project}-db"
  instance_class              = "db.t3.micro"
  engine                      = "postgres"
  engine_version              = "15"
  allocated_storage           = 20
  storage_encrypted           = true
  db_name                     = "marketly"
  username                    = "marketly_admin"
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.main.name
  parameter_group_name        = aws_db_parameter_group.postgres.name
  vpc_security_group_ids      = [var.rds_sg_id]
  publicly_accessible         = false
  backup_retention_period     = 1
  skip_final_snapshot         = true # Disposable capstone; export data before teardown.
}
