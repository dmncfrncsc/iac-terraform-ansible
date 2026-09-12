variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "172.20.0.0/16"
}

variable "public_subnet_1a_cidr" {
  description = "CIDR block for public subnet in us-east-1a"
  type        = string
  default     = "172.20.1.0/24"
}

variable "public_subnet_1b_cidr" {
  description = "CIDR block for public subnet in us-east-1b"
  type        = string
  default     = "172.20.2.0/24"
}

variable "private_subnet_1a_cidr" {
  description = "CIDR block for private subnet in us-east-1a"
  type        = string
  default     = "172.20.3.0/24"
}

variable "az_1a" {
  description = "Availability zone A used for subnet placement"
  type        = string
  default     = "us-east-1a"
}

variable "az_1b" {
  description = "Availability zone B used for subnet placement"
  type        = string
  default     = "us-east-1b"
}
