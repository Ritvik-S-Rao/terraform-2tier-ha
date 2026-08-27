# 1. ALB Security Group (Internet facing)
resource "aws_security_group" "alb" {
  name        = "devops-alb-sg"
  description = "Allow inbound HTTP/HTTPS from the internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devops-alb-sg"
  }
}

# 2. App / EC2 Security Group (Private)
resource "aws_security_group" "app" {
  name        = "devops-app-sg"
  description = "Allow inbound traffic strictly from the ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow HTTP from ALB SG only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic via NAT Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devops-app-sg"
  }
}

# 3. Database Security Group (Private)
resource "aws_security_group" "db" {
  name        = "devops-db-sg"
  description = "Allow inbound MySQL traffic strictly from the App SG"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow MySQL from App SG only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  tags = {
    Name = "devops-db-sg"
  }
}
