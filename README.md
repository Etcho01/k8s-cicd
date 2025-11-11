# Kubernetes CI/CD Infrastructure - Phase 1

Production-grade Terraform infrastructure for deploying a Kubernetes 1.30 cluster on AWS with Amazon Linux 2023.

## 📋 Overview

This Terraform project provisions a complete Kubernetes cluster infrastructure including:
- **3 Master nodes** (control plane with HA capability)
- **2 Worker nodes** (compute with automatic cluster joining)
- **1 Private repository host** (Docker Registry + Git)
- Dedicated VPC with public/private subnets
- Security groups with Kubernetes-specific port configurations
- **Automated setup** - Workers join automatically via AWS SSM Parameter Store
- **Amazon Linux 2023** (kernel 6.1) for enhanced security and performance

## 🏗️ Architecture

```
VPC (10.0.0.0/16)
├── Public Subnets (10.0.1.0/24, 10.0.2.0/24)
│   ├── Master Nodes (3x t3.small) - Auto-initialized
│   ├── Worker Nodes (2x t3.small) - Auto-join cluster
│   └── Repository Host (1x t3.small) - Docker Registry
├── Private Subnets (10.0.10.0/24, 10.0.11.0/24)
├── Internet Gateway
└── SSM Parameter Store (for join command)
```

## 📁 Project Structure

```
.
├── main.tf                      # Root module orchestration
├── variables.tf                 # Root module variables
├── outputs.tf                   # Root module outputs
├── provider.tf                  # AWS provider configuration
├── terraform.tf                 # Backend configuration
├── terraform.tfvars             # real variables file not pushed
├── .gitignore                   # Git ignore rules
├── README.md                    # This file
├── scripts/                     # User data scripts
│   ├── master_setup.sh          # Master node initialization
│   ├── worker_setup.sh          # Worker node setup + auto-join
│   ├── repo_setup.sh            # Repository host setup
│   └── setup-terraform-backend.sh # S3 + DynamoDB setup
└── modules/
    ├── network/                 # VPC, subnets, routing
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── securitygroups/          # Security groups
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── ec2/                     # EC2 instances + IAM
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## 🚀 Prerequisites

1. **AWS Account** with appropriate IAM permissions
2. **Terraform** >= 1.7.0 installed
3. **AWS CLI** v2 configured with credentials
4. **SSH Key Pair** named `wsl-terraform-key` in AWS EC2 (eu-west-1)

### Required IAM Permissions

Your AWS user/role needs permissions for:
- EC2 (instances, VPC, security groups)
- S3 (for state backend)
- DynamoDB (for state locking)
- SSM Parameter Store (for join command)
- IAM (for instance profiles)

## 📦 Step-by-Step Deployment

### Step 1: Create SSH Key Pair

```bash
# Create key pair in AWS (if not already exists)
aws ec2 create-key-pair \
  --key-name wsl-terraform-key \
  --region eu-west-1 \
  --query 'KeyMaterial' \
  --output text > wsl-terraform-key.pem

# Set proper permissions
chmod 400 wsl-terraform-key.pem
```

### Step 2: Setup Terraform State Backend (S3 + DynamoDB)

```bash
# Make setup script executable
chmod +x scripts/setup-terraform-backend.sh

# Run the setup script
./scripts/setup-terraform-backend.sh
```

The script will:
- Create S3 bucket with versioning and encryption
- Create DynamoDB table for state locking
- Output the backend configuration
- Save configuration to `terraform-backend-config.txt`

**Example output:**
```
S3 Bucket: cicd-k8s-terraform-state-1699876543
DynamoDB Table: terraform-state-lock
Region: eu-west-1
```

### Step 3: Configure Terraform Backend

Edit `terraform.tf` and uncomment the backend block with your bucket name:

```hcl
terraform {
  backend "s3" {
    bucket         = "cicd-k8s-terraform-state-1699876543"  # Use your bucket name
    key            = "cicd-k8s/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### Step 4: Configure Variables

```bash
# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars
vim terraform.tfvars
```

**REQUIRED: Update these values:**
```hcl
admin_cidr = "YOUR_PUBLIC_IP/32"  # Get your IP: curl ifconfig.me
```

**Verify your IP:**
```bash
curl ifconfig.me
# Example output: 203.0.113.45
# Then set: admin_cidr = "203.0.113.45/32"
```

### Step 5: Initialize Terraform

```bash
# Initialize Terraform and migrate state to S3
terraform init -migrate-state

# Type 'yes' when prompted to migrate state
```

### Step 6: Validate and Plan

```bash
# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# Create execution plan
terraform plan -out=tfplan

# Review the plan carefully
```

### Step 7: Deploy Infrastructure

```bash
# Apply the plan
terraform apply tfplan
```

⏱️ **Deployment time:** Approximately **10-15 minutes**

**What happens during deployment:**
1. VPC and networking created (~2 min)
2. Security groups configured (~1 min)
3. Master node 1 launches and initializes Kubernetes (~8 min)
   - Installs Kubernetes 1.30
   - Initializes control plane
   - Installs Flannel CNI
   - Stores join command in SSM Parameter Store
4. Worker nodes launch and automatically join cluster (~5 min)
   - Retrieve join command from SSM
   - Join the cluster automatically
5. Repository host sets up Docker Registry (~3 min)

## 🎉 Post-Deployment

### Verify Deployment

```bash
# View all outputs
terraform output

# Get specific outputs
terraform output master_public_ips
terraform output worker_public_ips
terraform output kubernetes_cluster_info
```

### Access Master Node

```bash
# SSH to master1 (replace with your master IP)
ssh -i wsl-terraform-key.pem ec2-user@<MASTER1_PUBLIC_IP>

# Check cluster status
kubectl get nodes

# Expected output:
# NAME                          STATUS   ROLES           AGE   VERSION
# ip-10-0-1-x.ec2.internal      Ready    control-plane   10m   v1.30.x
# ip-10-0-1-y.ec2.internal      Ready    <none>          5m    v1.30.x
# ip-10-0-2-z.ec2.internal      Ready    <none>          5m    v1.30.x

# Check all pods
kubectl get pods -A
```

### Verify Automatic Worker Joining

Workers should automatically join within 5 minutes of master initialization:

```bash
# On master node
kubectl get nodes -w  # Watch nodes join in real-time

# Check node details
kubectl describe node <worker-node-name>
```

### Access Repository Host

```bash
# SSH to repository host
ssh -i wsl-terraform-key.pem ec2-user@<REPO_PUBLIC_IP>

# Check Docker Registry
docker ps | grep registry

# Test registry
curl http://localhost:5000/v2/_catalog
```

### Get Kubeconfig (for local kubectl)

```bash
# From master node, copy kubeconfig
ssh -i wsl-terraform-key.pem ec2-user@<MASTER1_IP> "cat ~/.kube/config" > kubeconfig

# Update server URL to use public IP
sed -i 's|https://[0-9.]*:|https://<MASTER1_PUBLIC_IP>:|' kubeconfig

# Use it locally
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

## 🔐 Security Features

### Implemented Security Controls

✅ **Network Security**
- Private VPC with controlled ingress/egress
- Security groups with least-privilege rules
- Admin access restricted to your IP only

✅ **Encryption**
- EBS volumes encrypted at rest
- S3 state bucket encrypted (AES256)
- SSM Parameter Store uses SecureString

✅ **Instance Security**
- IMDSv2 enforced (prevents SSRF attacks)
- No hardcoded credentials
- IAM roles for AWS API access

✅ **Kubernetes Security**
- Flannel CNI with network policies support
- API server secured with TLS
- RBAC enabled by default

### Security Group Ports

#### Kubernetes Cluster SG
| Port Range | Protocol | Purpose | Source |
|------------|----------|---------|--------|
| 22 | TCP | SSH | Your IP only |
| 6443 | TCP | Kubernetes API | Your IP + Cluster |
| 2379-2380 | TCP | etcd | Cluster only |
| 10250 | TCP | Kubelet API | Cluster only |
| 10257 | TCP | kube-controller | Cluster only |
| 10259 | TCP | kube-scheduler | Cluster only |
| 30000-32767 | TCP | NodePort | Cluster only |
| 8472 | UDP | Flannel VXLAN | Cluster only |

#### Repository SG
| Port | Protocol | Purpose | Source |
|------|----------|---------|--------|
| 22 | TCP | SSH | Your IP only |
| 80/443 | TCP | Registry | Cluster only |
| 5000 | TCP | Docker Registry | Cluster only |

## 🔧 Troubleshooting

### Check Deployment Logs

```bash
# SSH to instance
ssh -i wsl-terraform-key.pem ec2-user@<INSTANCE_IP>

# View user-data execution log
sudo cat /var/log/user-data.log

# Check if setup completed
cat ~/SETUP_COMPLETE.txt
```

### Master Node Issues

```bash
# Check kubelet
sudo systemctl status kubelet
sudo journalctl -u kubelet -f

# Check containerd
sudo systemctl status containerd

# Check API server
kubectl cluster-info

# Check control plane pods
kubectl get pods -n kube-system
```

### Worker Node Not Joining

```bash
# On worker node, check user-data log
sudo cat /var/log/user-data.log | grep -i error

# Verify SSM Parameter exists
aws ssm get-parameter \
  --name "/cicd-k8s/k8s-join-command" \
  --region eu-west-1 \
  --with-decryption

# Manually get join command from master
ssh ec2-user@<MASTER_IP> "cat ~/join_command.sh"

# Manually join (if automatic join failed)
sudo $(cat ~/join_command.sh)
```

### Flannel Issues

```bash
# Check Flannel pods
kubectl get pods -n kube-flannel

# View Flannel logs
kubectl logs -n kube-flannel -l app=flannel

# Restart Flannel
kubectl rollout restart daemonset kube-flannel-ds -n kube-flannel
```

### Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Workers not joining | SSM retrieval timeout | Check IAM role permissions, increase retry count |
| Pods stuck in Pending | Flannel not ready | Wait for Flannel DaemonSet to be ready |
| Can't access API | Security group | Verify your IP in admin_cidr |
| SSH connection refused | Wrong key or IP | Verify key name and public IP |

## 📊 Understanding the Setup

### Why Amazon Linux 2023?

- **Latest kernel (6.1)**: Better performance and security
- **Long-term support**: Until 2028
- **SELinux enabled**: Enhanced security
- **Modern packages**: Latest Kubernetes compatible versions
- **Optimized for AWS**: Better EC2 integration

### Why Flannel CNI?

- **Simple setup**: Single kubectl apply
- **VXLAN overlay**: Works across any network
- **Production-ready**: Used by many organizations
- **No external dependencies**: Self-contained

**Note:** Flannel is the CNI (pod networking), not an Ingress Controller. For HTTP/HTTPS ingress, you'll install Nginx Ingress or Traefik in Phase 2.

### Automatic Worker Joining Explained

1. Master node initializes and generates join command
2. Join command stored in AWS SSM Parameter Store (encrypted)
3. Worker nodes poll SSM every 10 seconds (max 10 minutes)
4. Once retrieved, workers execute join command automatically
5. No manual intervention needed! 🎉

## 🔄 Managing Infrastructure

### Update Infrastructure

```bash
# Modify .tf files or scripts
terraform plan
terraform apply
```

### Add More Workers

```bash
# Edit terraform.tfvars
worker_count = 4  # Increase from 2 to 4

# Apply changes
terraform apply
# New workers will auto-join the cluster
```

### Destroy Infrastructure

```bash
# WARNING: This destroys ALL resources
terraform destroy

# Also cleanup backend (if needed)
aws s3 rb s3://<BUCKET_NAME> --force
aws dynamodb delete-table --table-name terraform-state-lock --region eu-west-1
```

## 📚 Technical Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| Terraform | >= 1.7.0 | Infrastructure as Code |
| AWS Provider | ~> 5.0 | AWS resource management |
| Kubernetes | 1.30 | Container orchestration |
| Containerd | Latest | Container runtime |
| Flannel | Latest | CNI (pod networking) |
| Amazon Linux | 2023 (kernel 6.1) | Operating system |
| Docker Registry | 2 | Private container registry |

### Network Configuration

- **VPC CIDR**: 10.0.0.0/16
- **Pod Network CIDR**: 10.244.0.0/16 (Flannel)
- **Service CIDR**: 10.96.0.0/12 (Kubernetes default)

## 🔮 Future Enhancements (Phase 2+)

- [ ] HA Load Balancer for API servers (NLB/ALB)
- [ ] NAT Gateway for private subnet outbound traffic
- [ ] Bastion host for secure jump access
- [ ] CloudWatch logs and metrics
- [ ] Automated TLS certificate management (cert-manager)
- [ ] Ingress controller (Nginx/Traefik)
- [ ] Helm package manager
- [ ] Horizontal Pod Autoscaling
- [ ] Cluster autoscaling
- [ ] EBS CSI driver for persistent volumes
- [ ] Monitoring stack (Prometheus + Grafana)

## 🧪 Testing the Cluster

### Deploy Test Application

```bash
# Create nginx deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Expose as NodePort service
kubectl expose deployment nginx --port=80 --type=NodePort

# Get service details
kubectl get svc nginx

# Access from master node
curl http://localhost:<NODEPORT>
```

### Test Docker Registry

```bash
# On repository host
docker pull hello-world
docker tag hello-world localhost:5000/hello-world
docker push localhost:5000/hello-world

# List registry images
curl http://localhost:5000/v2/_catalog

# From Kubernetes cluster
curl http://<REPO_PRIVATE_IP>:5000/v2/_catalog
```

## 📝 Important Notes

- **Region**: eu-west-1 (Ireland)
- **AMI**: Amazon Linux 2023 (kernel 6.1) - fetched dynamically
- **Instance Type**: t3.small (2 vCPU, 2 GB RAM)
- **State Storage**: S3 + DynamoDB (remote backend)
- **Key File**: wsl-terraform-key.pem (keep secure!)

## 🆘 Getting Help

### Useful Commands

```bash
# Terraform
terraform state list                    # List all resources
terraform state show <resource>         # Show resource details
terraform refresh                       # Sync state with reality

# Kubernetes
kubectl get all -A                      # All resources
kubectl top nodes                       # Node resource usage
kubectl describe node <name>            # Node details
kubectl logs <pod> -n <namespace>       # Pod logs

# AWS
aws ec2 describe-instances --region eu-west-1  # List instances
aws ssm get-parameter --name "/cicd-k8s/k8s-join-command" --with-decryption  # Get join command
```

### Log Locations

- **User data**: `/var/log/user-data.log`
- **Cloud-init**: `/var/log/cloud-init-output.log`
- **Kubelet**: `journalctl -u kubelet`
- **Containerd**: `journalctl -u containerd`

## 📄 License

This project is for educational and demonstration purposes.

## 👤 Author

**Mohamed Hesham**
- Project: cicd-k8s
- Environment: dev
- SSH Key: wsl-terraform-key

## 🤝 Contributing

1. Follow Terraform best practices
2. Test changes in a dev environment
3. Document all modifications
4. Keep scripts idempotent

---

**Last Updated**: November 2025  
**Terraform Version**: >= 1.7.0  
**AWS Provider**: ~> 5.0  
**Kubernetes Version**: 1.30  
**OS**: Amazon Linux 2023 (kernel 6.1)

## ⚡ Quick Reference

```bash
# Complete deployment flow
./scripts/setup-terraform-backend.sh
# Update terraform.tf with bucket name
terraform init -migrate-state
terraform plan -out=tfplan
terraform apply tfplan

# Access cluster
ssh -i wsl-terraform-key.pem ec2-user@<MASTER_IP>
kubectl get nodes

# Cleanup
terraform destroy
```

🎉 **You're ready to deploy!** Follow the steps above for a smooth deployment experience.