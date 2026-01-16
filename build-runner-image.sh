#!/bin/bash

# Build custom GitHub Actions runner image with kubectl and buildx
# Usage: ./build-runner-image.sh [version]
# Example: ./build-runner-image.sh v1.0.0
#          ./build-runner-image.sh (defaults to latest)

set -e


# Use current working directory as project root (script must be run from project root)
PROJECT_ROOT="$(pwd)"


# Load Docker Hub config from .env if present (robust parsing)
echo "Loading environment variables from $PROJECT_ROOT/.env (if exists)..."
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo "Loading .env variables..."
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        if [[ "$key" =~ ^#.*$ || -z "$key" ]]; then
            echo "  Skipping line: $key"
            continue
        fi
        key="${key#export }"
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        export "$key=$value"
        echo "  Loaded $key=$value"
    done < "$PROJECT_ROOT/.env"
fi

IMAGE_NAME="gh-runner"
VERSION="${1:-latest}"
DOCKERFILE_PATH="$PROJECT_ROOT/docker/Dockerfile"
LOCAL_REGISTRY="localhost:5000"
LOCAL_IMAGE="$IMAGE_NAME:$VERSION"


# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Building custom GitHub Actions runner image...${NC}"
echo "Image: $IMAGE_NAME:$VERSION"
echo "Dockerfile: $DOCKERFILE_PATH"
echo ""


# Build the image (Docker Hub and GHCR tags)
# Build the image and tag for local registry
docker build \
    -t "$IMAGE_NAME:$VERSION" \
    -t "$IMAGE_NAME:latest" \
    -f "$DOCKERFILE_PATH" \
    "$PROJECT_ROOT/docker"


# Tag as latest if a specific version was provided
# Tag as latest for local registry if a specific version was provided
if [ "$VERSION" != "latest" ]; then
    echo -e "\n${BLUE}Tagging as latest for local registry...${NC}"
    docker tag "$IMAGE_NAME:$VERSION" "$IMAGE_NAME:latest"
fi


echo -e "\n${GREEN}✓ Build complete!${NC}"
echo "Images created:"
docker images "$IMAGE_NAME" --format "  - {{.Repository}}:{{.Tag}} ({{.Size}})"
echo ""
echo ""

# Docker Hub login and push
# Push to local Docker Desktop registry


echo ""
echo "Next steps:"
echo "  1. Test the image: docker run --rm $IMAGE_NAME:latest kubectl version --client"
echo "  2. Deploy runners: envsubst < k8s/arc/runner-deployment.yaml | kubectl apply -f -"
echo "  (Kubernetes in Docker Desktop will use the local image automatically)"
