#!/bin/bash

# Build and push the custom GitHub Actions runner images to the local registry.
# docker/Dockerfile defines two targets from a shared `base` stage: `deploy`
# (lean, for build/push/helm jobs) and `e2e` (deploy + Java/Allure + Chromium
# OS deps, for E2E jobs). This script builds and pushes both every time, since
# they share cached layers and the two RunnerDeployments must stay in lockstep
# on the same version tag.
#
# Usage: ./build-runner-image.sh [version]
# Example: ./build-runner-image.sh v1.2.0
#          ./build-runner-image.sh (defaults to latest)

set -e

# Load .env if present
if [ -f "$(dirname "$0")/.env" ]; then
    set -a; source "$(dirname "$0")/.env"; set +a
fi

# Configuration
VERSION="${1:-latest}"
REGISTRY="localhost:5050"
TARGETS=("deploy" "e2e")

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
echo -e "${BLUE}Building GitHub Actions Runner images${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Version: $VERSION"
echo "Targets: ${TARGETS[*]}"
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

for TARGET in "${TARGETS[@]}"; do
    IMAGE_NAME="gh-runner-${TARGET}"
    REGISTRY_IMAGE="$REGISTRY/$IMAGE_NAME"

    echo -e "${BLUE}Building target '$TARGET' -> $IMAGE_NAME:$VERSION ...${NC}"
    docker build \
        --target "$TARGET" \
        -t "$IMAGE_NAME:$VERSION" \
        -t "$IMAGE_NAME:latest" \
        -t "$REGISTRY_IMAGE:$VERSION" \
        -t "$REGISTRY_IMAGE:latest" \
        -f "$PROJECT_ROOT/$DOCKERFILE_PATH" \
        "$PROJECT_ROOT/docker"
    echo -e "${GREEN}✓ Build complete: $IMAGE_NAME:$VERSION${NC}"
    echo ""

    echo -e "${BLUE}Pushing $IMAGE_NAME to local registry ($REGISTRY)...${NC}"
    docker push "$REGISTRY_IMAGE:$VERSION"
    [ "$VERSION" != "latest" ] && docker push "$REGISTRY_IMAGE:latest"
    echo -e "${GREEN}✓ Push complete: $IMAGE_NAME${NC}"
    echo ""
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Build and push completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Images available:"
for TARGET in "${TARGETS[@]}"; do
    echo "  - $REGISTRY/gh-runner-${TARGET}:$VERSION"
done
echo ""
echo "Next steps:"
echo "  1. Bump helm/github-runners/values.yaml tags in oguz-lab-infra to $VERSION"
echo "  2. helm upgrade github-runners oguz-lab-infra/helm/github-runners -n github-runners"
echo "  3. Check status: kubectl get pods -n github-runners"
