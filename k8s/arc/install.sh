# This file has been removed as part of the merge process.
# The original content of install.sh is no longer needed.

# Install Actions Runner Controller (ARC)
# This script installs the official GitHub Actions Runner Controller
# using Helm charts.

# set -e

# echo "=== Installing Actions Runner Controller ==="

# Configuration
# ARC_NAMESPACE="actions-runner-system"
# ARC_RELEASE_NAME="arc"
# ARC_VERSION=""  # Leave empty for latest, or specify version like "0.27.4"

# Additional setup and configuration code has been removed.
#!/bin/bash
#
# Install Actions Runner Controller (ARC)
# This script installs the official GitHub Actions Runner Controller
# using Helm charts.
#

set -e

echo "=== Installing Actions Runner Controller ==="

# Configuration
ARC_NAMESPACE="actions-runner-system"
ARC_RELEASE_NAME="arc"
ARC_VERSION=""  # Leave empty for latest, or specify version like "0.27.4"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}ERROR: kubectl is not installed${NC}"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}ERROR: helm is not installed${NC}"
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}ERROR: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"

# Check if cert-manager is installed
echo -e "\n${YELLOW}Checking for cert-manager...${NC}"
if ! kubectl get namespace cert-manager &> /dev/null; then
    echo -e "${YELLOW}cert-manager not found. Installing cert-manager...${NC}"
    
    # Install cert-manager
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml
    
    # Wait for cert-manager to be ready
    echo -e "${YELLOW}Waiting for cert-manager to be ready...${NC}"
    kubectl wait --for=condition=available --timeout=300s \
      deployment/cert-manager -n cert-manager
    kubectl wait --for=condition=available --timeout=300s \
      deployment/cert-manager-webhook -n cert-manager
    kubectl wait --for=condition=available --timeout=300s \
      deployment/cert-manager-cainjector -n cert-manager
    
    # Additional wait for webhook to be fully operational
    echo -e "${YELLOW}Waiting for cert-manager webhook to be ready...${NC}"
    sleep 30
    
    echo -e "${GREEN}✓ cert-manager installed successfully${NC}"
else
    echo -e "${GREEN}✓ cert-manager already installed${NC}"
    
    # Ensure cert-manager is actually ready
    kubectl wait --for=condition=available --timeout=60s \
      deployment/cert-manager -n cert-manager 2>/dev/null || true
    kubectl wait --for=condition=available --timeout=60s \
      deployment/cert-manager-webhook -n cert-manager 2>/dev/null || true
fi

# Add Actions Runner Controller Helm repository
echo -e "\n${YELLOW}Adding ARC Helm repository...${NC}"
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm repo update

# Create namespace for ARC
echo -e "\n${YELLOW}Creating namespace ${ARC_NAMESPACE}...${NC}"
kubectl create namespace ${ARC_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Install or upgrade ARC
echo -e "\n${YELLOW}Installing Actions Runner Controller...${NC}"

HELM_INSTALL_CMD="helm upgrade --install ${ARC_RELEASE_NAME} \
  actions-runner-controller/actions-runner-controller \
  --namespace ${ARC_NAMESPACE} \
  --timeout 10m \
  --wait"

# Add version if specified
if [ -n "$ARC_VERSION" ]; then
    HELM_INSTALL_CMD="${HELM_INSTALL_CMD} --version ${ARC_VERSION}"
fi

# Execute helm install
if eval $HELM_INSTALL_CMD; then
    echo -e "${GREEN}✓ Actions Runner Controller installed successfully${NC}"
else
    echo -e "${RED}ERROR: Failed to install Actions Runner Controller${NC}"
    exit 1
fi

# Wait for controller to be ready
echo -e "\n${YELLOW}Waiting for controller to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s \
  deployment/arc-controller-manager \
  -n ${ARC_NAMESPACE}

# Display status
echo -e "\n${GREEN}=== Installation Complete ===${NC}"
echo -e "\nController pods:"
kubectl get pods -n ${ARC_NAMESPACE}

echo -e "\n${GREEN}Actions Runner Controller is ready!${NC}"
echo -e "\nNext steps:"
echo -e "1. Configure secrets: cp k8s/secrets.yaml.example k8s/secrets.yaml"
echo -e "2. Edit k8s/secrets.yaml with your GitHub credentials"
echo -e "3. Apply secrets: kubectl apply -f k8s/secrets.yaml"
echo -e "4. Deploy runners: kubectl apply -f k8s/arc/runner-deployment.yaml"
