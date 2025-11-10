# Main Terraform configuration
# Orchestrates all modules and defines data sources

# Local variables for consistent tagging and naming
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

# Data source: Fetch available AWS availability zones dynamically
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source: Fetch latest Amazon Linux 2 AMI dynamically
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Module: Network infrastructure (VPC, subnets, IGW, routing)
module "network" {
  source = "./modules/network"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = data.aws_availability_zones.available.names
  common_tags          = local.common_tags
}

# Module: Security groups for Kubernetes cluster and private repo
module "securitygroups" {
  source = "./modules/securitygroups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.network.vpc_id
  vpc_cidr     = var.vpc_cidr
  admin_cidr   = var.admin_cidr
  common_tags  = local.common_tags
}

# Module: EC2 instances (masters, workers, repo host)
module "ec2" {
  source = "./modules/ec2"

  project_name             = var.project_name
  environment              = var.environment
  ami_id                   = data.aws_ami.amazon_linux.id
  instance_type            = var.instance_type
  key_name                 = var.key_name
  master_count             = var.master_count
  worker_count             = var.worker_count
  public_subnet_ids        = module.network.public_subnet_ids
  private_subnet_ids       = module.network.private_subnet_ids
  k8s_security_group_id    = module.securitygroups.k8s_security_group_id
  repo_security_group_id   = module.securitygroups.repo_security_group_id
  enable_detailed_monitoring = var.enable_detailed_monitoring
  root_volume_size         = var.root_volume_size
  root_volume_type         = var.root_volume_type
  common_tags              = local.common_tags
}