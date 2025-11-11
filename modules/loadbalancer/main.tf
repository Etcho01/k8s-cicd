# Load Balancer module - Network Load Balancer for Kubernetes API HA
# Required for multi-master Kubernetes cluster
# Note: Target group attachments are done in EC2 module

# Network Load Balancer for Kubernetes API server
resource "aws_lb" "k8s_api" {
  name               = "${var.project_name}-${var.environment}-k8s-api-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-k8s-api-nlb"
      Purpose = "Kubernetes API Server HA"
    }
  )
}

# Target Group for Kubernetes API server (port 6443)
resource "aws_lb_target_group" "k8s_api" {
  name     = "${var.project_name}-${var.environment}-k8s-api-tg"
  port     = 6443
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
    protocol            = "TCP"
    port                = 6443
  }

  deregistration_delay = 30

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-k8s-api-tg"
      Purpose = "Kubernetes API Server Target Group"
    }
  )
}

# Listener for Kubernetes API (6443)
resource "aws_lb_listener" "k8s_api" {
  load_balancer_arn = aws_lb.k8s_api.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_api.arn
  }
}