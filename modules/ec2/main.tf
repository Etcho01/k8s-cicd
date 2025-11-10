# EC2 module - Kubernetes cluster instances
# Provisions master nodes, worker nodes, and private repository host

# User data template for Kubernetes master nodes
locals {
  master_user_data = <<-EOF
    #!/bin/bash
    set -eux
    
    # Log all output to file for debugging
    exec > >(tee /var/log/user-data.log)
    exec 2>&1
    
    echo "=== Starting Kubernetes Master Node Setup ==="
    
    # Update system packages
    yum update -y
    
    # Disable swap (required for Kubernetes)
    swapoff -a
    sed -i '/swap/d' /etc/fstab
    
    # Load required kernel modules
    modprobe overlay
    modprobe br_netfilter
    
    # Persist kernel modules on reboot
    cat <<MODULES | tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    MODULES
    
    # Configure kernel parameters for Kubernetes
    cat <<SYSCTL | tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.ipv4.ip_forward                 = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    SYSCTL
    
    # Apply sysctl parameters
    sysctl --system
    
    # Install container runtime prerequisites
    yum install -y yum-utils device-mapper-persistent-data lvm2
    
    # Add Docker CE repository
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # Install containerd
    yum install -y containerd.io
    
    # Configure containerd
    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml
    
    # Configure containerd to use systemd cgroup driver (required for Kubernetes)
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    
    # Enable and start containerd
    systemctl enable --now containerd
    
    # Add Kubernetes repository
    cat <<REPO | tee /etc/yum.repos.d/kubernetes.repo
    [kubernetes]
    name=Kubernetes
    baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
    enabled=1
    gpgcheck=1
    gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
    exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
    REPO
    
    # Install Kubernetes components
    yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    
    # Enable kubelet service
    systemctl enable --now kubelet
    
    # Initialize Kubernetes control plane (only on first master)
    # Pod network CIDR for Flannel: 10.244.0.0/16
    HOSTNAME=$(hostname -f)
    IPADDR=$(hostname -I | awk '{print $1}')
    
    echo "=== Initializing Kubernetes cluster ==="
    kubeadm init \
      --pod-network-cidr=10.244.0.0/16 \
      --apiserver-advertise-address=$IPADDR \
      --node-name=$HOSTNAME
    
    # Configure kubectl for root user
    export KUBECONFIG=/etc/kubernetes/admin.conf
    echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /root/.bashrc
    
    # Configure kubectl for ec2-user
    mkdir -p /home/ec2-user/.kube
    cp /etc/kubernetes/admin.conf /home/ec2-user/.kube/config
    chown -R ec2-user:ec2-user /home/ec2-user/.kube
    
    # Wait for API server to be ready
    echo "=== Waiting for API server ==="
    until kubectl get nodes; do
      echo "Waiting for API server..."
      sleep 5
    done
    
    # Install Flannel pod network
    echo "=== Installing Flannel CNI ==="
    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
    
    # Generate join command and save it
    kubeadm token create --print-join-command > /tmp/kubeadm_join_command.sh
    chmod +x /tmp/kubeadm_join_command.sh
    
    # Save join command to a publicly accessible location (for demo purposes)
    # In production, use AWS Systems Manager Parameter Store or Secrets Manager
    cp /tmp/kubeadm_join_command.sh /home/ec2-user/join_command.sh
    chown ec2-user:ec2-user /home/ec2-user/join_command.sh
    
    echo "=== Kubernetes Master Setup Complete ==="
    EOF

  worker_user_data = <<-EOF
    #!/bin/bash
    set -eux
    
    # Log all output to file for debugging
    exec > >(tee /var/log/user-data.log)
    exec 2>&1
    
    echo "=== Starting Kubernetes Worker Node Setup ==="
    
    # Update system packages
    yum update -y
    
    # Disable swap (required for Kubernetes)
    swapoff -a
    sed -i '/swap/d' /etc/fstab
    
    # Load required kernel modules
    modprobe overlay
    modprobe br_netfilter
    
    # Persist kernel modules on reboot
    cat <<MODULES | tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    MODULES
    
    # Configure kernel parameters for Kubernetes
    cat <<SYSCTL | tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.ipv4.ip_forward                 = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    SYSCTL
    
    # Apply sysctl parameters
    sysctl --system
    
    # Install container runtime prerequisites
    yum install -y yum-utils device-mapper-persistent-data lvm2
    
    # Add Docker CE repository
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # Install containerd
    yum install -y containerd.io
    
    # Configure containerd
    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml
    
    # Configure containerd to use systemd cgroup driver (required for Kubernetes)
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    
    # Enable and start containerd
    systemctl enable --now containerd
    
    # Add Kubernetes repository
    cat <<REPO | tee /etc/yum.repos.d/kubernetes.repo
    [kubernetes]
    name=Kubernetes
    baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
    enabled=1
    gpgcheck=1
    gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
    exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
    REPO
    
    # Install Kubernetes components
    yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    
    # Enable kubelet service
    systemctl enable --now kubelet
    
    # Note: Worker nodes need to join the cluster using the command from master
    # To join: ssh to master1, get the join command, then execute on this worker
    # Example: kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
    
    echo "=== Kubernetes Worker Node Setup Complete ==="
    echo "=== To join cluster, run the join command from master node ==="
    EOF

  repo_user_data = <<-EOF
    #!/bin/bash
    set -eux
    
    # Log all output to file for debugging
    exec > >(tee /var/log/user-data.log)
    exec 2>&1
    
    echo "=== Starting Private Repository Host Setup ==="
    
    # Update system packages
    yum update -y
    
    # Install Docker for hosting container registry
    yum install -y yum-utils device-mapper-persistent-data lvm2
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y docker-ce docker-ce-cli containerd.io
    
    # Start Docker
    systemctl enable --now docker
    
    # Install Docker Registry
    docker run -d \
      -p 5000:5000 \
      --restart=always \
      --name registry \
      -v /mnt/registry:/var/lib/registry \
      registry:2
    
    # Install Git for repository management
    yum install -y git
    
    # Install additional tools
    yum install -y htop vim wget curl
    
    echo "=== Private Repository Host Setup Complete ==="
    echo "=== Docker Registry available at: http://$(hostname -I | awk '{print $1}'):5000 ==="
    EOF
}

# EC2 Instances: Kubernetes Master Nodes
resource "aws_instance" "master" {
  count = var.master_count

  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.public_subnet_ids[count.index % length(var.public_subnet_ids)]
  vpc_security_group_ids = [var.k8s_security_group_id]

  user_data = count.index == 0 ? local.master_user_data : ""

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  monitoring                  = var.enable_detailed_monitoring
  associate_public_ip_address = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-master${count.index + 1}"
      Role = "kubernetes-master"
      Node = "master${count.index + 1}"
    }
  )
}

# EC2 Instances: Kubernetes Worker Nodes
resource "aws_instance" "worker" {
  count = var.worker_count

  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.public_subnet_ids[count.index % length(var.public_subnet_ids)]
  vpc_security_group_ids = [var.k8s_security_group_id]

  user_data = local.worker_user_data

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  monitoring                  = var.enable_detailed_monitoring
  associate_public_ip_address = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-worker${count.index + 1}"
      Role = "kubernetes-worker"
      Node = "worker${count.index + 1}"
    }
  )
}

# EC2 Instance: Private Repository Host
resource "aws_instance" "repo" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.repo_security_group_id]

  user_data = local.repo_user_data

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  monitoring                  = var.enable_detailed_monitoring
  associate_public_ip_address = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-repo"
      Role = "private-repository"
      Node = "repo"
    }
  )
}