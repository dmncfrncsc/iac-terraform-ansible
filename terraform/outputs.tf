output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_1a_id" {
  description = "ID of the public subnet in us-east-1a"
  value       = aws_subnet.public_1a.id
}

output "public_subnet_1b_id" {
  description = "ID of the public subnet in us-east-1b"
  value       = aws_subnet.public_1b.id
}

output "private_subnet_1a_id" {
  description = "ID of the private subnet in us-east-1a"
  value       = aws_subnet.private_1a.id
}
