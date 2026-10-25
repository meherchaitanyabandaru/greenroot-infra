# PostgreSQL 17 + PostGIS on RDS. The master password is generated and kept
# by RDS in Secrets Manager (manage_master_user_password); it is only used by
# deploy/host/bin/init-db.sh to create the least-privilege roles.

resource "aws_db_subnet_group" "main" {
  name       = local.name
  subnet_ids = data.aws_subnets.default.ids
}

resource "aws_db_parameter_group" "pg17" {
  name   = "${local.name}-pg17"
  family = "postgres17"

  parameter {
    name  = "rds.force_ssl" # no plaintext connections, ever
    value = "1"
  }
  parameter {
    name  = "timezone"
    value = "Asia/Kolkata"
  }
  parameter {
    name  = "log_min_duration_statement" # slow queries into CloudWatch
    value = "1000"
  }
  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
    # Changing it needs a reboot; set at creation.
    apply_method = "pending-reboot"
  }
}

resource "aws_db_instance" "main" {
  identifier     = local.name
  engine         = "postgres"
  engine_version = "17"
  instance_class = var.db_instance_class

  db_name                     = "greenroot"
  username                    = "greenroot_admin"
  manage_master_user_password = true

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = var.db_multi_az
  parameter_group_name   = aws_db_parameter_group.pg17.name

  backup_retention_period  = var.db_backup_retention_days # PITR window
  backup_window            = "20:30-21:00"                # 02:00-02:30 IST
  maintenance_window       = "sun:21:30-sun:22:30"        # Monday 03:00 IST
  copy_tags_to_snapshot    = true
  delete_automated_backups = false

  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.name}-final"

  auto_minor_version_upgrade            = true
  performance_insights_enabled          = true
  performance_insights_retention_period = 7 # free tier
  enabled_cloudwatch_logs_exports       = ["postgresql"]
}
