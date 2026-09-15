#!/bin/bash

# Build and push custom GitHub Actions runner image to local registry
# Usage: ./build-runner-image.sh [version]
# Example: ./build-runner-image.sh v1.0.0
#          ./build-runner-image.sh (defaults to latest)

set -e

# Load .env if present
if [ -f "$(dirname "$0")/.env" ]; then
    set -a; source "$(dirname "$0")/.env"; set +a
fi

# Configuration
IMAGE_NAME="gh-runner"
VERSION="${1:-latest}"
REGISTRY="localhost:5050"
REGISTRY_IMAGE="$REGISTRY/$IMAGE_NAME"

# Use current working directory as project root
PROJECT_ROOT="$(pwd)"
DOCKERFILE_PATH="docker/Dockerfile"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Building GitHub Actions Runner${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Image: $IMAGE_NAME:$VERSION"
echo "Registry: $REGISTRY_IMAGE:$VERSION"
echo "Dockerfile: $DOCKERFILE_PATH"
echo ""

# Check if Docker is available
echo -e "${BLUE}Checking Docker availability...${NC}"
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running or not available${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker is available${NC}"
echo ""

# Check if registry is accessible
echo -e "${BLUE}Checking registry accessibility...${NC}"
if ! curl -sf http://$REGISTRY/v2/ > /dev/null; then
    echo -e "${YELLOW}Warning: Registry at $REGISTRY is not accessible${NC}"
    echo "Make sure the local-registry is deployed: kubectl get svc -n docker-registry"
else
    echo -e "${GREEN}✓ Registry is accessible at $REGISTRY${NC}"
fi
echo ""

# Build image locally
echo -e "${BLUE}Building image locally...${NC}"
docker build \
    -t "$IMAGE_NAME:$VERSION" \
    -t "$IMAGE_NAME:latest" \
    -t "$REGISTRY_IMAGE:$VERSION" \
    -t "$REGISTRY_IMAGE:latest" \
    -f "$PROJECT_ROOT/$DOCKERFILE_PATH" \
    "$PROJECT_ROOT/docker"
echo -e "${GREEN}✓ Build complete!${NC}"
echo ""

# Push to local registry
echo -e "${BLUE}Pushing to local registry ($REGISTRY)...${NC}"
docker push "$REGISTRY_IMAGE:$VERSION"
[ "$VERSION" != "latest" ] && docker push "$REGISTRY_IMAGE:latest"
echo -e "${GREEN}✓ Push complete!${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Build and push completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Images available:"
echo "  - $REGISTRY_IMAGE:$VERSION"
[ "$VERSION" != "latest" ] && echo "  - $REGISTRY_IMAGE:latest"
echo ""
echo "Next steps:"
echo "  1. Deploy: kubectl apply -f k8s/arc/runner-deployment.yaml"
echo "  2. Check status: kubectl get pods -n github-runners"
