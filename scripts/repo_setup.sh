#!/bin/bash
# Private Docker Registry Setup - Ubuntu 22.04 LTS
# Creates a secure, authenticated Docker registry for your organization

set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== [$(date)] Private Docker Registry Setup Started ==="

# Set hostname
hostnamectl set-hostname registry
echo "127.0.0.1 registry" >> /etc/hosts

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release apache2-utils

# Add Docker's official GPG key
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
systemctl enable docker
systemctl start docker

# Create registry directories
mkdir -p /opt/docker-registry/{data,auth,certs}
cd /opt/docker-registry

# Get the instance's private IP (for internal communication)
PRIVATE_IP=$(hostname -I | awk '{print $1}')
echo "Registry Private IP: ${PRIVATE_IP}"

# Generate self-signed certificate (valid for 10 years)
# In production, you'd use a real certificate from Let's Encrypt or your CA
openssl req -newkey rsa:4096 -nodes -sha256 \
  -keyout certs/registry.key \
  -x509 -days 3650 \
  -out certs/registry.crt \
  -subj "/C=US/ST=State/L=City/O=YourCompany/CN=${PRIVATE_IP}" \
  -addext "subjectAltName=IP:${PRIVATE_IP},DNS:registry"

echo "✓ SSL certificate generated"

# Create registry user credentials
# Default: admin / YourSecurePassword123
# YOU SHOULD CHANGE THIS PASSWORD!
REGISTRY_USER="admin"
REGISTRY_PASS="YourSecurePassword123"

# Generate htpasswd file for basic auth
htpasswd -Bbn ${REGISTRY_USER} ${REGISTRY_PASS} > auth/htpasswd

echo "✓ Authentication configured"
echo "  Username: ${REGISTRY_USER}"
echo "  Password: ${REGISTRY_PASS}"

# Create Docker Compose configuration
cat > docker-compose.yml <<'EOF'
version: '3.8'

services:
  registry:
    image: registry:2
    container_name: docker-registry
    restart: always
    ports:
      - "5000:5000"
    environment:
      REGISTRY_HTTP_TLS_CERTIFICATE: /certs/registry.crt
      REGISTRY_HTTP_TLS_KEY: /certs/registry.key
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: "Registry Realm"
      REGISTRY_STORAGE_DELETE_ENABLED: "true"
    volumes:
      - ./data:/var/lib/registry
      - ./certs:/certs
      - ./auth:/auth
    networks:
      - registry-network

networks:
  registry-network:
    driver: bridge
EOF

# Start the registry
docker compose up -d

# Wait for registry to be ready
echo "Waiting for registry to start..."
sleep 10

# Verify registry is running
if docker compose ps | grep -q "Up"; then
  echo "✓ Docker Registry is running"
else
  echo "✗ Registry failed to start"
  docker compose logs
  exit 1
fi

# Create helper scripts for ubuntu user
cat > /home/ubuntu/registry-info.sh <<EOFINFO
#!/bin/bash
# Docker Registry Information

PRIVATE_IP=\$(hostname -I | awk '{print \$1}')

echo "=========================================="
echo "   Private Docker Registry Information"
echo "=========================================="
echo ""
echo "Registry URL: https://\${PRIVATE_IP}:5000"
echo "Username: admin"
echo "Password: YourSecurePassword123"
echo ""
echo "Management Commands:"
echo "  View logs:        cd /opt/docker-registry && docker compose logs -f"
echo "  Restart:          cd /opt/docker-registry && docker compose restart"
echo "  Stop:             cd /opt/docker-registry && docker compose down"
echo "  Start:            cd /opt/docker-registry && docker compose up -d"
echo ""
echo "Registry Storage: /opt/docker-registry/data"
echo "=========================================="
EOFINFO

chmod +x /home/ubuntu/registry-info.sh
chown ubuntu:ubuntu /home/ubuntu/registry-info.sh

# Create management script
cat > /home/ubuntu/registry-manage.sh <<'EOFMANAGE'
#!/bin/bash
# Registry Management Script

REGISTRY_DIR="/opt/docker-registry"

case "$1" in
  status)
    cd ${REGISTRY_DIR} && docker compose ps
    ;;
  logs)
    cd ${REGISTRY_DIR} && docker compose logs -f
    ;;
  restart)
    cd ${REGISTRY_DIR} && docker compose restart
    echo "Registry restarted"
    ;;
  stop)
    cd ${REGISTRY_DIR} && docker compose down
    echo "Registry stopped"
    ;;
  start)
    cd ${REGISTRY_DIR} && docker compose up -d
    echo "Registry started"
    ;;
  list-images)
    PRIVATE_IP=$(hostname -I | awk '{print $1}')
    curl -k -u admin:YourSecurePassword123 https://${PRIVATE_IP}:5000/v2/_catalog
    ;;
  *)
    echo "Usage: $0 {status|logs|restart|stop|start|list-images}"
    exit 1
    ;;
esac
EOFMANAGE

chmod +x /home/ubuntu/registry-manage.sh
chown ubuntu:ubuntu /home/ubuntu/registry-manage.sh

# Create certificate distribution script
cat > /home/ubuntu/distribute-cert.sh <<'EOFDIST'
#!/bin/bash
# Script to help distribute the registry certificate to cluster nodes

PRIVATE_IP=$(hostname -I | awk '{print $1}')
CERT_FILE="/opt/docker-registry/certs/registry.crt"

echo "=========================================="
echo "  Certificate Distribution Instructions"
echo "=========================================="
echo ""
echo "To allow K8s nodes to trust this registry, run this on EACH node:"
echo ""
echo "sudo mkdir -p /etc/docker/certs.d/${PRIVATE_IP}:5000"
echo "sudo scp ubuntu@${PRIVATE_IP}:${CERT_FILE} /etc/docker/certs.d/${PRIVATE_IP}:5000/ca.crt"
echo "sudo systemctl restart docker"
echo ""
echo "Or use this one-liner (from this registry server):"
echo ""
echo "for NODE in master1 master2 master3 worker1 worker2; do"
echo "  ssh ubuntu@\${NODE} 'sudo mkdir -p /etc/docker/certs.d/${PRIVATE_IP}:5000'"
echo "  scp ${CERT_FILE} ubuntu@\${NODE}:/tmp/ca.crt"
echo "  ssh ubuntu@\${NODE} 'sudo mv /tmp/ca.crt /etc/docker/certs.d/${PRIVATE_IP}:5000/ca.crt && sudo systemctl restart docker'"
echo "done"
echo ""
echo "Certificate location on this server: ${CERT_FILE}"
echo "=========================================="
EOFDIST

chmod +x /home/ubuntu/distribute-cert.sh
chown ubuntu:ubuntu /home/ubuntu/distribute-cert.sh

# Create completion file
cat <<EOFCOMPLETE > /home/ubuntu/SETUP_COMPLETE.txt
===========================================
Private Docker Registry Setup Complete
===========================================
Hostname: registry
Private IP: ${PRIVATE_IP}
Registry URL: https://${PRIVATE_IP}:5000

Credentials:
  Username: admin
  Password: YourSecurePassword123
  
⚠️  IMPORTANT: Change the default password!
   Edit: /opt/docker-registry/auth/htpasswd
   
Storage Location: /opt/docker-registry/data
Certificate: /opt/docker-registry/certs/registry.crt

Helper Scripts:
  ~/registry-info.sh        - Show registry information
  ~/registry-manage.sh      - Manage registry (status/logs/restart)
  ~/distribute-cert.sh      - Help distribute cert to nodes

Quick Start:
  1. View info:      ./registry-info.sh
  2. Check status:   ./registry-manage.sh status
  3. View logs:      ./registry-manage.sh logs
  4. List images:    ./registry-manage.sh list-images

Next Steps:
  1. Distribute certificate to K8s nodes
  2. Test push/pull from nodes
  3. Create K8s secret for registry auth

Completed: $(date)
===========================================
EOFCOMPLETE

chown ubuntu:ubuntu /home/ubuntu/SETUP_COMPLETE.txt

# Display info
cat /home/ubuntu/SETUP_COMPLETE.txt

echo "=== [$(date)] Registry Setup Complete ==="