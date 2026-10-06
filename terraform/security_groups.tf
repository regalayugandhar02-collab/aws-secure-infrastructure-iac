# ==============================================================================
# SECURITY GROUPS (Tiered Least Privilege & CIS Network Hardening)
# Compliant with CIS AWS Foundations Benchmark (4.1 & 4.2)
# ==============================================================================

# 1. Web Tier / Load Balancer Security Group
# Only exposes HTTP (80) & HTTPS (443) to the public internet
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-tier-sg"
  description = "Security group for public-facing web tier and load balancers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow inbound HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow inbound HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound to app tier"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
    Tier = "Web-DMZ"
  }
}

# 2. Application Tier Security Group (Private)
# Ingress is ONLY allowed from the Web Security Group (Tiered Defense)
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-tier-sg"
  description = "Security group for internal backend application instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow traffic from Web SG only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  # CIS 4.1 Compliance: SSH is NOT open to 0.0.0.0/0
  ingress {
    description = "Restricted management access (Never open to 0.0.0.0/0)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_admin_ip]
  }

  egress {
    description = "Allow outbound communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-app-sg"
    Tier = "Application"
  }
}

# 3. Database Tier Security Group (Isolated Private)
# Ingress is ONLY allowed from the Application Security Group
resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-db-tier-sg"
  description = "Security group for isolated database tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow database traffic from App SG only"
    from_port       = 5432 # PostgreSQL (or 3306 for MySQL)
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    description = "Allow outbound to local VPC only"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${var.project_name}-db-sg"
    Tier = "Database"
  }
}
