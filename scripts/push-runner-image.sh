#!/bin/bash

# Push custom GitHub Actions runner image to GitHub Container Registry
# Usage: ./push-runner-image.sh [version]
# Example: ./push-runner-image.sh v1.0.0
#          ./push-runner-image.sh (defaults to latest)

set -e

# Configuration
REGISTRY_NAMESPACE="registry"
REGISTRY_HOST="localhost:30005"
IMAGE_NAME="$REGISTRY_HOST/gh-runner"
VERSION="${1:-latest}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Pushing GitHub Actions runner image to local registry...${NC}"
echo "Image: $IMAGE_NAME:$VERSION"
echo ""

# Check if image exists locally
if ! docker images "$IMAGE_NAME:$VERSION" --format "{{.Repository}}:{{.Tag}}" | grep -q "$IMAGE_NAME:$VERSION"; then
    echo -e "${YELLOW}Warning: Image $IMAGE_NAME:$VERSION not found locally.${NC}"
    echo "Build it first with: ./scripts/build-runner-image.sh $VERSION"
    exit 1
fi

# Setup port-forward to local registry
echo -e "${BLUE}Setting up port-forward to registry...${NC}"
if ! nc -z localhost 5000 2>/dev/null; then
    echo "Starting port-forward to registry service..."
    kubectl port-forward -n "$REGISTRY_NAMESPACE" svc/docker-registry 5000:5000 &
    PORT_FORWARD_PID=$!
    sleep 3
    
    # Store PID for cleanup
    trap "kill $PORT_FORWARD_PID 2>/dev/null" EXIT
else
    echo "Port 5000 already forwarded or registry accessible"
fi

# Verify registry is accessible
if ! curl -s http://localhost:5000/v2/ > /dev/null; then
    echo -e "${YELLOW}Warning: Registry not accessible at localhost:5000${NC}"
    echo "Make sure the registry is deployed: kubectl get svc -n $REGISTRY_NAMESPACE docker-registry"
    exit 1
fi

# Push the image
echo -e "\n${BLUE}Pushing $IMAGE_NAME:$VERSION...${NC}"
docker push "$IMAGE_NAME:$VERSION"

# Push latest tag if a specific version was provided
if [ "$VERSION" != "latest" ]; then
    echo -e "\n${BLUE}Pushing $IMAGE_NAME:latest...${NC}"
    docker push "$IMAGE_NAME:latest"
fi

echo -e "\n${GREEN}✓ Push complete!${NC}"
echo "Image pushed to local registry"
echo ""
echo "Verify with: curl http://localhost:5000/v2/_catalog"
echo ""
echo "Next steps:"
echo "  1. Update k8s/arc/runner-deployment.yaml to use: docker-registry.$REGISTRY_NAMESPACE.svc.cluster.local:5000/gh-runner:$VERSION"
echo "  2. Apply deployment: kubectl apply -f k8s/arc/runner-deployment.yaml"
