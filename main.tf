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

# Data source: Fetch latest Ubuntu 22.04 LTS AMI dynamically
# Ubuntu is the most documented and stable for Kubernetes deployments
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
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

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.network.vpc_id
  vpc_cidr        = var.vpc_cidr
  admin_cidr      = var.admin_cidr
  monitoring_cidr = var.monitoring_cidr # NEW: For Grafana/Prometheus access
  common_tags     = local.common_tags
}

# S3 bucket for sharing join commands between nodes
resource "aws_s3_bucket" "k8s_config" {
  bucket_prefix = "${var.project_name}-k8s-config-"

  tags = merge(
    local.common_tags,
    {
      Name    = "${var.project_name}-k8s-config"
      Purpose = "Kubernetes join commands"
    }
  )
}

resource "aws_s3_bucket_versioning" "k8s_config" {
  bucket = aws_s3_bucket.k8s_config.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "k8s_config" {
  bucket = aws_s3_bucket.k8s_config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "k8s_config" {
  bucket = aws_s3_bucket.k8s_config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Module: Load Balancer for Kubernetes API HA (created BEFORE EC2 instances)
module "loadbalancer" {
  source = "./modules/loadbalancer"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  common_tags       = local.common_tags
}

# Module: EC2 instances (masters, workers, repo host)
# Masters will use LB DNS as control-plane-endpoint
module "ec2" {
  source = "./modules/ec2"

  project_name               = var.project_name
  environment                = var.environment
  aws_region                 = var.aws_region
  s3_bucket_name             = aws_s3_bucket.k8s_config.id
  s3_bucket_arn              = aws_s3_bucket.k8s_config.arn
  ami_id                     = data.aws_ami.ubuntu.id
  instance_type              = var.instance_type
  key_name                   = var.key_name
  master_count               = var.master_count
  worker_count               = var.worker_count
  public_subnet_ids          = module.network.public_subnet_ids
  private_subnet_ids         = module.network.private_subnet_ids
  k8s_security_group_id      = module.securitygroups.k8s_security_group_id
  repo_security_group_id     = module.securitygroups.repo_security_group_id
  enable_detailed_monitoring = var.enable_detailed_monitoring
  root_volume_size           = var.root_volume_size
  root_volume_type           = var.root_volume_type
  common_tags                = local.common_tags
  control_plane_endpoint     = module.loadbalancer.control_plane_endpoint
  target_group_arn           = module.loadbalancer.target_group_arn

  depends_on = [
    aws_s3_bucket.k8s_config,
    module.loadbalancer
  ]
}