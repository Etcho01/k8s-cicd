# High Availability Kubernetes Cluster on AWS

> **Production-ready Kubernetes v1.30 cluster with 3 control plane nodes, Network Load Balancer, and automatic node joining via S3**

(https://img.shields.io/badge/Kubernetes-v1.30.0-326CE5?logo=kubernetes) (https://kubernetes.io/)
---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Post-Deployment](#post-deployment)
- [Troubleshooting](#troubleshooting)
- [Cost Estimation](#cost-estimation)
- [Security](#security)
- [Maintenance](#maintenance)
- [Contributing](#contributing)

---

## 🎯 Overview

This project provides a complete Infrastructure as Code (IaC) solution for deploying a **production-ready High Availability Kubernetes cluster** on AWS using Terraform. The cluster features:

- **3 Control Plane Nodes** for HA with automatic failover
- **2 Worker Nodes** for workload execution
- **Network Load Balancer** for stable API endpoint
- **Automatic Node Joining** via S3 (no manual intervention)
- **Private Docker Registry** for container images
- **Full Observability** with proper tagging and naming

### Why This Solution?

✅ **Production-Ready**: Follows official Kubernetes HA documentation  
✅ **Fully Automated**: Zero manual steps after `terraform apply`  
✅ **Battle-Tested**: Uses Ubuntu 22.04 LTS and stable K8s versions  
✅ **Infrastructure as Code**: Version-controlled, repeatable deployments  

---
### Network Architecture

```
VPC (10.0.0.0/16)
├── Public Subnets (10.0.1.0/24, 10.0.2.0/24)
│   ├── Network Load Balancer
│   ├── 3 Master Nodes (control plane)
│   ├── 2 Worker Nodes (compute)
│   └── 1 Repository Host (Docker registry)
├── Private Subnets (10.0.10.0/24, 10.0.11.0/24)
│   └── Reserved for future use
├── Internet Gateway
└── S3 Bucket (join commands storage)
```

---

## ✨ Features

### Core Features
- ✅ **High Availability**: 3 control plane nodes with automatic failover
- ✅ **Network Load Balancer**: Stable endpoint for API server (--control-plane-endpoint)
- ✅ **Automatic Node Joining**: S3-based join command distribution
- ✅ **Custom Hostnames**: Nodes named master1-3, worker1-2 (not IPs)
- ✅ **Flannel CNI**: Pod networking with VXLAN overlay
- ✅ **Ubuntu 22.04 LTS**: Long-term support until 2027
- ✅ **Kubernetes 1.30**: Latest stable release

### Infrastructure Features
- ✅ **Modular Terraform**: Reusable modules (network, security, ec2, loadbalancer)
- ✅ **S3 State Backend**: Remote state with locking via DynamoDB
- ✅ **Encrypted Storage**: EBS volumes encrypted at rest
- ✅ **IAM Roles**: Instance profiles for secure AWS API access
- ✅ **Security Groups**: Least-privilege network access
- ✅ **Proper Tagging**: Organized resource management

### Operational Features
- ✅ **Professional Outputs**: Clear SSH commands and cluster info
- ✅ **Private Docker Registry**: Self-hosted container registry
- ✅ **Complete Documentation**: Comprehensive guides and troubleshooting
- ✅ **Validation Scripts**: Pre-deployment checks

---

## 📋 Prerequisites

### Required Tools
- **Terraform** >= 1.7.0 ([Install](https://www.terraform.io/downloads))
- **AWS CLI** v2 ([Install](https://aws.amazon.com/cli/))
- **SSH Client** (ssh command)
- **Git** (for cloning repository)

### AWS Requirements
- **AWS Account** with appropriate permissions
- **IAM Permissions**:
  - EC2 (instances, VPC, security groups, load balancers)
  - S3 (bucket creation and management)
  - IAM (roles and policies)
  - DynamoDB (for state locking)

### SSH Key Setup
```bash
# Create SSH key pair in AWS (if not exists)
aws ec2 create-key-pair \
  --key-name wsl-terraform-key \
  --region eu-west-1 \
  --query 'KeyMaterial' \
  --output text > wsl-terraform-key.pem

# Set proper permissions
chmod 400 wsl-terraform-key.pem
```

### AWS Credentials
```bash
# Configure AWS CLI
aws configure

# Or export credentials
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_DEFAULT_REGION="eu-west-1"
```

---

## 📂 Project Structure

```
k8s-cicd/
├── main.tf                          # Root orchestration
├── variables.tf                     # Input variables
├── outputs.tf                       # Formatted outputs
├── provider.tf                      # AWS provider config
├── terraform.tf                     # Backend configuration
├── terraform.tfvars.example         # Example variables
├── wsl-terraform-key.pem           # Your SSH key
│
├── scripts/
│   ├── master_setup.sh              # First master initialization
│   ├── master_join.sh               # Additional masters join
│   ├── worker_setup.sh              # Workers join
│   ├── repo_setup.sh                # Repository host setup
│   └── setup-terraform-backend.sh   # S3/DynamoDB creation
│
├── modules/
│   ├── network/                     # VPC, subnets, routing
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── securitygroups/              # Security groups
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── loadbalancer/                # Network Load Balancer
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── ec2/                         # EC2 instances + IAM
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── docs/                            # Additional documentation
    ├── HA_DEPLOYMENT_GUIDE.md
    ├── TROUBLESHOOTING.md
    └── CHANGELOG.md
```

---

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone <your-repo-url>
cd k8s-cicd
```

### 2. Setup Backend
```bash
# Create S3 bucket and DynamoDB table for state management
chmod +x scripts/setup-terraform-backend.sh
./scripts/setup-terraform-backend.sh

# Note the bucket name from output
# Update terraform.tf with your bucket name
```

### 3. Configure Variables
```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

**Required Changes:**
```hcl
admin_cidr = "YOUR_PUBLIC_IP/32"  # Get your IP: curl ifconfig.me
```

### 4. Deploy
```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan

# Deploy infrastructure
terraform apply
```

### 5. Access Cluster
```bash
# Wait ~15 minutes for cluster initialization

# SSH to master1
ssh -i wsl-terraform-key.pem ubuntu@$(terraform output -json master_nodes | jq -r '.[0].public_ip')

# Check cluster
kubectl get nodes
```

**Expected Output:**
```
NAME      STATUS   ROLES           AGE   VERSION
master1   Ready    control-plane   10m   v1.30.0
master2   Ready    control-plane   8m    v1.30.0
master3   Ready    control-plane   8m    v1.30.0
worker1   Ready    <none>          6m    v1.30.0
worker2   Ready    <none>          6m    v1.30.0
```

---

## ⚙️ Configuration

### Key Variables (terraform.tfvars)

```hcl
# AWS Configuration
aws_region  = "eu-west-1"           # AWS region
environment = "dev"                  # Environment name
owner       = "your-name"            # Resource owner

# Network Configuration
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

# Cluster Configuration
master_count = 3                     # Number of control plane nodes
worker_count = 2                     # Number of worker nodes

# Instance Configuration
instance_type    = "t3.small"        # Instance size
root_volume_size = 20                # Root disk size (GB)
root_volume_type = "gp3"             # EBS volume type

# Security
key_name   = "wsl-terraform-key"     # SSH key name
admin_cidr = "YOUR_IP/32"            # Your public IP
```

### Customization Options

#### Change Instance Type
```hcl
# For more resources
instance_type = "t3.medium"  # 2 vCPU, 4 GB RAM

# For production
instance_type = "t3.large"   # 2 vCPU, 8 GB RAM
```

#### Adjust Cluster Size
```hcl
# Smaller cluster
master_count = 1
worker_count = 1

# Larger cluster
master_count = 3
worker_count = 5
```

---

## 🎯 Deployment

### Full Deployment Process

#### Step 1: Pre-Deployment Validation
```bash
# Check AWS credentials
aws sts get-caller-identity

# Validate Terraform syntax
terraform validate

# Check format
terraform fmt -check -recursive
```

#### Step 2: Plan Review
```bash
# Generate and review plan
terraform plan -out=tfplan

# Expected resources: ~35-40
```

#### Step 3: Apply Infrastructure
```bash
# Deploy
terraform apply tfplan

# Or with auto-approve
terraform apply -auto-approve
```

#### Step 4: Monitor Deployment
```bash
# Watch Terraform progress
# Total time: ~15 minutes

# Timeline:
# 0-2 min:   VPC, subnets, NLB, S3 bucket
# 2-10 min:  Master1 initializes Kubernetes
# 10-13 min: Masters 2-3 join cluster
# 13-15 min: Workers 1-2 join cluster
```

### Deployment Outputs

After deployment, you'll see professional formatted outputs:

```
Outputs:

deployment_summary = <<EOT

╔════════════════════════════════════════════════════════════════════════╗
║                  KUBERNETES CLUSTER DEPLOYMENT SUMMARY                  ║
╚════════════════════════════════════════════════════════════════════════╝

📋 CLUSTER INFORMATION
├─ Kubernetes Version: v1.30.0
├─ Control Plane Endpoint: cicd-k8s-dev-k8s-api-nlb-xxx.elb.eu-west-1.amazonaws.com:6443
├─ CNI Plugin: Flannel
├─ Pod Network: 10.244.0.0/16
└─ Nodes: 3 masters, 2 workers

📦 REPOSITORY HOST
└─ repo: 54.194.123.50 (Docker Registry: http://10.0.1.50:5000)

📚 NEXT STEPS
1. Wait ~15 minutes for cluster initialization
2. SSH to master1 and run: kubectl get nodes
3. All nodes should show "Ready" status
4. Deploy your applications!

═══════════════════════════════════════════════════════════════════════════
EOT

ssh_commands = {
  master1 = "ssh -i wsl-terraform-key.pem ubuntu@54.194.123.45"
  master2 = "ssh -i wsl-terraform-key.pem ubuntu@54.194.123.46"
  master3 = "ssh -i wsl-terraform-key.pem ubuntu@54.194.123.47"
  worker1 = "ssh -i wsl-terraform-key.pem ubuntu@54.194.123.48"
  worker2 = "ssh -i wsl-terraform-key.pem ubuntu@54.194.123.49"
  repo    = "ssh -i wsl-terraform-key.pem ubuntu@54.194.123.50"
}
```

---

## 🔍 Post-Deployment

### Verify Cluster Health

```bash
# SSH to master1
ssh -i wsl-terraform-key.pem ubuntu@<MASTER1_IP>

# Check all nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -A

# Check cluster info
kubectl cluster-info

# Check component status
kubectl get componentstatuses
```

### Expected Cluster State

```bash
# All nodes should be Ready
$ kubectl get nodes
NAME      STATUS   ROLES           AGE   VERSION
master1   Ready    control-plane   10m   v1.30.0
master2   Ready    control-plane   8m    v1.30.0
master3   Ready    control-plane   8m    v1.30.0
worker1   Ready    <none>          6m    v1.30.0
worker2   Ready    <none>          6m    v1.30.0

# All system pods should be Running
$ kubectl get pods -A
NAMESPACE      NAME                              READY   STATUS    RESTARTS   AGE
kube-flannel   kube-flannel-ds-xxxxx             1/1     Running   0          9m
kube-system    coredns-xxxxx                     1/1     Running   0          10m
kube-system    etcd-master1                      1/1     Running   0          10m
kube-system    etcd-master2                      1/1     Running   0          8m
kube-system    etcd-master3                      1/1     Running   0          8m
kube-system    kube-apiserver-master1            1/1     Running   0          10m
kube-system    kube-apiserver-master2            1/1     Running   0          8m
kube-system    kube-apiserver-master3            1/1     Running   0          8m
...
```

### Get Kubeconfig

```bash
# From master node
cat ~/.kube/config

# Or copy to local machine
scp -i wsl-terraform-key.pem ubuntu@<MASTER1_IP>:~/.kube/config ./kubeconfig

# Update server URL to use public IP
sed -i 's/https:\/\/[0-9.]*/https://<MASTER1_PUBLIC_IP>/' kubeconfig

# Use locally
export KUBECONFIG=./kubeconfig
kubectl get nodes
```

### Test Deployment

```bash
# Deploy nginx
kubectl create deployment nginx --image=nginx --replicas=3

# Check pods
kubectl get pods

# Expose service
kubectl expose deployment nginx --port=80 --type=NodePort

# Get service details
kubectl get svc nginx

# Test access
curl http://localhost:<NODEPORT>
```

### Test Docker Registry

```bash
# SSH to repository host
ssh -i wsl-terraform-key.pem ubuntu@<REPO_IP>

# Test registry
docker pull hello-world
docker tag hello-world localhost:5000/hello-world
docker push localhost:5000/hello-world

# List images
curl http://localhost:5000/v2/_catalog
```

---

### Development Setup
```bash
# Clone repository
git clone <repo-url>
cd k8s-cicd

# Create feature branch
git checkout -b feature/your-feature

# Make changes
# Test thoroughly

# Commit and push
git add .
git commit -m "Description of changes"
git push origin feature/your-feature
```

### Code Standards
- Use proper Terraform formatting: `terraform fmt -recursive`
- Validate before committing: `terraform validate`
- Add comments for complex logic
- Update documentation for new features
- Test in dev environment before production

---

## 📚 Additional Resources

### Documentation
- [Kubernetes Official Docs](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [kubeadm HA Setup](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/)
- [Flannel CNI](https://github.com/flannel-io/flannel)

### Related Projects
- [Cluster Autoscaler](https://github.com/kubernetes/autoscaler)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [Kubernetes Dashboard](https://github.com/kubernetes/dashboard)

---

## 📄 License

This project is for educational and demonstration purposes.

---

## 👤 Author

**Mohamed Hesham**
- Project: cicd-k8s
- Environment: dev

---


## 📊 Project Status

**Status:** ✅ **Production Ready**  
**Last Updated:** November 2025  
**Terraform Version:** >= 1.7.0  
**Kubernetes Version:** v1.30.0  
**OS:** Ubuntu 22.04 LTS

---

**🚀 Ready to deploy? Run `terraform apply` and have your cluster in 15 minutes!**