#!/bin/bash
# Kubernetes Master Node Setup - Ubuntu 22.04 LTS
# Following official Kubernetes documentation for HA setup

set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== [$(date)] Kubernetes Master Setup Started ==="

# Variables from Terraform
S3_BUCKET="${s3_bucket}"
AWS_REGION="${aws_region}"
CONTROL_PLANE_ENDPOINT="${control_plane_endpoint}"

echo "S3 Bucket: $${S3_BUCKET}"
echo "AWS Region: $${AWS_REGION}"
echo "Control Plane Endpoint: $${CONTROL_PLANE_ENDPOINT}"

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

# Install containerd
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd
systemctl status containerd --no-pager

# Add Kubernetes apt repository
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes components
apt-get update
apt-get install -y kubelet=1.30.0-1.1 kubeadm=1.30.0-1.1 kubectl=1.30.0-1.1
apt-mark hold kubelet kubeadm kubectl
systemctl enable --now kubelet

# Get instance info
IPADDR=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname -f)

echo "Instance IP: $${IPADDR}"
echo "Hostname: $${HOSTNAME}"

# Initialize Kubernetes with NLB DNS as control-plane-endpoint (enables HA)
echo "=== Initializing Kubernetes cluster with HA support ==="
kubeadm init \
  --control-plane-endpoint="$${CONTROL_PLANE_ENDPOINT}" \
  --upload-certs \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=$${IPADDR} \
  --node-name=$${HOSTNAME}

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

# Install Flannel CNI
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Wait for node to be Ready
echo "Waiting for node to be Ready..."
until kubectl get nodes | grep -v NotReady | grep Ready; do
  sleep 10
done
echo "✓ Node is Ready"

# Generate join commands
echo "=== Generating join commands ==="

# Upload certificates and get the key (FIXED: use tail -1)
CERT_KEY=$(kubeadm init phase upload-certs --upload-certs 2>&1 | tail -1)
echo "Certificate key: $${CERT_KEY}"

# Validate certificate key (should be 64 hex characters)
if [ -z "$${CERT_KEY}" ] || [ "$${CERT_KEY}" == "key:" ] || [ $${#CERT_KEY} -lt 32 ]; then
  echo "ERROR: Invalid certificate key: '$${CERT_KEY}'"
  exit 1
fi

# Generate worker join command
WORKER_JOIN=$(kubeadm token create --print-join-command)
echo "Original worker join: $${WORKER_JOIN}"

# CRITICAL: Replace IP:PORT with NLB DNS:PORT
# This ensures all nodes join through the load balancer
WORKER_JOIN_NLB=$(echo "$${WORKER_JOIN}" | sed -E "s/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+/$${CONTROL_PLANE_ENDPOINT}/")
echo "Worker join (via NLB): $${WORKER_JOIN_NLB}"

# Generate master join command (with NLB DNS)
MASTER_JOIN_NLB="$${WORKER_JOIN_NLB} --control-plane --certificate-key $${CERT_KEY}"
echo "Master join (via NLB): $${MASTER_JOIN_NLB}"

# Save locally
echo "$${WORKER_JOIN_NLB}" > /home/ubuntu/worker-join.sh
echo "$${MASTER_JOIN_NLB}" > /home/ubuntu/master-join.sh
chmod +x /home/ubuntu/worker-join.sh /home/ubuntu/master-join.sh
chown ubuntu:ubuntu /home/ubuntu/worker-join.sh /home/ubuntu/master-join.sh

# Upload to S3 with proper content
echo "Uploading join commands to S3..."
echo "$${WORKER_JOIN_NLB}" | aws s3 cp - s3://$${S3_BUCKET}/worker-join.sh --region $${AWS_REGION}
echo "$${MASTER_JOIN_NLB}" | aws s3 cp - s3://$${S3_BUCKET}/master-join.sh --region $${AWS_REGION}
echo "ready" | aws s3 cp - s3://$${S3_BUCKET}/master-ready --region $${AWS_REGION}

# Verify S3 uploads
echo "=== Verifying S3 uploads ==="
aws s3 ls s3://$${S3_BUCKET}/ --region $${AWS_REGION}

echo "=== Verifying join command content in S3 ==="
echo "Worker join command:"
aws s3 cp s3://$${S3_BUCKET}/worker-join.sh - --region $${AWS_REGION}
echo ""
echo "Master join command:"
aws s3 cp s3://$${S3_BUCKET}/master-join.sh - --region $${AWS_REGION}

# Display cluster status
echo "=== Cluster Status ==="
kubectl get nodes -o wide
kubectl get pods -A

# Completion file
cat <<EOFCOMPLETE > /home/ubuntu/SETUP_COMPLETE.txt
===========================================
Kubernetes Master Node Setup Complete
===========================================
Hostname: $${HOSTNAME}
IP: $${IPADDR}
Control Plane Endpoint: $${CONTROL_PLANE_ENDPOINT}
Kubernetes: v1.30.0
CNI: Flannel

Join Commands Uploaded to S3:
  Worker: s3://$${S3_BUCKET}/worker-join.sh
  Master: s3://$${S3_BUCKET}/master-join.sh

Local Join Commands:
  Worker: ~/worker-join.sh
  Master: ~/master-join.sh

Completed: $(date)
===========================================
EOFCOMPLETE

chown ubuntu:ubuntu /home/ubuntu/SETUP_COMPLETE.txt

echo "=== [$(date)] Master setup completed successfully ==="