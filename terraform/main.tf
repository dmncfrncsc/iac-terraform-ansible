# VPC — reproduces the network from Project 1 (aws-lift-and-shift)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vprofile-vpc"
  }
}

# Internet Gateway — allows public subnets to route traffic to/from the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "vprofile-igw"
  }
}

# Public subnet — AZ 1a
resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1a_cidr
  availability_zone       = var.az_1a
  map_public_ip_on_launch = true

  tags = {
    Name = "vprofile-public-1a"
  }
}

# Public subnet — AZ 1b
resource "aws_subnet" "public_1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1b_cidr
  availability_zone       = var.az_1b
  map_public_ip_on_launch = true

  tags = {
    Name = "vprofile-public-1b"
  }
}

# Private subnet — AZ 1a (no public IP assignment, no internet route)
resource "aws_subnet" "private_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_1a_cidr
  availability_zone       = var.az_1a
  map_public_ip_on_launch = false

  tags = {
    Name = "vprofile-private-1a"
  }
}

# Public route table — default route to the Internet Gateway is what makes
# subnets associated with this table "public"
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "vprofile-public-rt"
  }
}

# Associate both public subnets with the public route table
resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1b" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.public.id
}

# SSM VPC Endpoints — allow private instances to reach SSM without internet access
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1a.id]
  security_group_ids  = [aws_security_group.ssm_ep.id]
  private_dns_enabled = true

  tags = {
    Name = "vprofile-ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1a.id]
  security_group_ids  = [aws_security_group.ssm_ep.id]
  private_dns_enabled = true

  tags = {
    Name = "vprofile-ssmmessages-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1a.id]
  security_group_ids  = [aws_security_group.ssm_ep.id]
  private_dns_enabled = true

  tags = {
    Name = "vprofile-ec2messages-endpoint"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "vprofile-s3-endpoint"
  }
}

# Private route table — no internet route, local VPC traffic only
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "vprofile-private-rt"
  }
}

# Associate private subnet with the private route table
resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private.id
}

# Private DNS for internal service resolution (Route 53 private hosted zone)
# Matches course lecture "DNS Route 53" — avoids hardcoding IPs into the app,
# so instance recreation only requires a DNS record update, not a source change.
resource "aws_route53_zone" "internal" {
  name = "vprofile.internal"

  vpc {
    vpc_id = aws_vpc.main.id
  }
}

resource "aws_route53_record" "db01" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "db01.vprofile.internal"
  type    = "A"
  ttl     = 300
  records = ["172.20.3.56"]
}

resource "aws_route53_record" "mc01" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "mc01.vprofile.internal"
  type    = "A"
  ttl     = 300
  records = ["172.20.3.237"]
}

resource "aws_route53_record" "rmq01" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "rmq01.vprofile.internal"
  type    = "A"
  ttl     = 300
  records = ["172.20.3.106"]
}

resource "aws_vpc_dhcp_options" "main" {
  domain_name         = "vprofile.internal"
  domain_name_servers = ["AmazonProvidedDNS"]

  tags = {
    Name    = "vprofile-dhcp-options"
    Project = "iac-terraform-ansible"
  }
}

resource "aws_vpc_dhcp_options_association" "main" {
  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.main.id
}