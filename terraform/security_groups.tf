# ALB — public entry point, accepts traffic from the internet
resource "aws_security_group" "alb" {
  name        = "vprofile-alb-sg"
  description = "Allow HTTP/HTTPS from the internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vprofile-alb-sg"
  }
}

# App tier — Tomcat, accepts traffic only from the ALB
resource "aws_security_group" "app" {
  name        = "vprofile-app-sg"
  description = "Allow Tomcat traffic only from the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Tomcat from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vprofile-app-sg"
  }
}

# DB tier — MariaDB, accepts traffic only from the app tier
resource "aws_security_group" "db" {
  name        = "vprofile-db-sg"
  description = "Allow MariaDB traffic only from the app tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MariaDB from app tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vprofile-db-sg"
  }
}

# Cache tier — Memcached, accepts traffic only from the app tier
resource "aws_security_group" "mc" {
  name        = "vprofile-mc-sg"
  description = "Allow Memcached traffic only from the app tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Memcached from app tier"
    from_port       = 11211
    to_port         = 11211
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vprofile-mc-sg"
  }
}

# Message queue tier — RabbitMQ, accepts traffic only from the app tier
resource "aws_security_group" "rmq" {
  name        = "vprofile-rmq-sg"
  description = "Allow RabbitMQ traffic only from the app tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "RabbitMQ from app tier"
    from_port       = 5672
    to_port         = 5672
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vprofile-rmq-sg"
  }
}

# SSM VPC endpoints — accepts HTTPS from instances needing Session Manager access
resource "aws_security_group" "ssm_ep" {
  name        = "vprofile-ssm-ep-sg"
  description = "Allow HTTPS from private instances for SSM connectivity"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTPS from app tier"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description     = "HTTPS from db tier"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.db.id]
  }

  ingress {
    description     = "HTTPS from mc tier"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.mc.id]
  }

  ingress {
    description     = "HTTPS from rmq tier"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.rmq.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vprofile-ssm-ep-sg"
  }
}
