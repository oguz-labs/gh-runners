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


# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Building custom GitHub Actions runner image...${NC}"
echo "Image: $IMAGE_NAME:$VERSION"
echo "Dockerfile: $DOCKERFILE_PATH"
echo ""


# Build the image (Docker Hub and GHCR tags)
docker build \
    -t "$IMAGE_NAME:$VERSION" \
    -t "$GHCR_REPO:$VERSION" \
    -t "$DOCKER_REPO:$VERSION" \
    -f "$DOCKERFILE_PATH" \
    "$PROJECT_ROOT/docker"


# Tag as latest if a specific version was provided
if [ "$VERSION" != "latest" ]; then
    echo -e "\n${BLUE}Tagging as latest...${NC}"
    docker tag "$IMAGE_NAME:$VERSION" "$IMAGE_NAME:latest"
    docker tag "$GHCR_REPO:$VERSION" "$GHCR_REPO:latest"
    docker tag "$DOCKER_REPO:$VERSION" "$DOCKER_REPO:latest"
fi


echo -e "\n${GREEN}✓ Build complete!${NC}"
echo "Images created:"
docker images "$IMAGE_NAME" --format "  - {{.Repository}}:{{.Tag}} ({{.Size}})"
docker images "$GHCR_REPO" --format "  - {{.Repository}}:{{.Tag}} ({{.Size}})"
docker images "$DOCKER_REPO" --format "  - {{.Repository}}:{{.Tag}} ({{.Size}})"
echo ""

# Docker Hub login and push
echo "[DEBUG] DOCKERHUB_USERNAME: $DOCKERHUB_USERNAME"
echo "[DEBUG] DOCKERHUB_TOKEN: ${DOCKERHUB_TOKEN:0:4}... (hidden)"
if [ -n "$DOCKERHUB_USERNAME" ] && [ -n "$DOCKERHUB_TOKEN" ]; then
    echo -e "${BLUE}Logging in to Docker Hub as $DOCKERHUB_USERNAME...${NC}"
    echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
    echo -e "${BLUE}Pushing to Docker Hub: $DOCKER_REPO:$VERSION and $DOCKER_REPO:latest...${NC}"
    docker push "$DOCKER_REPO:$VERSION"
    docker push "$DOCKER_REPO:latest"
else
    echo -e "${BLUE}Docker Hub credentials not set. Skipping push to Docker Hub.${NC}"
fi

echo ""
echo "Next steps:"
echo "  1. Test the image: docker run --rm $IMAGE_NAME:$VERSION kubectl version --client"
echo "  2. Deploy runners: kubectl apply -f k8s/arc/runner-deployment.yaml"
