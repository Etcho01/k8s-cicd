# EC2 module outputs

# Master node outputs
output "master_instance_ids" {
  description = "IDs of master instances"
  value       = aws_instance.master[*].id
}

output "master_private_ips" {
  description = "Private IP addresses of master nodes"
  value       = aws_instance.master[*].private_ip
}

output "master_public_ips" {
  description = "Public IP addresses of master nodes"
  value       = aws_instance.master[*].public_ip
}

output "master_private_dns" {
  description = "Private DNS names of master nodes"
  value       = aws_instance.master[*].private_dns
}

# Worker node outputs
output "worker_instance_ids" {
  description = "IDs of worker instances"
  value       = aws_instance.worker[*].id
}

output "worker_private_ips" {
  description = "Private IP addresses of worker nodes"
  value       = aws_instance.worker[*].private_ip
}

output "worker_public_ips" {
  description = "Public IP addresses of worker nodes"
  value       = aws_instance.worker[*].public_ip
}

output "worker_private_dns" {
  description = "Private DNS names of worker nodes"
  value       = aws_instance.worker[*].private_dns
}

# Repository host outputs
output "repo_instance_id" {
  description = "ID of repository instance"
  value       = aws_instance.repo.id
}

output "repo_private_ip" {
  description = "Private IP address of repository host"
  value       = aws_instance.repo.private_ip
}

output "repo_public_ip" {
  description = "Public IP address of repository host"
  value       = aws_instance.repo.public_ip
}

output "repo_private_dns" {
  description = "Private DNS name of repository host"
  value       = aws_instance.repo.private_dns
}