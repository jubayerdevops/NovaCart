# Chain of trust:  Internet -> ALB SG -> App SG -> DB SG
# Each tier only accepts traffic from the security group directly in front of it.

# ================================================================ Groups
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "ALB: HTTP/HTTPS from the internet"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-alb-sg", Tier = "web" }
}

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app-sg"
  description = "App: HTTP from the ALB only"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-app-sg", Tier = "app" }
}

resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db-sg"
  description = "DB: MySQL from the app tier only"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-db-sg", Tier = "database" }
}

resource "aws_security_group" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name        = "${var.name_prefix}-bastion-sg"
  description = "Bastion: SSH from allowed_ssh_cidr only"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-bastion-sg", Tier = "bastion" }

  lifecycle {
    precondition {
      condition     = var.allowed_ssh_cidr != null
      error_message = "allowed_ssh_cidr must be set when enable_bastion = true."
    }
  }
}

# ================================================================ ALB rules
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count = var.enable_https ? 1 : 0

  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from the internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward requests and health checks to the app tier"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.app.id
}

# ================================================================ App rules
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "HTTP from the ALB only"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_ingress_rule" "app_ssh_from_bastion" {
  count = var.enable_bastion ? 1 : 0

  security_group_id            = aws_security_group.app.id
  description                  = "SSH from the bastion only"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion[0].id
}

resource "aws_vpc_security_group_egress_rule" "app_https_out" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS out via NAT (SSM, Secrets Manager, package repos)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app_http_out" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP out via NAT (package repos)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "MySQL to the DB tier"
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
  referenced_security_group_id = aws_security_group.db.id
}

# ================================================================ DB rules
resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL from the app tier only"
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
  referenced_security_group_id = aws_security_group.app.id
}
# No egress rules for the DB: RDS never starts connections, and replies
# are allowed automatically because security groups are stateful.

# ================================================================ Bastion rules
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  count = var.enable_bastion ? 1 : 0

  security_group_id = aws_security_group.bastion[0].id
  description       = "SSH from my IP only"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.allowed_ssh_cidr
}

resource "aws_vpc_security_group_egress_rule" "bastion_to_app" {
  count = var.enable_bastion ? 1 : 0

  security_group_id            = aws_security_group.bastion[0].id
  description                  = "SSH onward to the app tier"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.app.id
}