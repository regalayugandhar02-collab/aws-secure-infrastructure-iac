variable "aws_region" {
  description = "The AWS Region where resources will be deployed"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Name prefix for all infrastructure resources"
  type        = string
  default     = "secure-cloud"
}

variable "vpc_cidr" {
  description = "CIDR block for the custom VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of Availability Zones for Multi-AZ high availability"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (DMZ / Load Balancers)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for isolated private database subnets"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "allowed_admin_ip" {
  description = "Your trusted static IP address for administrative management (e.g., 203.0.113.50/32). Never set to 0.0.0.0/0."
  type        = string
  default     = "10.0.0.0/16" # Defaults to internal VPC CIDR to prevent world-open ports
}
