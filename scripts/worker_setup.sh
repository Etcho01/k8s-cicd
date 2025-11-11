#!/bin/bash
# Kubernetes Worker Node - Ubuntu 22.04 LTS
# Joins cluster as worker

set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== [$(date)] Worker Setup Started ==="

# Variables
S3_BUCKET="${s3_bucket}"
AWS_REGION="${aws_region}"

# Update system
apt-get update
apt-get upgrade -y

# Install prerequisites
apt-get install -y apt-transport-https ca-certificates curl gpg awscli

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Sysctl
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Install containerd
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Add Kubernetes repo
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes
apt-get update
apt-get install -y kubelet=1.30.0-1.1 kubeadm=1.30.0-1.1 kubectl=1.30.0-1.1
apt-mark hold kubelet kubeadm kubectl
systemctl enable --now kubelet

# Wait for master to be ready
echo "Waiting for master..."
RETRY=0
until aws s3 cp s3://$S3_BUCKET/master-ready - --region $AWS_REGION 2>/dev/null | grep -q "ready"; do
  if [ $RETRY -ge 120 ]; then
    echo "ERROR: Master not ready after 20 minutes"
    exit 1
  fi
  echo "Master not ready yet... ($RETRY/120)"
  sleep 10
  RETRY=$((RETRY + 1))
done
echo "✓ Master is ready"

# Download and execute join command
echo "Downloading join command..."
aws s3 cp s3://$S3_BUCKET/worker-join.sh - --region $AWS_REGION > /tmp/join.sh
chmod +x /tmp/join.sh

echo "Joining cluster..."
bash /tmp/join.sh

cat <<EOF > /home/ubuntu/SETUP_COMPLETE.txt
===========================================
Worker Node Joined
===========================================
Joined: $(date)
Role: Worker
===========================================
EOF

chown ubuntu:ubuntu /home/ubuntu/SETUP_COMPLETE.txt

echo "=== [$(date)] Worker Setup Complete ==="