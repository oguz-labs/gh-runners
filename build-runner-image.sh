#!/bin/bash

# Build custom GitHub Actions runner image with kubectl and buildx
# Usage: ./build-runner-image.sh [version]
# Example: ./build-runner-image.sh v1.0.0
#          ./build-runner-image.sh (defaults to latest)

set -e

# Configuration
LIMA_VM="k3s"
IMAGE_NAME="gh-runner"
VERSION="${1:-latest}"
LOCAL_REGISTRY="localhost:32000"
REGISTRY_IMAGE="$LOCAL_REGISTRY/$IMAGE_NAME"

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
echo -e "${BLUE}Building GitHub Actions Runner for k3s${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Image: $IMAGE_NAME:$VERSION"
echo "Registry: $REGISTRY_IMAGE:$VERSION"
echo "Dockerfile: $DOCKERFILE_PATH"
echo ""

# Check if Lima VM is running
echo -e "${BLUE}Checking Lima VM status...${NC}"
if ! limactl list | grep -q "^${LIMA_VM}.*Running"; then
    echo -e "${RED}Error: Lima VM '${LIMA_VM}' is not running${NC}"
    echo "Start it with: limactl start ${LIMA_VM}"
    exit 1
fi
echo -e "${GREEN}✓ Lima VM is running${NC}"
echo ""

# Ensure BuildKit is running
echo -e "${BLUE}Ensuring BuildKit is running...${NC}"
if [ -f "$PROJECT_ROOT/scripts/ensure-buildkit.sh" ]; then
    bash "$PROJECT_ROOT/scripts/ensure-buildkit.sh" "$LIMA_VM"
else
    echo -e "${YELLOW}Warning: ensure-buildkit.sh not found, skipping BuildKit check${NC}"
fi
echo ""

# Check if registry is accessible
echo -e "${BLUE}Checking registry accessibility...${NC}"
if ! curl -sf http://$LOCAL_REGISTRY/v2/ > /dev/null; then
    echo -e "${YELLOW}Warning: Registry at $LOCAL_REGISTRY is not accessible${NC}"
    echo "Make sure the registry is running in k3s"
    echo "Check with: kubectl get svc -n kube-system registry"
else
    echo -e "${GREEN}✓ Registry is accessible${NC}"
fi
echo ""

# Build image using Lima's Docker socket (if available) or containerd
echo -e "${BLUE}Building image in Lima VM...${NC}"

LIMA_BUILD_DIR="/tmp/gh-runner-build"
TEMP_TAR="/tmp/gh-runner-${VERSION}.tar"

# Copy build context to Lima
limactl shell $LIMA_VM sudo rm -rf $LIMA_BUILD_DIR
limactl shell $LIMA_VM mkdir -p $LIMA_BUILD_DIR
limactl copy "$PROJECT_ROOT/docker/." $LIMA_VM:$LIMA_BUILD_DIR/

# Build with Lima's nerdctl, docker, or buildkit
if limactl shell $LIMA_VM which nerdctl >/dev/null 2>&1; then
    echo -e "${BLUE}Using nerdctl in Lima...${NC}"
    limactl shell $LIMA_VM -- sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io build -t $IMAGE_NAME:$VERSION -f $LIMA_BUILD_DIR/Dockerfile $LIMA_BUILD_DIR
    # No need to save/import - image is already in k3s containerd
    IMAGE_IN_CONTAINERD=true
elif limactl shell $LIMA_VM which docker >/dev/null 2>&1; then
    echo -e "${BLUE}Using Docker in Lima...${NC}"
    limactl shell $LIMA_VM -- bash -c "cd $LIMA_BUILD_DIR && docker build -t $IMAGE_NAME:$VERSION -f Dockerfile ."
    limactl shell $LIMA_VM docker save $IMAGE_NAME:$VERSION -o $TEMP_TAR
    IMAGE_IN_CONTAINERD=false
else
    echo -e "${RED}Error: No container build tool found in Lima VM${NC}"
    echo "Install nerdctl or docker in Lima"
    exit 1
fi

# Import to k3s containerd (only if not already there from nerdctl)
if [ "$IMAGE_IN_CONTAINERD" != "true" ]; then
    echo -e "${BLUE}Importing to k3s containerd...${NC}"
    limactl shell $LIMA_VM sudo k3s ctr images import $TEMP_TAR
else
    echo -e "${GREEN}✓ Image already in k3s containerd${NC}"
fi

# Tag images
echo -e "${BLUE}Tagging images...${NC}"
limactl shell $LIMA_VM sudo k3s ctr images tag docker.io/library/$IMAGE_NAME:$VERSION $REGISTRY_IMAGE:$VERSION || true
limactl shell $LIMA_VM sudo k3s ctr images tag docker.io/library/$IMAGE_NAME:$VERSION $REGISTRY_IMAGE:latest || true
limactl shell $LIMA_VM sudo k3s ctr images tag docker.io/library/$IMAGE_NAME:$VERSION $IMAGE_NAME:latest || true

# Cleanup
if [ "$IMAGE_IN_CONTAINERD" != "true" ]; then
    limactl shell $LIMA_VM rm -f $TEMP_TAR
fi

echo -e "${GREEN}✓ Build and import complete!${NC}"
echo ""

# Verify images
echo -e "${BLUE}Verifying images in k3s...${NC}"
limactl shell $LIMA_VM sudo k3s ctr images ls | grep -E "($IMAGE_NAME|$REGISTRY_IMAGE)"
echo ""

# Verify registry contents
echo -e "${BLUE}Verifying registry contents...${NC}"
curl -s http://$LOCAL_REGISTRY/v2/_catalog | jq '.'
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
echo "  1. Update your deployment to use: $REGISTRY_IMAGE:$VERSION"
echo "  2. Deploy: kubectl apply -f k8s/arc/runner-deployment.yaml"
echo "  3. Check status: kubectl get pods -n github-runners"
echo ""
echo "To test the image:"
echo "  limactl shell $LIMA_VM sudo k3s ctr run --rm $IMAGE_NAME:latest test kubectl version --client"
