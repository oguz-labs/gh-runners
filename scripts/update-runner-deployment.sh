#!/bin/bash
#
# Update runner-deployment.yaml with values from .env
# This script updates the runner deployment configuration based on .env settings

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
RUNNER_DEPLOYMENT="$PROJECT_ROOT/k8s/arc/runner-deployment.yaml"
RUNNER_DEPLOYMENT_BACKUP="$PROJECT_ROOT/k8s/arc/runner-deployment.yaml.bak"

echo -e "${BLUE}=== Updating Runner Deployment from .env ===${NC}\n"

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
SCOPE_YAML=""
SCOPE_DESC=""
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
    SCOPE_YAML="      repository: $GITHUB_OWNER/$GITHUB_REPOSITORY"
    SCOPE_DESC="Repository: $GITHUB_OWNER/$GITHUB_REPOSITORY"
    ;;
  organization)
    if [ -z "$GITHUB_ORGANIZATION" ]; then
      echo -e "${RED}ERROR: GITHUB_ORGANIZATION is required for organization scope${NC}"
      exit 1
    fi
    SCOPE_YAML="      organization: $GITHUB_ORGANIZATION"
    SCOPE_DESC="Organization: $GITHUB_ORGANIZATION"
    ;;
  enterprise)
    if [ -z "$GITHUB_ENTERPRISE" ]; then
      echo -e "${RED}ERROR: GITHUB_ENTERPRISE is required for enterprise scope${NC}"
      exit 1
    fi
    SCOPE_YAML="      enterprise: $GITHUB_ENTERPRISE"
    SCOPE_DESC="Enterprise: $GITHUB_ENTERPRISE"
    ;;
  *)
    echo -e "${RED}ERROR: Invalid RUNNER_SCOPE: $RUNNER_SCOPE${NC}"
    echo "Valid values: repository, organization, enterprise"
    exit 1
    ;;
esac

# Set default values
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,kubernetes,on-demand}"
RUNNER_IMAGE="${RUNNER_IMAGE:-gh-runner:latest}"
MIN_REPLICAS="${MIN_REPLICAS:-0}"
MAX_REPLICAS="${MAX_REPLICAS:-10}"
RUNNER_CPU_REQUEST="${RUNNER_CPU_REQUEST:-1}"
RUNNER_CPU_LIMIT="${RUNNER_CPU_LIMIT:-2}"
RUNNER_MEMORY_REQUEST="${RUNNER_MEMORY_REQUEST:-2Gi}"
RUNNER_MEMORY_LIMIT="${RUNNER_MEMORY_LIMIT:-4Gi}"

echo -e "${GREEN}✓ Configuration validated${NC}"
echo "  $SCOPE_DESC"
echo "  Labels: $RUNNER_LABELS"
echo "  Replicas: $MIN_REPLICAS - $MAX_REPLICAS"
echo "  CPU: $RUNNER_CPU_REQUEST - $RUNNER_CPU_LIMIT"
echo "  Memory: $RUNNER_MEMORY_REQUEST - $RUNNER_MEMORY_LIMIT"

# Backup existing deployment
if [ -f "$RUNNER_DEPLOYMENT" ]; then
  echo -e "\n${YELLOW}Creating backup: $(basename $RUNNER_DEPLOYMENT_BACKUP)${NC}"
  cp "$RUNNER_DEPLOYMENT" "$RUNNER_DEPLOYMENT_BACKUP"
fi

# Convert comma-separated labels to YAML array
IFS=',' read -ra LABEL_ARRAY <<< "$RUNNER_LABELS"
LABELS_YAML=""
for label in "${LABEL_ARRAY[@]}"; do
    LABELS_YAML="${LABELS_YAML}        - $(echo $label | xargs)\n"
done

# Generate runner deployment
echo -e "\n${YELLOW}Generating $RUNNER_DEPLOYMENT...${NC}"

cat > "$RUNNER_DEPLOYMENT" << EOF
---
# RunnerDeployment with Auto-Scaling
# Auto-generated from .env file
# Generated on: $(date)

apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: gh-runner
  namespace: github-runners
spec:
  replicas: 1
  
  template:
    metadata:
      labels:
        app: github-runner
    spec:
      image: $RUNNER_IMAGE
      imagePullPolicy: IfNotPresent
      # Runner scope configuration
$SCOPE_YAML
      
      # Runner labels (used in workflow: runs-on: [self-hosted, ...])
      labels:
$(echo -e "$LABELS_YAML")      
      # Ephemeral runners: each runner handles only one job then terminates
      ephemeral: true
      
      # Service account for runner pods
      serviceAccountName: github-runner
      
      # GitHub token from secret
      env:
        - name: GITHUB_TOKEN
          valueFrom:
            secretKeyRef:
              name: github-token
              key: github_token
      
      # Resource requests and limits
      resources:
        requests:
          cpu: "$RUNNER_CPU_REQUEST"
          memory: "$RUNNER_MEMORY_REQUEST"
        limits:
          cpu: "$RUNNER_CPU_LIMIT"
          memory: "$RUNNER_MEMORY_LIMIT"
      
      # Volume mounts for workspace
      volumeMounts:
        - name: work
          mountPath: /runner/_work
      
      volumes:
        - name: work
          emptyDir: {}
      
      # Security context
      securityContext:
        fsGroup: 1000
          # privileged: true

---
# Horizontal Runner Autoscaler
apiVersion: actions.summerwind.dev/v1alpha1
kind: HorizontalRunnerAutoscaler
metadata:
  name: gh-runner-autoscaler
  namespace: github-runners
spec:
  scaleTargetRef:
    name: gh-runner
  
  minReplicas: $MIN_REPLICAS
  maxReplicas: $MAX_REPLICAS
  
  metrics:
    - type: PercentageRunnersBusy
      scaleUpThreshold: "0.75"
      scaleDownThreshold: "0.25"
      scaleUpFactor: "2"
      scaleDownFactor: "0.5"
  
  scaleDownDelaySecondsAfterScaleOut: 300

EOF

echo -e "${GREEN}✓ Runner deployment updated successfully${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Review the generated file: cat k8s/arc/runner-deployment.yaml"
echo "  2. Apply to cluster: kubectl apply -f k8s/arc/runner-deployment.yaml"
echo ""
echo "To restore backup: cp k8s/arc/runner-deployment.yaml.bak k8s/arc/runner-deployment.yaml"
