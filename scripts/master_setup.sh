#!/bin/bash
# Kubernetes Master Node Setup - Ubuntu 22.04 LTS
# Following official Kubernetes documentation exactly
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== [$(date)] Kubernetes Master Setup Started ==="

# Variables from Terraform
S3_BUCKET="${s3_bucket}"
AWS_REGION="${aws_region}"

# Update system
apt-get update
apt-get upgrade -y

# Install prerequisites
apt-get install -y apt-transport-https ca-certificates curl gpg awscli

# Disable swap (required by Kubernetes)
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Load kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Configure sysctl
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Install containerd (official method)
apt-get install -y containerd

# Configure containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# Enable SystemdCgroup (required for kubelet)
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart containerd
systemctl restart containerd
systemctl enable containerd

# Verify containerd
systemctl status containerd --no-pager

# Add Kubernetes apt repository (official method)
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

# Update apt and install Kubernetes components
apt-get update
apt-get install -y kubelet=1.30.0-1.1 kubeadm=1.30.0-1.1 kubectl=1.30.0-1.1
apt-mark hold kubelet kubeadm kubectl

# Enable kubelet
systemctl enable --now kubelet

# Get instance info
IPADDR=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname -f)

echo "Instance IP: $IPADDR"
echo "Hostname: $HOSTNAME"

# Initialize Kubernetes (official command)
kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=$IPADDR \
  --node-name=$HOSTNAME

# Configure kubectl for root
export KUBECONFIG=/etc/kubernetes/admin.conf
echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /root/.bashrc

# Configure kubectl for ubuntu user
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

# Wait for API server
echo "Waiting for API server..."
until kubectl cluster-info 2>/dev/null; do
  sleep 5
done
echo "✓ API server ready"

# Install Flannel CNI (official method)
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Wait for node to be Ready
echo "Waiting for node to be Ready..."
until kubectl get nodes | grep -v NotReady | grep Ready; do
  sleep 10
done
echo "✓ Node is Ready"

# Generate join commands
echo "Generating join commands..."

# Upload certificates for control-plane nodes
CERT_KEY=$(kubeadm init phase upload-certs --upload-certs 2>&1 | tail -1)

# Worker join command
WORKER_JOIN=$(kubeadm token create --print-join-command)

# Control-plane join command
MASTER_JOIN="$WORKER_JOIN --control-plane --certificate-key $CERT_KEY"

# Save locally
echo "$WORKER_JOIN" > /home/ubuntu/worker-join.sh
echo "$MASTER_JOIN" > /home/ubuntu/master-join.sh
chmod +x /home/ubuntu/worker-join.sh /home/ubuntu/master-join.sh
chown ubuntu:ubuntu /home/ubuntu/*-join.sh

# Upload to S3 (simple and reliable)
echo "Uploading join commands to S3..."
echo "$WORKER_JOIN" | aws s3 cp - s3://$S3_BUCKET/worker-join.sh --region $AWS_REGION
echo "$MASTER_JOIN" | aws s3 cp - s3://$S3_BUCKET/master-join.sh --region $AWS_REGION
echo "ready" | aws s3 cp - s3://$S3_BUCKET/master-ready --region $AWS_REGION

# Verify upload
aws s3 ls s3://$S3_BUCKET/ --region $AWS_REGION

# Final status
kubectl get nodes
kubectl get pods -A

cat <<EOF > /home/ubuntu/SETUP_COMPLETE.txt
===========================================
Kubernetes Master Setup Complete
===========================================
Hostname: $HOSTNAME
IP: $IPADDR
Kubernetes: v1.30.0
CNI: Flannel

Join Commands:
  Worker: ~/worker-join.sh
  Master: ~/master-join.sh

S3 Bucket: $S3_BUCKET

Verify:
  kubectl get nodes
  kubectl get pods -A

Completed: $(date)
===========================================
EOF

chown ubuntu:ubuntu /home/ubuntu/SETUP_COMPLETE.txt

echo "=== [$(date)] Master Setup Complete ==="