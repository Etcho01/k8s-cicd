#!/bin/bash
# Private Repository Host - Ubuntu 22.04 LTS
# Docker Registry + Git server

set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== [$(date)] Repository Host Setup Started ==="

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start Docker
systemctl enable --now docker

# Run Docker Registry
mkdir -p /mnt/registry
docker run -d \
  -p 5000:5000 \
  --restart=always \
  --name registry \
  -v /mnt/registry:/var/lib/registry \
  registry:2

# Install Git and tools
apt-get install -y git htop vim wget curl tree

# Create git repo directory
mkdir -p /opt/git-repos
chown -R ubuntu:ubuntu /opt/git-repos

# Get instance info
IPADDR=$(hostname -I | awk '{print $1}')

cat <<EOF > /home/ubuntu/SETUP_COMPLETE.txt
===========================================
Repository Host Ready
===========================================
Docker Registry: http://$IPADDR:5000
Git Repos: /opt/git-repos

Test Registry:
  docker pull hello-world
  docker tag hello-world $IPADDR:5000/hello-world
  docker push $IPADDR:5000/hello-world

List Images:
  curl http://$IPADDR:5000/v2/_catalog

Completed: $(date)
===========================================
EOF

chown ubuntu:ubuntu /home/ubuntu/SETUP_COMPLETE.txt

echo "=== [$(date)] Repository Host Setup Complete ==="