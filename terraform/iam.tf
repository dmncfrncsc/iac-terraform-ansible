# IAM role assumable by EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "vprofile-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "vprofile-ec2-role"
  }
}

# Least-privilege policy: read only the two specific secrets this project uses
resource "aws_iam_role_policy" "secrets_access" {
  name = "vprofile-secrets-access"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "secretsmanager:GetSecretValue"
        Resource = [
          "arn:aws:secretsmanager:us-east-1:747336059892:secret:vprofile/db/admin-password-*",
          "arn:aws:secretsmanager:us-east-1:747336059892:secret:vprofile/rmq/test-password-*"
        ]
      }
    ]
  })
}

# AWS-managed policy granting SSM Session Manager connectivity
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile — the wrapper that actually attaches to an EC2 instance
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "vprofile-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}
