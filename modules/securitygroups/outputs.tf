# Security Groups module outputs

output "k8s_security_group_id" {
  description = "ID of the Kubernetes cluster security group"
  value       = aws_security_group.k8s_cluster.id
}

output "repo_security_group_id" {
  description = "ID of the private repository security group"
  value       = aws_security_group.repo.id
}

output "k8s_security_group_name" {
  description = "Name of the Kubernetes cluster security group"
  value       = aws_security_group.k8s_cluster.name
}

output "repo_security_group_name" {
  description = "Name of the private repository security group"
  value       = aws_security_group.repo.name
}