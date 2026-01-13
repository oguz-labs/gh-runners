#!/bin/bash
#
# Automated setup script for GitHub Runners on Kubernetes
# This script performs the complete setup process
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  GitHub Actions Runners on Kubernetes - Setup Script      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

# Function to print section headers
print_section() {
    echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"
}

# Function to print errors
print_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

# Function to print warnings
print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Check prerequisites
print_section "Checking prerequisites"

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi
print_success "kubectl found"

if ! command -v helm &> /dev/null; then
    print_error "helm is not installed"
    exit 1
fi
print_success "helm found"

if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi
print_success "Kubernetes cluster connection verified"

# Check if .env file exists
print_section "Checking configuration"

if [ ! -f "$PROJECT_ROOT/.env" ]; then
    print_warning ".env file not found"
    echo ""
    echo "Please create .env from the example:"
    echo "  cp .env.example .env"
    echo ""
    echo "Then edit .env to add:"
    echo "  1. Your GitHub Personal Access Token (GITHUB_TOKEN)"
    echo "  2. Your GitHub repository/organization settings"
    echo "  3. Runner configuration (labels, scope, etc.)"
    echo ""
    read -p "Have you created and configured .env? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Please configure .env first"
        exit 1
    fi
fi
print_success "Configuration file found"

# Generate secrets from .env
print_section "Generating Kubernetes secrets from .env"

if bash "$PROJECT_ROOT/scripts/generate-secrets.sh"; then
    print_success "Secrets generated"
else
    print_error "Failed to generate secrets"
    exit 1
fi

# Step 1: Create namespace
print_section "Step 1: Creating namespace and applying resource quotas"

if kubectl apply -f "$PROJECT_ROOT/k8s/namespace.yaml"; then
    print_success "Namespace created"
else
    print_error "Failed to create namespace"
    exit 1
fi

# Step 2: Apply RBAC
print_section "Step 2: Applying RBAC configuration"

if kubectl apply -f "$PROJECT_ROOT/k8s/rbac.yaml"; then
    print_success "RBAC configuration applied"
else
    print_error "Failed to apply RBAC"
    exit 1
fi

# Step 3: Apply secrets
print_section "Step 3: Creating secrets"

if kubectl apply -f "$PROJECT_ROOT/k8s/secrets.yaml"; then
    print_success "Secrets created"
else
    print_error "Failed to create secrets"
    exit 1
fi

# Step 4: Install Actions Runner Controller
print_section "Step 4: Installing Actions Runner Controller"

if bash "$PROJECT_ROOT/k8s/arc/install.sh"; then
    print_success "Actions Runner Controller installed"
else
    print_error "Failed to install Actions Runner Controller"
    exit 1
fi

# Step 5: Update runner deployment from .env
print_section "Step 5: Updating runner deployment configuration"

if bash "$PROJECT_ROOT/scripts/update-runner-deployment.sh"; then
    print_success "Runner deployment configuration updated"
else
    print_error "Failed to update runner deployment"
    exit 1
fi

# Step 6: Deploy runners
print_section "Step 6: Deploying GitHub runners"

if kubectl apply -f "$PROJECT_ROOT/k8s/arc/runner-deployment.yaml"; then
    print_success "Runner deployment created"
else
    print_error "Failed to deploy runners"
    exit 1
fi

# Final status
print_section "Installation Complete!"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Setup completed successfully!                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"

echo ""
echo "Verify installation:"
echo "  kubectl get pods -n actions-runner-system"
echo "  kubectl get runners -n github-runners"
echo "  kubectl get pods -n github-runners"
echo ""
echo "Check runner status:"
echo "  kubectl get runnerdeployment -n github-runners"
echo "  kubectl get horizontalrunnerautoscaler -n github-runners"
echo ""
echo "View logs:"
echo "  kubectl logs -n actions-runner-system deployment/arc-controller-manager"
echo "  kubectl logs -n github-runners <pod-name>"
echo ""
echo "Next steps:"
echo "  1. Go to your GitHub repository settings"
echo "  2. Navigate to Actions → Runners"
echo "  3. You should see your self-hosted runners listed"
echo "  4. Create a workflow with 'runs-on: self-hosted' to test"
echo ""
print_success "Ready to run GitHub Actions on Kubernetes!"
