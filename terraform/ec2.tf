# Look up the latest Amazon Linux 2023 AMI at apply time.
# Each instance pins the resolved AMI via lifecycle.ignore_changes,
# so later plans won't propose replacing a running instance just
# because AWS published a newer patch AMI in the background.
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# App tier — Tomcat
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_1a.id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "vprofile-app"
  }
}

# DB tier — MariaDB
resource "aws_instance" "db" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_1a.id
  vpc_security_group_ids = [aws_security_group.db.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "vprofile-db"
  }
}

# Cache tier — Memcached
resource "aws_instance" "mc" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_1a.id
  vpc_security_group_ids = [aws_security_group.mc.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "vprofile-mc"
  }
}

# Message queue tier — RabbitMQ
resource "aws_instance" "rmq" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_1a.id
  vpc_security_group_ids = [aws_security_group.rmq.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "vprofile-rmq"
  }
}