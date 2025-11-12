# Root module outputs
# Professional output formatting for easy access and reference

# ============================================================================
# NETWORK INFORMATION
# ============================================================================

output "vpc_id" {
  description = "VPC identifier"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet identifiers"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet identifiers"
  value       = module.network.private_subnet_ids
}

# ============================================================================
# LOAD BALANCER INFORMATION
# ============================================================================

output "load_balancer_dns" {
  description = "Network Load Balancer DNS name"
  value       = module.loadbalancer.nlb_dns_name
}

output "control_plane_endpoint" {
  description = "Kubernetes control plane endpoint (for kubeconfig)"
  value       = module.loadbalancer.control_plane_endpoint
}

# ============================================================================
# S3 BUCKET INFORMATION
# ============================================================================

output "s3_bucket_name" {
  description = "S3 bucket for join commands"
  value       = aws_s3_bucket.k8s_config.id
}

# ============================================================================
# KUBERNETES CLUSTER INFORMATION
# ============================================================================

output "cluster_info" {
  description = "Kubernetes cluster summary"
  value = {
    control_plane_endpoint = module.loadbalancer.control_plane_endpoint
    kubernetes_version     = "v1.30.0"
    cni_plugin            = "Flannel"
    pod_network_cidr      = "10.244.0.0/16"
    master_count          = var.master_count
    worker_count          = var.worker_count
  }
}

# ============================================================================
# SSH CONNECTION COMMANDS
# ============================================================================

output "ssh_commands" {
  description = "SSH commands to connect to each node"
  value = {
    master1 = "ssh -i wsl-terraform-key.pem ubuntu@${module.ec2.master_public_ips[0]}"
    master2 = var.master_count >= 2 ? "ssh -i wsl-terraform-key.pem ubuntu@${module.ec2.master_public_ips[1]}" : "N/A (only 1 master deployed)"
    master3 = var.master_count >= 3 ? "ssh -i wsl-terraform-key.pem ubuntu@${module.ec2.master_public_ips[2]}" : "N/A (only ${var.master_count} masters deployed)"
    worker1 = "ssh -i wsl-terraform-key.pem ubuntu@${module.ec2.worker_public_ips[0]}"
    worker2 = var.worker_count >= 2 ? "ssh -i wsl-terraform-key.pem ubuntu@${module.ec2.worker_public_ips[1]}" : "N/A (only 1 worker deployed)"
    repo    = "ssh -i wsl-terraform-key.pem ubuntu@${module.ec2.repo_public_ip}"
  }
}


# ============================================================================
# REPOSITORY HOST DETAILS
# ============================================================================

output "repository_host" {
  description = "Private repository host connection details"
  value = {
    name          = "repo"
    public_ip     = module.ec2.repo_public_ip
    private_ip    = module.ec2.repo_private_ip
    ssh           = "ssh -i wsl-terraform-key.pem ubuntu@${module.ec2.repo_public_ip}"
    docker_registry = "http://${module.ec2.repo_private_ip}:5000"
  }
}

