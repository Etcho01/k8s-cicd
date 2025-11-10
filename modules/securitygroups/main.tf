# Security Groups module - Network access control for Kubernetes cluster
# Implements least-privilege access with Kubernetes-specific ports

# Security Group: Kubernetes Cluster
# Controls traffic between masters, workers, and internal cluster communication
resource "aws_security_group" "k8s_cluster" {
  name_prefix = "${var.project_name}-${var.environment}-k8s-"
  description = "Security group for Kubernetes cluster nodes (masters and workers)"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-k8s-sg"
      Type = "kubernetes-cluster"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Ingress Rule: Kubernetes API Server (6443)
# Allows external access to Kubernetes API from admin CIDR
resource "aws_vpc_security_group_ingress_rule" "k8s_api_server" {
  security_group_id = aws_security_group.k8s_cluster.id
  description       = "Kubernetes API Server"

  from_port   = 6443
  to_port     = 6443
  ip_protocol = "tcp"
  cidr_ipv4   = var.admin_cidr
}

# Ingress Rule: Kubernetes API Server (internal cluster access)
resource "aws_vpc_security_group_ingress_rule" "k8s_api_server_internal" {
  security_group_id = aws_security_group.k8s_cluster.id
  description       = "Kubernetes API Server - internal cluster"

  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.k8s_cluster.id
}

# Ingress Rule: etcd server client API (2379-2380)
# Used by control plane components to access etcd
resource "aws_vpc_security_group_ingress_rule" "etcd" {
  security_group_id = aws_security_group.k8s_cluster.id
  description       = "etcd server client API"

  from_port                    = 2379
  to_port                      = 2380
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.k8s_cluster.id
}

# Ingress Rule: Kubelet API (10250)
# Required for kubectl logs, exec, and other kubelet operations
resource "aws_vpc_security_group_ingress_rule" "kubelet_api" {
  security_group_id = aws_security_group.k8s_cluster.id
  description       = "Kubelet API"

  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.k8s_cluster.id
}

# Ingress Rule: Kube-scheduler (10259)
# Scheduler health check and metrics
resource "aws_vpc_security_group_ingress_rule" "kube_scheduler" {
  security_group_id = aws_security_group.k8s_cluster.id
  description       = "Kube-scheduler"

  from_port                    = 10259
  to_port                      = 10259
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.k8s_cluster.id
}

# Ingress Rule: Kube-controller-manager (10257)
# Controller manager health check and metrics
resource "aws_vpc_security_group_ingress_rule" "kube_controller_manager" {
  security_group_id = aws_security_group.k8s_cluster.id
  description       = "Kube-controller-manager"

  from_port                    = 10257
  to_port                      = 10257
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.k8s_cluster.id
}

# Ingress Rule: NodePort Services (30000-32767)
# Allow access to services exposed via NodePort
resource "aws_vpc_security_group_ingress_rule" "nodeport_services" {
  security_group_id = aws_security_group.k8s_cluster.id
  description       = "NodePort Services"

  from_port                    = 30000
  to_port                      = 32767
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.k8s_cluster.id
}

# Ingress Rule: Flannel VXLAN (8472)
# Required for Flannel pod network overlay
resource "aws_vpc_security_group_ingress_rule" "flannel_vxlan" {
  security_group_id = aws_security_group.k8s_cluster.id
  description       = "Flannel VXLAN overlay network"

  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
  referenced_security_group_id = aws_security_group.k8s_cluster.id
}

# Ingress Rule: All internal cluster traffic
# Allows all communication between cluster nodes
resource "aws_vpc_security_group_ingress_rule" "cluster_internal" {
  security_group_id = aws_security_group.k8s_cluster.id
  description       = "All internal cluster communication"

  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.k8s_cluster.id
}

# Ingress Rule: SSH access from admin CIDR
resource "aws_vpc_security_group_ingress_rule" "ssh_admin" {
  security_group_id = aws_security_group.k8s_cluster.id
  description       = "SSH access from admin"

  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
  cidr_ipv4   = var.admin_cidr
}

# Egress Rule: Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "k8s_egress_all" {
  security_group_id = aws_security_group.k8s_cluster.id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

# Security Group: Private Repository Host
# Separate security group for the private repository server
resource "aws_security_group" "repo" {
  name_prefix = "${var.project_name}-${var.environment}-repo-"
  description = "Security group for private repository host"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-repo-sg"
      Type = "private-repository"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Ingress Rule: Allow all traffic from Kubernetes cluster
resource "aws_vpc_security_group_ingress_rule" "repo_from_k8s" {
  security_group_id = aws_security_group.repo.id
  description       = "Allow all traffic from Kubernetes cluster"

  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.k8s_cluster.id
}

# Ingress Rule: SSH access from admin CIDR to repo
resource "aws_vpc_security_group_ingress_rule" "repo_ssh_admin" {
  security_group_id = aws_security_group.repo.id
  description       = "SSH access from admin"

  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
  cidr_ipv4   = var.admin_cidr
}

# Ingress Rule: HTTP/HTTPS for repository access (if needed)
resource "aws_vpc_security_group_ingress_rule" "repo_http" {
  security_group_id = aws_security_group.repo.id
  description       = "HTTP access for repository"

  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.k8s_cluster.id
}

resource "aws_vpc_security_group_ingress_rule" "repo_https" {
  security_group_id = aws_security_group.repo.id
  description       = "HTTPS access for repository"

  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.k8s_cluster.id
}

# Egress Rule: Allow all outbound traffic from repo
resource "aws_vpc_security_group_egress_rule" "repo_egress_all" {
  security_group_id = aws_security_group.repo.id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}