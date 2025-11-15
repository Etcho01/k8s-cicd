#!/bin/bash
# Kubernetes Monitoring Stack - Automated Installation
# Installs Prometheus + Grafana + Node Exporters on Kubernetes cluster
# 
# Usage: ./install-monitoring.sh
# Run this script on master1 after cluster is fully initialized

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║       KUBERNETES MONITORING STACK INSTALLER               ║
║       Prometheus + Grafana + Node Exporter                ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if running on master node
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}ERROR: kubectl not configured. Please run this on master1.${NC}"
    exit 1
fi

echo -e "${BLUE}[1/8]${NC} ${YELLOW}Checking cluster health...${NC}"
READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
TOTAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")

if [ "$READY_NODES" -eq 0 ]; then
    echo -e "${RED}ERROR: No nodes are Ready. Please wait for cluster initialization.${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Cluster health: $READY_NODES/$TOTAL_NODES nodes Ready"

echo ""
echo -e "${BLUE}[2/8]${NC} ${YELLOW}Installing Helm...${NC}"
if command -v helm &> /dev/null; then
    echo -e "${GREEN}✓${NC} Helm already installed ($(helm version --short))"
else
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo -e "${GREEN}✓${NC} Helm installed successfully"
fi

echo ""
echo -e "${BLUE}[3/8]${NC} ${YELLOW}Adding Prometheus Helm repository...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update
echo -e "${GREEN}✓${NC} Repository added and updated"

echo ""
echo -e "${BLUE}[4/8]${NC} ${YELLOW}Checking for existing installation...${NC}"
if helm list -n monitoring 2>/dev/null | grep -q prometheus; then
    echo -e "${YELLOW}⚠${NC}  Existing installation found. Uninstalling..."
    helm uninstall prometheus -n monitoring 2>/dev/null || true
    sleep 5
fi

if kubectl get namespace monitoring &>/dev/null; then
    echo -e "${YELLOW}⚠${NC}  Existing namespace found. Cleaning up..."
    kubectl delete namespace monitoring --timeout=60s 2>/dev/null || true
    sleep 5
fi
echo -e "${GREEN}✓${NC} Environment clean"

echo ""
echo -e "${BLUE}[5/8]${NC} ${YELLOW}Creating monitoring namespace...${NC}"
kubectl create namespace monitoring
echo -e "${GREEN}✓${NC} Namespace created"

echo ""
echo -e "${BLUE}[6/8]${NC} ${YELLOW}Creating Helm values configuration...${NC}"
cat > /tmp/prometheus-values.yaml <<'EOF'
# Prometheus + Grafana Stack Configuration
# Optimized for 5-node cluster with reduced memory footprint

grafana:
  enabled: true
  adminPassword: "admin123"
  
  service:
    type: NodePort
    nodePort: 30300
    port: 80
  
  persistence:
    enabled: false  # No persistence - data in emptyDir
  
  defaultDashboardsEnabled: true
  
  grafana.ini:
    server:
      root_url: "http://localhost:30300"
    analytics:
      check_for_updates: false
    users:
      allow_sign_up: false

prometheus:
  enabled: true
  
  prometheusSpec:
    retention: 15d
    retentionSize: "5GB"
    storageSpec: {}
    
    # Reduced resource requirements for t3.small instances
    resources:
      requests:
        memory: 512Mi
        cpu: 250m
      limits:
        memory: 1Gi
        cpu: 1000m
    
    scrapeInterval: 30s
    evaluationInterval: 30s
  
  service:
    type: NodePort
    nodePort: 30900
    port: 9090

alertmanager:
  enabled: true
  
  alertmanagerSpec:
    storage: {}
    
    resources:
      requests:
        memory: 100Mi
        cpu: 50m
      limits:
        memory: 200Mi
        cpu: 100m

prometheus-node-exporter:
  enabled: true
  # Run on all nodes including masters
  tolerations:
    - effect: NoSchedule
      operator: Exists

kube-state-metrics:
  enabled: true

serviceMonitors:
  enabled: true

podMonitors:
  enabled: true
EOF

echo -e "${GREEN}✓${NC} Configuration file created"

echo ""
echo -e "${BLUE}[7/8]${NC} ${YELLOW}Installing Prometheus stack...${NC}"
echo -e "      ${YELLOW}This will take 2-3 minutes. Please wait...${NC}"

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values /tmp/prometheus-values.yaml \
  --version 58.0.0

echo -e "${GREEN}✓${NC} Helm chart deployed"

echo ""
echo -e "${BLUE}[8/8]${NC} ${YELLOW}Waiting for pods to be ready...${NC}"
echo -e "      ${YELLOW}This may take 2-3 minutes...${NC}"
echo ""

# Wait for pods with progress indicator
SECONDS=0
MAX_WAIT=300
while [ $SECONDS -lt $MAX_WAIT ]; do
    READY_PODS=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    TOTAL_PODS=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | wc -l || echo "0")
    
    if [ "$TOTAL_PODS" -gt 0 ]; then
        echo -ne "\r      Progress: $READY_PODS/$TOTAL_PODS pods Running (${SECONDS}s elapsed)"
        
        # Check if all pods are running (except the one that might be pending)
        PENDING_PODS=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | grep -c "Pending" || echo "0")
        
        if [ "$READY_PODS" -ge 9 ] && [ "$PENDING_PODS" -le 1 ]; then
            echo ""
            break
        fi
    fi
    
    sleep 5
done

echo ""
echo ""

# Final pod status check
echo -e "${YELLOW}Checking final pod status...${NC}"
kubectl get pods -n monitoring

# Check if critical pods are running
GRAFANA_RUNNING=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --no-headers 2>/dev/null | grep -c "Running" || echo "0")
NODE_EXPORTERS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus-node-exporter --no-headers 2>/dev/null | grep -c "Running" || echo "0")

echo ""
if [ "$GRAFANA_RUNNING" -ge 1 ] && [ "$NODE_EXPORTERS" -ge 4 ]; then
    echo -e "${GREEN}✓${NC} Core monitoring components are running"
else
    echo -e "${YELLOW}⚠${NC}  Some pods may still be starting. This is normal."
    echo -e "   Run: ${BLUE}kubectl get pods -n monitoring${NC} to check status"
fi

# Get node IP for access
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null)
if [ -z "$NODE_IP" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
fi

# Summary
echo ""
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              INSTALLATION COMPLETED!                      ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${BLUE}📊 ACCESS INFORMATION${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  ${GREEN}Grafana Dashboard${NC}"
echo -e "  URL:      ${BLUE}http://${NODE_IP}:30300${NC}"
echo -e "  Username: ${YELLOW}admin${NC}"
echo -e "  Password: ${YELLOW}admin123${NC}"
echo ""
echo -e "  ${GREEN}Prometheus UI${NC}"
echo -e "  URL:      ${BLUE}http://${NODE_IP}:30900${NC}"
echo ""

echo -e "${BLUE}📈 RECOMMENDED DASHBOARDS${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  Import these dashboard IDs in Grafana:"
echo -e "  (☰ Menu → Dashboards → Import → Enter ID)"
echo ""
echo -e "  ${YELLOW}1860${NC}  - Node Exporter Full (hardware metrics)"
echo -e "  ${YELLOW}15760${NC} - Kubernetes Cluster Monitoring"
echo -e "  ${YELLOW}14623${NC} - Kubernetes Pod Resources"
echo ""

echo -e "${BLUE}🔍 VERIFICATION COMMANDS${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  Check pods:        ${BLUE}kubectl get pods -n monitoring${NC}"
echo -e "  Check services:    ${BLUE}kubectl get svc -n monitoring${NC}"
echo -e "  View Grafana logs: ${BLUE}kubectl logs -n monitoring -l app.kubernetes.io/name=grafana${NC}"
echo -e "  Check targets:     ${BLUE}Open Prometheus UI → Status → Targets${NC}"
echo ""

echo -e "${BLUE}📚 NEXT STEPS${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  1. Wait 1-2 minutes for all components to stabilize"
echo -e "  2. Open Grafana in your browser: ${BLUE}http://${NODE_IP}:30300${NC}"
echo -e "  3. Login with: ${YELLOW}admin${NC} / ${YELLOW}admin123${NC}"
echo -e "  4. Import dashboards using IDs above"
echo -e "  5. Explore your cluster metrics!"
echo ""

echo -e "${BLUE}💡 TIPS${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  • In Grafana dashboards, use ${YELLOW}Host${NC} dropdown to select specific nodes"
echo -e "  • Prometheus keeps metrics for ${YELLOW}15 days${NC}"
echo -e "  • Data is stored in memory (lost on pod restart)"
echo -e "  • All ${NODE_EXPORTERS} nodes are being monitored"
echo ""

# Create info file
cat > ~/MONITORING_INFO.txt <<INFOEOF
═══════════════════════════════════════════════════════════
        KUBERNETES MONITORING STACK - ACCESS INFO
═══════════════════════════════════════════════════════════

Grafana Dashboard:
  URL:      http://${NODE_IP}:30300
  Username: admin
  Password: admin123

Prometheus UI:
  URL:      http://${NODE_IP}:30900

Recommended Dashboards:
  1860  - Node Exporter Full
  15760 - Kubernetes Cluster Monitoring
  14623 - Kubernetes Pod Resources

Useful Commands:
  kubectl get pods -n monitoring
  kubectl get svc -n monitoring
  kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

Installation Date: $(date)
═══════════════════════════════════════════════════════════
INFOEOF

echo -e "${GREEN}✓${NC} Access information saved to: ${BLUE}~/MONITORING_INFO.txt${NC}"
echo ""
echo -e "${GREEN}🎉 Monitoring stack is ready! Happy monitoring!${NC}"
echo ""