# Kubernetes CI/CD Infrastructure - Phase 1

Production-grade Terraform infrastructure for deploying a Kubernetes 1.30 cluster on AWS.

## 📋 Overview

This Terraform project provisions a complete Kubernetes cluster infrastructure including:
- 3 Master nodes (control plane)
- 2 Worker nodes (compute)
- 1 Private repository host
- Dedicated VPC with public/private subnets
- Security groups with Kubernetes-specific port configurations
- Automated Kubernetes 1.30 installation via user-data

## 🏗️ Architecture

```
VPC (10.0.0.0/16)
├── Public Subnets (10.0.1.0/24, 10.0.2.0/24)
│   ├── Master Nodes (3x t3.small)
│   ├── Worker Nodes (2x t3.small)
│   └── Repository Host (1x t3.small)
├── Private Subnets (10.0.10.0/24, 10.0.11.0/24)
└── Internet Gateway
```

## 📁 Project Structure

```
.
├── main.tf                      # Root module orchestration
├── variables.tf                 # Root module variables
├── outputs.tf                   # Root module outputs
├── provider.tf                  # AWS provider configuration
├── terraform.tf                 # Backend configuration
├── terraform.tfvars.example     # Example variables file
├── README.md                    # This file
└── modules/
    ├── network/                 # VPC, subnets, routing
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── securitygroups/          # Security groups
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── ec2/                     # EC2 instances
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## 🚀 Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.7.0 installed
3. **AWS CLI** configured with credentials
4. **SSH Key Pair** created in AWS EC2 (eu-west-1)

### Create SSH Key Pair

```bash
# Create key pair in AWS
aws ec2 create-key-pair \
  --key-name cicd-k8s-key \
  --region eu-west-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/cicd-k8s-key.pem

# Set proper permissions
chmod 400 ~/.ssh/cicd-k8s-key.pem
```

## 📦 Deployment Instructions

### 1. Clone and Configure

```bash
# Navigate to project directory
cd terraform-k8s-infrastructure

# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# REQUIRED: Update key_name and admin_cidr
vim terraform.tfvars
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Validate Configuration

```bash
terraform validate
terraform fmt -recursive
```

### 4. Plan Deployment

```bash
terraform plan -out=tfplan
```

### 5. Apply Infrastructure

```bash
terraform apply tfplan
```

Deployment takes approximately **10-15 minutes**.

## 🔧 Post-Deployment

### Access Master Node

```bash
# Get master1 public IP from outputs
terraform output master_public_ips

# SSH to master1
ssh -i ~/.ssh/cicd-k8s-key.pem ec2-user@<MASTER1_PUBLIC_IP>

# Verify Kubernetes cluster
kubectl get nodes
kubectl get pods -A
```

### Join Worker Nodes

Worker nodes need to join the cluster manually:

```bash
# 1. SSH to master1
ssh -i ~/.ssh/cicd-k8s-key.pem ec2-user@<MASTER1_IP>

# 2. Get join command
cat /home/ec2-user/join_command.sh

# 3. SSH to each worker and run the join command
ssh -i ~/.ssh/cicd-k8s-key.pem ec2-user@<WORKER1_IP>
sudo bash -c "$(cat join_command.sh)"  # Run the join command from master
```

### Verify Cluster

```bash
# On master node
kubectl get nodes
# Should show all masters and workers in Ready state

kubectl get pods -n kube-system
# Should show all system pods running
```

## 🔐 Security Considerations

### Kubernetes Security Group Ports

| Port Range | Protocol | Purpose |
|------------|----------|---------|
| 6443 | TCP | Kubernetes API Server |
| 2379-2380 | TCP | etcd server client API |
| 10250 | TCP | Kubelet API |
| 10257 | TCP | Kube-controller-manager |
| 10259 | TCP | Kube-scheduler |
| 30000-32767 | TCP | NodePort Services |
| 8472 | UDP | Flannel VXLAN |
| 22 | TCP | SSH (from admin_cidr only) |

### Best Practices Implemented

- ✅ Encrypted EBS volumes
- ✅ IMDSv2 enforced on instances
- ✅ Least-privilege security groups
- ✅ Admin SSH access restricted by CIDR
- ✅ Consistent tagging for resource management
- ✅ Modular architecture for maintainability

## 📊 Outputs

After successful deployment, Terraform provides:

```hcl
- VPC ID and subnet IDs
- Security group IDs
- All instance IDs and IP addresses (public/private)
- Kubernetes API endpoint
- SSH connection commands
```

View outputs:
```bash
terraform output
```

## 🔄 Managing Infrastructure

### Update Infrastructure

```bash
# Modify .tf files or terraform.tfvars
terraform plan
terraform apply
```

### Destroy Infrastructure

```bash
# WARNING: This will destroy all resources
terraform destroy
```

## 🐛 Troubleshooting

### Check User Data Logs

```bash
# SSH to instance
ssh -i ~/.ssh/cicd-k8s-key.pem ec2-user@<INSTANCE_IP>

# View user-data execution log
sudo cat /var/log/user-data.log

# Check cloud-init logs
sudo cat /var/log/cloud-init-output.log
```

### Kubernetes Issues

```bash
# Check kubelet status
sudo systemctl status kubelet

# View kubelet logs
sudo journalctl -u kubelet -f

# Check containerd
sudo systemctl status containerd
```

### Common Issues

1. **Worker nodes not joining**: Ensure security groups allow port 6443 between nodes
2. **Pods not starting**: Check Flannel CNI installation: `kubectl get pods -n kube-system`
3. **API server unreachable**: Verify security group allows port 6443 from your IP

## 📚 Kubernetes Version

- **Kubernetes**: 1.30 (stable)
- **Container Runtime**: containerd
- **CNI Plugin**: Flannel (VXLAN)
- **Pod Network CIDR**: 10.244.0.0/16

## 🔮 Future Enhancements (Phase 2+)

- [ ] High Availability with load balancer
- [ ] NAT Gateway for private subnets
- [ ] Bastion host for secure access
- [ ] IAM roles for AWS integrations
- [ ] CloudWatch monitoring and alerting
- [ ] Automated worker node joining
- [ ] Helm installation
- [ ] Ingress controller setup
- [ ] Certificate management

## 📝 Notes

- **Region**: eu-west-1 (Ireland)
- **AMI**: Latest Amazon Linux 2 (fetched dynamically)
- **Instance Type**: t3.small (2 vCPU, 2 GB RAM)
- **State Management**: Local (configure S3 backend in terraform.tf)

## 📄 License

This project is for educational and demonstration purposes.

## 👤 Author

**Mohamed Hesham**
- Project: cicd-k8s
- Environment: dev

## 🤝 Contributing

1. Follow Terraform best practices
2. Test changes in a separate environment
3. Document all modifications
4. Update README with new features

---

**Last Updated**: November 2025
**Terraform Version**: >= 1.7.0
**AWS Provider Version**: ~> 5.0