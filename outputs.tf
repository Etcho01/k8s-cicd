# Root module outputs
# Export important resource identifiers and endpoints

# Network outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "s3_bucket_name" {
  description = "S3 bucket name for Kubernetes config"
  value       = aws_s3_bucket.k8s_config.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for Kubernetes config"
  value       = aws_s3_bucket.k8s_config.arn
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.network.private_subnet_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.network.internet_gateway_id
}

# Security group outputs
output "k8s_security_group_id" {
  description = "ID of Kubernetes cluster security group"
  value       = module.securitygroups.k8s_security_group_id
}

output "repo_security_group_id" {
  description = "ID of private repository security group"
  value       = module.securitygroups.repo_security_group_id
}

# EC2 instance outputs
output "master_instance_ids" {
  description = "IDs of Kubernetes master instances"
  value       = module.ec2.master_instance_ids
}

output "master_private_ips" {
  description = "Private IP addresses of master nodes"
  value       = module.ec2.master_private_ips
}

output "master_public_ips" {
  description = "Public IP addresses of master nodes"
  value       = module.ec2.master_public_ips
}

output "worker_instance_ids" {
  description = "IDs of Kubernetes worker instances"
  value       = module.ec2.worker_instance_ids
}

output "worker_private_ips" {
  description = "Private IP addresses of worker nodes"
  value       = module.ec2.worker_private_ips
}

output "worker_public_ips" {
  description = "Public IP addresses of worker nodes"
  value       = module.ec2.worker_public_ips
}

output "repo_instance_id" {
  description = "ID of private repository instance"
  value       = module.ec2.repo_instance_id
}

output "repo_private_ip" {
  description = "Private IP address of repository host"
  value       = module.ec2.repo_private_ip
}

output "repo_public_ip" {
  description = "Public IP address of repository host"
  value       = module.ec2.repo_public_ip
}

# AMI information
output "ami_id" {
  description = "AMI ID used for instances"
  value       = data.aws_ami.ubuntu.id
}

output "ami_name" {
  description = "AMI name"
  value       = data.aws_ami.ubuntu.name
}

# Kubernetes cluster information
output "kubernetes_cluster_info" {
  description = "Information for connecting to the Kubernetes cluster"
  value = {
    api_endpoint    = "https://${module.ec2.master_public_ips[0]}:6443"
    master_nodes    = module.ec2.master_private_ips
    worker_nodes    = module.ec2.worker_private_ips
    kubeconfig_note = "SSH to master1 and copy /etc/kubernetes/admin.conf"
  }
}

# Connection instructions
output "ssh_connection_commands" {
  description = "SSH commands to connect to instances"
  value = {
    master1 = "ssh -i /path/to/${var.key_name}.pem ec2-user@${module.ec2.master_public_ips[0]}"
    worker1 = "ssh -i /path/to/${var.key_name}.pem ec2-user@${module.ec2.worker_public_ips[0]}"
    repo    = "ssh -i /path/to/${var.key_name}.pem ec2-user@${module.ec2.repo_public_ip}"
  }
}