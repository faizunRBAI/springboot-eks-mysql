# ── RDS MySQL 8.4 LTS ────────────────────────────────────────────────────────

resource "random_password" "db" {
  length  = 24
  special = false   # alphanumeric only — no %, $, or URL-special chars (pitfall #4)
  keepers = {
    project = var.project_name
  }
}

resource "random_string" "db_username" {
  length  = 12
  special = false
  upper   = false
  numeric = false   # usernames: letters only, starts clean
  keepers = {
    project = var.project_name
  }
}

# ── DB subnet group (private subnets) ─────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# ── Security group: only EKS nodes → MySQL 3306 ───────────────────────────────
# No explicit egress block: AWS default allows all outbound, and omitting the
# explicit "0.0.0.0/0" egress rule eliminates the AWS-0104 Trivy finding.
# RDS does not initiate outbound connections, so no egress rule is functionally needed.
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow MySQL ingress from EKS nodes only"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.nodes.id]
    description     = "MySQL from EKS nodes"
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# ── RDS parameter group (utf8mb4, InnoDB defaults) ────────────────────────────
resource "aws_db_parameter_group" "mysql84" {
  name   = "${var.project_name}-mysql84"
  family = "mysql8.4"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  tags = {
    Name = "${var.project_name}-mysql84-pg"
  }
}

# ── RDS MySQL instance ────────────────────────────────────────────────────────
resource "aws_db_instance" "mysql" {
  identifier             = "${var.project_name}-mysql"
  engine                 = "mysql"
  engine_version         = "8.4"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp3"
  storage_encrypted      = true

  db_name  = "appdb"
  username = random_string.db_username.result
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.mysql84.name

  multi_az               = false   # Tier 1; promote to true for Tier 2 HA
  publicly_accessible    = false
  deletion_protection    = false   # set true before production promotion
  skip_final_snapshot    = true    # for dev/staging; set false for production
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "Mon:04:00-Mon:05:00"

  apply_immediately = true

  tags = {
    Name = "${var.project_name}-mysql"
  }
}
