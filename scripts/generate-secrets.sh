#!/bin/bash
#
# Generate k8s/secrets.yaml from .env file
# This script reads variables from .env and creates the Kubernetes secrets manifest
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
ENV_FILE="$PROJECT_ROOT/.env"
SECRETS_FILE="$PROJECT_ROOT/k8s/secrets.yaml"

echo -e "${BLUE}=== Generating Kubernetes Secrets from .env ===${NC}\n"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}ERROR: .env file not found${NC}"
    echo ""
    echo "Please create .env file first:"
    echo "  cp .env.example .env"
    echo "  # Edit .env with your values"
    exit 1
fi

# Load environment variables from .env
echo -e "${YELLOW}Loading variables from .env...${NC}"
set -a
source "$ENV_FILE"
set +a

# Validate required variables
if [ -z "$GITHUB_TOKEN" ] || [ "$GITHUB_TOKEN" == "your_github_personal_access_token_here" ]; then
    echo -e "${RED}ERROR: GITHUB_TOKEN is not set or still has default value${NC}"
    exit 1
fi

# Determine scope configuration
SCOPE_CONFIG=""
case "${RUNNER_SCOPE:-repository}" in
    repository)
        if [ -z "$GITHUB_OWNER" ] || [ "$GITHUB_OWNER" == "your-github-username-or-org" ]; then
            echo -e "${RED}ERROR: GITHUB_OWNER is required for repository scope${NC}"
            exit 1
        fi
        if [ -z "$GITHUB_REPOSITORY" ] || [ "$GITHUB_REPOSITORY" == "your-repo-name" ]; then
            echo -e "${RED}ERROR: GITHUB_REPOSITORY is required for repository scope${NC}"
            exit 1
        fi
        SCOPE_CONFIG="  github_owner: \"$GITHUB_OWNER\"
  github_repository: \"$GITHUB_REPOSITORY\""
        FULL_REPO="$GITHUB_OWNER/$GITHUB_REPOSITORY"
        ;;
    organization)
        if [ -z "$GITHUB_ORGANIZATION" ]; then
            echo -e "${RED}ERROR: GITHUB_ORGANIZATION is required for organization scope${NC}"
            exit 1
        fi
        SCOPE_CONFIG="  github_organization: \"$GITHUB_ORGANIZATION\""
        FULL_REPO="organization: $GITHUB_ORGANIZATION"
        ;;
    enterprise)
        if [ -z "$GITHUB_ENTERPRISE" ]; then
            echo -e "${RED}ERROR: GITHUB_ENTERPRISE is required for enterprise scope${NC}"
            exit 1
        fi
        SCOPE_CONFIG="  github_enterprise: \"$GITHUB_ENTERPRISE\""
        FULL_REPO="enterprise: $GITHUB_ENTERPRISE"
        ;;
    *)
        echo -e "${RED}ERROR: Invalid RUNNER_SCOPE: $RUNNER_SCOPE${NC}"
        echo "Valid values: repository, organization, enterprise"
        exit 1
        ;;
esac

# Set default values
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,kubernetes,on-demand}"
RUNNER_GROUP="${RUNNER_GROUP:-}"

echo -e "${GREEN}✓ Configuration validated${NC}"
echo "  Scope: $RUNNER_SCOPE"
echo "  Target: $FULL_REPO"
echo "  Labels: $RUNNER_LABELS"

# Generate secrets.yaml
echo -e "\n${YELLOW}Generating $SECRETS_FILE...${NC}"

cat > "$SECRETS_FILE" << EOF
---
# GitHub Token Secret
# Auto-generated from .env file
# DO NOT commit this file to version control!
# Generated on: $(date)

apiVersion: v1
kind: Secret
metadata:
  name: github-token
  namespace: github-runners
type: Opaque
stringData:
  github_token: "$GITHUB_TOKEN"
---
# ConfigMap for GitHub Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: github-config
  namespace: github-runners
data:
$SCOPE_CONFIG
  
  # Runner labels (space-separated in config, comma-separated in .env)
  runner_labels: "${RUNNER_LABELS//,/ }"
EOF

# Add runner group if specified
if [ -n "$RUNNER_GROUP" ]; then
cat >> "$SECRETS_FILE" << EOF
  
  # Runner group
  runner_group: "$RUNNER_GROUP"
EOF
fi

echo -e "${GREEN}✓ Secrets file generated successfully${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Review the generated file: cat k8s/secrets.yaml"
echo "  2. Apply to cluster: kubectl apply -f k8s/secrets.yaml"
echo "  3. Update runner deployment: scripts/update-runner-deployment.sh"
echo ""
echo -e "${YELLOW}⚠️  Remember: k8s/secrets.yaml contains sensitive data!${NC}"
echo "   Make sure it's listed in .gitignore"
