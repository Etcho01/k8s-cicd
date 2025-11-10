# Root module variables
# Define all configurable parameters for the infrastructure

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner/team responsible for the infrastructure"
  type        = string
  default     = "mohamed.hesham"
}

variable "project_name" {
  description = "Project identifier"
  type        = string
  default     = "cicd-k8s"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for all nodes"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "SSH key pair name for EC2 instances"
  type        = string
  # Must be created in AWS EC2 console before deployment
  # Example: aws ec2 create-key-pair --key-name cicd-k8s-key --query 'KeyMaterial' --output text > cicd-k8s-key.pem
}

variable "admin_cidr" {
  description = "CIDR block allowed for SSH access to instances"
  type        = string
  # Restrict this to your IP for security
  # Example: "203.0.113.0/32"
}

variable "master_count" {
  description = "Number of Kubernetes master nodes"
  type        = number
  default     = 3
}

variable "worker_count" {
  description = "Number of Kubernetes worker nodes"
  type        = number
  default     = 2
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring for EC2 instances"
  type        = bool
  default     = false
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Root EBS volume type"
  type        = string
  default     = "gp3"
}