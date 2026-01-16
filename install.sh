#!/bin/bash

# Merged install.sh: Installs ARC, cert-manager, and prepares runner deployment
set -e

# --- Colors for output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- 1. Prerequisite checks ---
echo -e "\n${YELLOW}Checking prerequisites...${NC}"
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}ERROR: kubectl is not installed${NC}"
    exit 1
fi
if ! command -v helm &> /dev/null; then
    echo -e "${RED}ERROR: helm is not installed${NC}"
    exit 1
fi
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}ERROR: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Prerequisites check passed${NC}"

# --- 2. cert-manager install ---
echo -e "\n${YELLOW}Checking for cert-manager...${NC}"
if ! kubectl get namespace cert-manager &> /dev/null; then
    echo -e "${YELLOW}cert-manager not found. Installing cert-manager...${NC}"
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml
    echo -e "${YELLOW}Waiting for cert-manager to be ready...${NC}"
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
    echo -e "${YELLOW}Waiting for cert-manager webhook to be ready...${NC}"
    sleep 30
    echo -e "${GREEN}✓ cert-manager installed successfully${NC}"
else
    echo -e "${GREEN}✓ cert-manager already installed${NC}"
    kubectl wait --for=condition=available --timeout=60s deployment/cert-manager -n cert-manager 2>/dev/null || true
    kubectl wait --for=condition=available --timeout=60s deployment/cert-manager-webhook -n cert-manager 2>/dev/null || true
fi

# --- 3. ARC install ---
ARC_NAMESPACE="actions-runner-system"
ARC_RELEASE_NAME="arc"
ARC_VERSION=""  # Leave empty for latest

echo -e "\n${YELLOW}Adding ARC Helm repository...${NC}"
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm repo update

echo -e "\n${YELLOW}Creating namespace ${ARC_NAMESPACE}...${NC}"
kubectl create namespace ${ARC_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo -e "\n${YELLOW}Installing Actions Runner Controller...${NC}"
HELM_INSTALL_CMD="helm upgrade --install ${ARC_RELEASE_NAME} actions-runner-controller/actions-runner-controller --namespace ${ARC_NAMESPACE} --timeout 10m --wait"
if [ -n "$ARC_VERSION" ]; then
    HELM_INSTALL_CMD="${HELM_INSTALL_CMD} --version ${ARC_VERSION}"
fi
if eval $HELM_INSTALL_CMD; then
    echo -e "${GREEN}✓ Actions Runner Controller installed successfully${NC}"
else
    echo -e "${RED}ERROR: Failed to install Actions Runner Controller${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Waiting for controller to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/arc-controller-manager -n ${ARC_NAMESPACE}

echo -e "\n${GREEN}=== ARC Installation Complete ===${NC}"

# --- 4. Runner deployment configuration ---
# Prompt for input if not set via environment variables
TARGET_TYPE=${TARGET_TYPE:-}
TARGET_NAME=${TARGET_NAME:-}
MIN_REPLICA_COUNT=${MIN_REPLICA_COUNT:-1}
MAX_REPLICA_COUNT=${MAX_REPLICA_COUNT:-}
GITHUB_TOKEN=${GITHUB_TOKEN:-}
DOCKER_REPOSITORY=${DOCKER_REPOSITORY:-gh-runner:latest}

if [ -z "$TARGET_TYPE" ]; then
  read -rp "Enter target type (project/organisation): " TARGET_TYPE
fi
if [ -z "$TARGET_NAME" ]; then
  read -rp "Enter target name: " TARGET_NAME
fi
if [ "$TARGET_TYPE" = "project" ]; then
  REPOSITORY=${REPOSITORY:-$TARGET_NAME}
  ORGANIZATION=""
elif [ "$TARGET_TYPE" = "organisation" ]; then
  ORGANIZATION=${ORGANIZATION:-$TARGET_NAME}
  REPOSITORY=""
else
  echo "Invalid target type. Use 'project' or 'organisation'." >&2
  exit 1
fi
if [ -z "$MIN_REPLICA_COUNT" ]; then
  read -rp "Enter min replica count [default: 1]: " MIN_REPLICA_COUNT
  MIN_REPLICA_COUNT=${MIN_REPLICA_COUNT:-1}
fi
if [ -z "$MAX_REPLICA_COUNT" ]; then
  read -rp "Enter max replica count (mandatory): " MAX_REPLICA_COUNT
fi
if [ -z "$MAX_REPLICA_COUNT" ]; then
  echo "Error: max replica count is mandatory." >&2
  exit 1
fi
if [ -z "$GITHUB_TOKEN" ]; then
  read -rsp "Enter your GitHub Personal Access Token (GITHUB_TOKEN): " GITHUB_TOKEN
  echo
fi

# --- 5. Namespace and secret for runners ---
if ! kubectl get namespace github-runners >/dev/null 2>&1; then
  echo "Creating namespace github-runners..."
  kubectl create namespace github-runners
else
  echo "Namespace github-runners already exists."
fi

echo "Creating GitHub token secret in Kubernetes..."
kubectl create secret generic github-token \
  --from-literal=github_token="$GITHUB_TOKEN" \
  --namespace=github-runners \
  --dry-run=client -o yaml | kubectl apply -f -

echo "GitHub token secret created in Kubernetes (namespace: github-runners). Token was never written to disk."

# --- 6. Summary and next steps ---
echo -e "\n${GREEN}=== Configuration for Runner Deployment ===${NC}"
echo "  Target type: $TARGET_TYPE"
echo "  Target name: $TARGET_NAME"
if [ -n "$REPOSITORY" ]; then
  echo "  Repository: $REPOSITORY"
fi
if [ -n "$ORGANIZATION" ]; then
  echo "  Organization: $ORGANIZATION"
fi
echo "  Docker repository: $DOCKER_REPOSITORY"
echo "  Min replica count: $MIN_REPLICA_COUNT"
echo "  Max replica count: $MAX_REPLICA_COUNT"
echo "  GitHub token: ${GITHUB_TOKEN:+***hidden***}"

echo -e "\n${GREEN}=== All set! ===${NC}"
echo -e "\nNext steps:"
echo "  1. Build the runner image: ./scripts/build-runner-image.sh"
echo "  2. Deploy runners: envsubst < k8s/arc/runner-deployment.yaml | kubectl apply -f -"
echo "  (Kubernetes in Docker Desktop will use the local image automatically)"
