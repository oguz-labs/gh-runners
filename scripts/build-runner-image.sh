#!/bin/bash

# Build custom GitHub Actions runner image with kubectl and buildx
# Usage: ./build-runner-image.sh [version]
# Example: ./build-runner-image.sh v1.0.0
#          ./build-runner-image.sh (defaults to latest)

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
IMAGE_NAME="gh-runner"
VERSION="${1:-latest}"
DOCKERFILE_PATH="$PROJECT_ROOT/docker/Dockerfile"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Building custom GitHub Actions runner image...${NC}"
echo "Image: $IMAGE_NAME:$VERSION"
echo "Dockerfile: $DOCKERFILE_PATH"
echo ""

# Build the image
docker build \
    -t "$IMAGE_NAME:$VERSION" \
    -f "$DOCKERFILE_PATH" \
    "$PROJECT_ROOT/docker"

# Tag as latest if a specific version was provided
if [ "$VERSION" != "latest" ]; then
    echo -e "\n${BLUE}Tagging as latest...${NC}"
    docker tag "$IMAGE_NAME:$VERSION" "$IMAGE_NAME:latest"
fi

echo -e "\n${GREEN}✓ Build complete!${NC}"
echo "Images created:"
docker images "$IMAGE_NAME" --format "  - {{.Repository}}:{{.Tag}} ({{.Size}})"
echo ""
echo "Image is now available in local Docker cache."
echo "Kubernetes will pull from cache (no registry needed)."
echo ""
echo "Next steps:"
echo "  1. Test the image: docker run --rm $IMAGE_NAME:$VERSION kubectl version --client"
echo "  2. Deploy runners: kubectl apply -f k8s/arc/runner-deployment.yaml"
