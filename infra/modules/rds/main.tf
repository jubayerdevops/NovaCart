# ---------------------------------------------------------------- Subnet group
# Tells RDS which subnets it may use: the database tier in both AZs
resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = var.database_subnet_ids

  tags = { Name = "${var.name_prefix}-db-subnets" }
}

# ---------------------------------------------------------------- MySQL
resource "aws_db_instance" "this" {
  identifier     = "${var.name_prefix}-mysql"
  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true # encryption at rest

  db_name  = var.db_name
  username = var.master_username

  # AWS generates the password and stores it in Secrets Manager.
  # It never appears in code, variables or Terraform state.
  manage_master_user_password = true

  # Network: private only
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.db_sg_id]
  publicly_accessible    = false

  # Per-environment settings
  multi_az                  = var.multi_az
  deletion_protection       = var.deletion_protection
  backup_retention_period   = var.backup_retention_period
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-mysql-final"

  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true
  apply_immediately          = true

  tags = { Name = "${var.name_prefix}-mysql" }
}