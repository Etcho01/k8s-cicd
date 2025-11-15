# High Availability Kubernetes Cluster on AWS

> **Production-ready Kubernetes v1.30 cluster with 3 control plane nodes, Network Load Balancer, automated node joining, and complete observability stack**
--
## 🎯 Overview

This project provides a complete Infrastructure as Code (IaC) solution for deploying a **production-ready High Availability Kubernetes cluster** on AWS using Terraform. The cluster features:

- **3 Control Plane Nodes** for HA with automatic failover
- **2 Worker Nodes** for workload execution
- **Network Load Balancer** for stable API endpoint
- **Automatic Node Joining** via S3 (no manual intervention)
- **Private Docker Registry** for container images
- **Complete Observability** with Prometheus + Grafana
- **Custom Node Hostnames** (master1-3, worker1-2)

### Why This Solution?

✅ **Production-Ready**: Follows official Kubernetes HA documentation  
✅ **Fully Automated**: Zero manual steps after deployment  
✅ **Complete Monitoring**: Enterprise-grade observability included  
✅ **Battle-Tested**: Uses Ubuntu 22.04 LTS and stable K8s versions  
✅ **Infrastructure as Code**: Version-controlled, repeatable deployments  

---

## 🏗️ Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud (eu-west-1)                    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                        │ │
│  │                                                             │ │
│  │  ┌─────────────────────────────────────────────────────┐  │ │
│  │  │              Network Load Balancer                   │  │ │
│  │  │         (Kubernetes API Endpoint)                    │  │ │
│  │  │    k8s-api-nlb-xxx.elb.eu-west-1.amazonaws.com      │  │ │
│  │  └──────────────────┬──────────────────────────────────┘  │ │
│  │                     │                                      │ │
│  │         ┌───────────┼───────────┬──────────────┐          │ │
│  │         │           │           │              │          │ │
│  │    ┌────▼───┐  ┌───▼────┐  ┌──▼─────┐   ┌───▼────┐     │ │
│  │    │Master1 │  │Master2 │  │Master3 │   │ Worker │     │ │
│  │    │Control │  │Control │  │Control │   │  Nodes │     │ │
│  │    │ Plane  │  │ Plane  │  │ Plane  │   │ (x2)   │     │ │
│  │    └────────┘  └────────┘  └────────┘   └────────┘     │ │
│  │         │                                      │          │ │
│  │         └──────────────────────────────────────┘          │ │
│  │                          │                                │ │
│  │              ┌───────────▼───────────┐                   │ │
│  │              │   Monitoring Stack    │                   │ │
│  │              │  Prometheus + Grafana │                   │ │
│  │              │    Node Exporters     │                   │ │
│  │              └───────────────────────┘                   │ │
│  │                                                           │ │
│  │  ┌────────────┐         ┌─────────────────┐            │ │
│  │  │  Registry  │         │   S3 Bucket     │            │ │
│  │  │   Server   │         │ (Join Commands) │            │ │
│  │  └────────────┘         └─────────────────┘            │ │
│  └──────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

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

### Monitoring Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Monitoring Namespace                      │
│                                                              │
│  ┌──────────────┐      ┌──────────────┐                    │
│  │  Prometheus  │◄─────┤   Exporters  │                    │
│  │   Server     │      │              │                    │
│  │  (Metrics    │      │ - Node       │                    │
│  │   Storage)   │      │ - kube-state │                    │
│  └──────┬───────┘      │ - cAdvisor   │                    │
│         │              └──────────────┘                    │
│         │                                                   │
│         ▼                                                   │
│  ┌──────────────┐                                          │
│  │   Grafana    │ (Visualization)                          │
│  │  Dashboards  │ http://<node-ip>:30300                  │
│  └──────────────┘                                          │
│                                                              │
│  Monitors: All 5 nodes (masters + workers)                 │
│  Retention: 15 days                                         │
│  Metrics: CPU, Memory, Disk, Network, K8s Objects          │
└─────────────────────────────────────────────────────────────┘
```

---

## ✨ Features

### Core Kubernetes Features
- ✅ **High Availability**: 3 control plane nodes with automatic failover
- ✅ **Network Load Balancer**: Stable endpoint for API server (--control-plane-endpoint)
- ✅ **Automatic Node Joining**: S3-based join command distribution
- ✅ **Custom Hostnames**: Nodes named master1-3, worker1-2 (not IPs)
- ✅ **Flannel CNI**: Pod networking with VXLAN overlay
- ✅ **Ubuntu 22.04 LTS**: Long-term support until 2027
- ✅ **Kubernetes 1.30**: Latest stable release

### Monitoring & Observability
- ✅ **Prometheus**: Metrics collection and storage (15-day retention)
- ✅ **Grafana**: Beautiful dashboards and visualization
- ✅ **Node Exporter**: Hardware metrics (CPU, RAM, disk, network)
- ✅ **kube-state-metrics**: Kubernetes object metrics
- ✅ **Pre-configured Dashboards**: Import and use immediately
- ✅ **Automated Installation**: One-script deployment
- ✅ **Real-time Monitoring**: All 5 nodes monitored continuously

### Infrastructure Features
- ✅ **Modular Terraform**: Reusable modules (network, security, ec2, loadbalancer)
- ✅ **S3 State Backend**: Remote state with locking via DynamoDB
- ✅ **Encrypted Storage**: EBS volumes encrypted at rest
- ✅ **IAM Roles**: Instance profiles for secure AWS API access
- ✅ **Security Groups**: Least-privilege network access
- ✅ **Monitoring Ports**: Grafana (30300), Prometheus (30900)
- ✅ **Proper Tagging**: Organized resource management

### Operational Features
- ✅ **Professional Outputs**: Clear SSH commands and cluster info
- ✅ **Private Docker Registry**: Self-hosted container registry
- ✅ **Complete Documentation**: Comprehensive guides and troubleshooting
- ✅ **Automation Scripts**: One-command monitoring installation
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
│   ├── repo_setup.sh                # Docker registry setup
│   ├── install-monitoring.sh        # Monitoring automation (NEW)
│   └── setup-terraform-backend.sh   # S3/DynamoDB creation
│
├── modules/
│   ├── network/                     # VPC, subnets, routing
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── securitygroups/              # Security groups
│   │   ├── main.tf                  # (Updated with monitoring ports)
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
    ├── PROMETHEUS-SETUP.md          # Detailed monitoring guide
    ├── MONITORING-COMMANDS.md       # Monitoring cheat sheet
    └── TROUBLESHOOTING.md          # Common issues and fixes
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
admin_cidr      = "YOUR_PUBLIC_IP/32"  # Get: curl ifconfig.me
monitoring_cidr = "YOUR_PUBLIC_IP/32"  # For Grafana/Prometheus access
```

### 4. Deploy Infrastructure
```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan

# Deploy infrastructure (takes ~15 minutes)
terraform apply
```

### 5. Wait for Cluster Initialization
```bash
# The cluster takes ~15 minutes to fully initialize
# - Minutes 0-2:   Infrastructure creation
# - Minutes 2-10:  Master1 initializes Kubernetes
# - Minutes 10-13: Masters 2-3 join cluster
# - Minutes 13-15: Workers 1-2 join cluster

# Check progress
ssh -i wsl-terraform-key.pem ubuntu@$(terraform output -json master_nodes | jq -r '.[0].public_ip')
kubectl get nodes
```

### 6. Install Monitoring Stack
```bash
# Still on master1, download and run monitoring installer
curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/main/scripts/install-monitoring.sh -o install-monitoring.sh
chmod +x install-monitoring.sh
./install-monitoring.sh

# Or if you have the file locally
./scripts/install-monitoring.sh

# Wait 2-3 minutes for installation
```

### 7. Access Grafana
```bash
# Get node IP from installer output or run:
kubectl get nodes -o wide

# Open browser: http://<node-ip>:30300
# Login: admin / admin123
```

### 8. Import Dashboards
In Grafana:
1. Click **☰** → **Dashboards** → **Import**
2. Enter dashboard ID: **1860** (Node Exporter Full)
3. Click **Load** → **Import**
4. Repeat for IDs: **15760**, **14623**

**🎉 Your cluster with complete monitoring is ready!**

---

## 📊 Monitoring Stack

### What Gets Installed

The monitoring stack includes:

| Component | Purpose | Port | Access |
|-----------|---------|------|--------|
| **Prometheus** | Metrics collection and storage | 30900 | http://node-ip:30900 |
| **Grafana** | Visualization and dashboards | 30300 | http://node-ip:30300 |
| **Node Exporter** | Hardware metrics (5 pods, 1 per node) | 9100 | Internal only |
| **kube-state-metrics** | Kubernetes object metrics | 8080 | Internal only |
| **Alertmanager** | Alert management | 9093 | Internal only |

### Key Metrics Monitored

**Per-Node Metrics:**
- CPU usage (per core and total)
- Memory usage (used, free, cached, buffers)
- Disk I/O (IOPS, throughput, latency)
- Network traffic (bandwidth, packets, errors)
- Disk space usage
- System load averages
- Process counts

**Cluster-Wide Metrics:**
- Total pods running
- Pods per namespace
- Resource usage by namespace
- Failed/Pending pods
- Container restarts
- API server performance
- etcd performance

### Automated Installation

The `install-monitoring.sh` script automates everything:

```bash
# What it does:
✓ Checks cluster health
✓ Installs Helm if needed
✓ Adds Prometheus repository
✓ Creates monitoring namespace
✓ Generates optimized configuration (reduced memory for t3.small)
✓ Installs Prometheus + Grafana + exporters
✓ Waits for pods to be ready
✓ Displays access information

# Optimized for your cluster:
- Memory: 512Mi request, 1Gi limit (fits t3.small instances)
- Storage: emptyDir (no PVC needed)
- Monitoring: All 5 nodes (masters + workers)
- Retention: 15 days of metrics
```

### Recommended Dashboards

| ID | Name | What It Shows |
|----|------|---------------|
| **1860** | Node Exporter Full | Detailed hardware metrics per node |
| **15760** | Kubernetes Cluster | Cluster-wide overview and health |
| **14623** | Kubernetes Pod Resources | Pod-level CPU, memory, network |

### Quick Access

```bash
# Check monitoring pods
kubectl get pods -n monitoring

# View Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Check Prometheus targets
# Open: http://<node-ip>:30900/targets

# Restart Grafana (if needed)
kubectl rollout restart deployment/prometheus-grafana -n monitoring
```

---

## ⚙️ Configuration

### Key Variables (terraform.tfvars)

```hcl
# AWS Configuration
aws_region  = "eu-west-1"
environment = "dev"
owner       = "your-name"

# Network Configuration
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

# Cluster Configuration
master_count = 3
worker_count = 2

# Instance Configuration
instance_type    = "t3.small"       # 2 vCPU, 2GB RAM
root_volume_size = 20               # GB
root_volume_type = "gp3"

# Security
key_name        = "wsl-terraform-key"
admin_cidr      = "YOUR_IP/32"      # For SSH and K8s API
monitoring_cidr = "YOUR_IP/32"      # For Grafana/Prometheus
```

### Security Group Ports

The following ports are automatically configured:

**Kubernetes Cluster:**
- 6443 (API Server)
- 2379-2380 (etcd)
- 10250 (Kubelet)
- 10257 (Controller Manager)
- 10259 (Scheduler)
- 8472 (Flannel VXLAN)
- 30000-32767 (NodePort services)

**Monitoring Stack:**
- 30300 (Grafana UI) - from your IP only
- 30900 (Prometheus UI) - from your IP only
- 9100 (Node Exporter) - internal only
- 9090 (Prometheus) - internal only
- 8080 (kube-state-metrics) - internal only

**Docker Registry:**
- 5000 (Registry HTTPS) - from cluster nodes only

---

## 🎯 Deployment

### Full Deployment Timeline

| Time | Phase | What's Happening |
|------|-------|------------------|
| 0-2 min | Infrastructure | VPC, subnets, NLB, S3, security groups |
| 2-10 min | Master1 | Kubernetes initialization, join commands to S3 |
| 10-13 min | Masters 2-3 | Join cluster as control plane nodes |
| 13-15 min | Workers 1-2 | Join cluster as worker nodes |
| 15+ min | Monitoring | Install Prometheus + Grafana (2-3 min) |

### Deployment Outputs

After `terraform apply`, you'll see:

```
Outputs:

deployment_summary = <<EOT

╔════════════════════════════════════════════════════════════════════════╗
║                  KUBERNETES CLUSTER DEPLOYMENT SUMMARY                  ║
╚════════════════════════════════════════════════════════════════════════╝

📋 CLUSTER INFORMATION
├─ Kubernetes Version: v1.30.0
├─ Control Plane Endpoint: k8s-api-nlb-xxx.elb.eu-west-1.amazonaws.com:6443
├─ CNI Plugin: Flannel
├─ Pod Network: 10.244.0.0/16
└─ Nodes: 3 masters, 2 workers

🖥️  MASTER NODES
├─ master1: 54.194.123.45 (10.0.1.10)
├─ master2: 54.194.123.46 (10.0.1.20)
└─ master3: 54.194.123.47 (10.0.1.30)

👷 WORKER NODES
├─ worker1: 54.194.123.48 (10.0.2.10)
└─ worker2: 54.194.123.49 (10.0.2.20)

📦 REPOSITORY HOST
└─ repo: 54.194.123.50 (Docker Registry: http://10.0.1.50:5000)

📚 NEXT STEPS
1. Wait ~15 minutes for cluster initialization
2. SSH to master1: ssh -i wsl-terraform-key.pem ubuntu@54.194.123.45
3. Verify cluster: kubectl get nodes
4. Install monitoring: ./install-monitoring.sh
5. Access Grafana: http://54.194.123.45:30300

═══════════════════════════════════════════════════════════════════════════
EOT
```

---

## 🔍 Post-Deployment

### Verify Cluster

```bash
# SSH to master1
ssh -i wsl-terraform-key.pem ubuntu@<MASTER1_IP>

# Check nodes (should all be Ready)
kubectl get nodes

# Check system pods (should all be Running)
kubectl get pods -A

# Check cluster info
kubectl cluster-info
```

### Install Monitoring

```bash
# Download and run installer
curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/main/scripts/install-monitoring.sh -o install-monitoring.sh
chmod +x install-monitoring.sh
./install-monitoring.sh

# Or if file is local
./scripts/install-monitoring.sh

# Wait 2-3 minutes for installation
```

### Access Monitoring

```bash
# Get node IP
kubectl get nodes -o wide

# Access in browser:
# Grafana:    http://<node-ip>:30300 (admin/admin123)
# Prometheus: http://<node-ip>:30900

# Import dashboards
# IDs: 1860, 15760, 14623

# Destroy cluster
terraform destroy
```

---

## 🚀 Getting Started Checklist

Before you begin, make sure you have:

- [ ] AWS account with appropriate permissions
- [ ] AWS CLI configured (`aws configure`)
- [ ] Terraform installed (>= 1.7.0)
- [ ] SSH key created in AWS
- [ ] Your public IP noted (`curl ifconfig.me`)
- [ ] Git repository cloned

**Deployment Steps:**

1. [ ] Setup Terraform backend (`./scripts/setup-terraform-backend.sh`)
2. [ ] Configure `terraform.tfvars` with your IP
3. [ ] Run `terraform init`
4. [ ] Run `terraform apply`
5. [ ] Wait ~15 minutes for cluster initialization
6. [ ] SSH to master1 and verify cluster (`kubectl get nodes`)
7. [ ] Run `./install-monitoring.sh` on master1
8. [ ] Access Grafana at `http://<node-ip>:30300`
9. [ ] Import dashboards (1860, 15760, 14623)
10. [ ] Start deploying your applications!

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