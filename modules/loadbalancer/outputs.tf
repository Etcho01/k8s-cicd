# Load Balancer module outputs

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = aws_lb.k8s_api.dns_name
}

output "nlb_arn" {
  description = "ARN of the Network Load Balancer"
  value       = aws_lb.k8s_api.arn
}

output "nlb_zone_id" {
  description = "Zone ID of the Network Load Balancer"
  value       = aws_lb.k8s_api.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.k8s_api.arn
}

output "control_plane_endpoint" {
  description = "Control plane endpoint for kubeadm (LB DNS:PORT)"
  value       = "${aws_lb.k8s_api.dns_name}:6443"
}