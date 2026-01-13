# Using GitHub Container Registry (GHCR)

## Image Naming Convention

All images should be pushed under the `calorimeter_ai` repository namespace:

```
ghcr.io/doguz2509/calorimeter_ai/bot:tag
ghcr.io/doguz2509/calorimeter_ai/backend:tag
ghcr.io/doguz2509/calorimeter_ai/llm:tag
ghcr.io/doguz2509/calorimeter_ai/nginx:tag
```

**NOT** as separate repositories:
```
❌ ghcr.io/doguz2509/calorimeter-bot:tag
❌ ghcr.io/doguz2509/calorimeter-backend:tag
```

## Setup

### 1. Authenticate with GHCR

Your GitHub token is already configured in the runners. For local development:

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u doguz2509 --password-stdin
```

### 2. GitHub Actions Workflow Examples

#### Build and Push Bot Service

```yaml
name: Build and Push Bot
on:
  push:
    paths:
      - 'bot/**'
      - '.github/workflows/bot.yml'

jobs:
  build:
    runs-on: [self-hosted, kubernetes]
    steps:
      - uses: actions/checkout@v4
      
      - name: Login to GHCR
        run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
      
      - name: Build and push bot image
        run: |
          cd bot
          docker build -t ghcr.io/doguz2509/calorimeter_ai/bot:${{ github.sha }} .
          docker build -t ghcr.io/doguz2509/calorimeter_ai/bot:latest .
          docker push ghcr.io/doguz2509/calorimeter_ai/bot:${{ github.sha }}
          docker push ghcr.io/doguz2509/calorimeter_ai/bot:latest
```

#### Build and Push Backend Service

```yaml
name: Build and Push Backend
on:
  push:
    paths:
      - 'backend/**'
      - '.github/workflows/backend.yml'

jobs:
  build:
    runs-on: [self-hosted, kubernetes]
    steps:
      - uses: actions/checkout@v4
      
      - name: Login to GHCR
        run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
      
      - name: Build and push backend image
        run: |
          cd backend
          docker build -t ghcr.io/doguz2509/calorimeter_ai/backend:${{ github.sha }} .
          docker build -t ghcr.io/doguz2509/calorimeter_ai/backend:latest .
          docker push ghcr.io/doguz2509/calorimeter_ai/backend:${{ github.sha }}
          docker push ghcr.io/doguz2509/calorimeter_ai/backend:latest
```

#### Build All Services (Multi-Service)

```yaml
name: Build All Services
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: [self-hosted, kubernetes]
    strategy:
      matrix:
        service: [bot, backend, llm, nginx]
    steps:
      - uses: actions/checkout@v4
      
      - name: Login to GHCR
        run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
      
      - name: Build and push ${{ matrix.service }}
        run: |
          cd ${{ matrix.service }}
          docker build -t ghcr.io/doguz2509/calorimeter_ai/${{ matrix.service }}:${{ github.sha }} .
          docker build -t ghcr.io/doguz2509/calorimeter_ai/${{ matrix.service }}:latest .
          docker push ghcr.io/doguz2509/calorimeter_ai/${{ matrix.service }}:${{ github.sha }}
          docker push ghcr.io/doguz2509/calorimeter_ai/${{ matrix.service }}:latest
```

## Local Development

### Build and Push Locally

```bash
# Authenticate
echo $GITHUB_TOKEN | docker login ghcr.io -u doguz2509 --password-stdin

# Build and push bot
cd bot
docker build -t ghcr.io/doguz2509/calorimeter_ai/bot:latest .
docker push ghcr.io/doguz2509/calorimeter_ai/bot:latest

# Build and push backend
cd backend
docker build -t ghcr.io/doguz2509/calorimeter_ai/backend:latest .
docker push ghcr.io/doguz2509/calorimeter_ai/backend:latest
```

### Pull Images

```bash
# Pull from GHCR
docker pull ghcr.io/doguz2509/calorimeter_ai/bot:latest
docker pull ghcr.io/doguz2509/calorimeter_ai/backend:latest
```

## Kubernetes Deployment

Update your Kubernetes deployments to use the new image paths:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bot
spec:
  template:
    spec:
      containers:
      - name: bot
        image: ghcr.io/doguz2509/calorimeter_ai/bot:latest
        imagePullPolicy: Always
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  template:
    spec:
      containers:
      - name: backend
        image: ghcr.io/doguz2509/calorimeter_ai/backend:latest
        imagePullPolicy: Always
```

## Managing GHCR Images

### List Images

Visit: https://github.com/doguz2509/calorimeter_ai/pkgs/container

Or use the GitHub CLI:

```bash
gh api /user/packages/container/calorimeter_ai%2Fbot/versions
gh api /user/packages/container/calorimeter_ai%2Fbackend/versions
```

### Delete Old Images

```bash
# Delete specific version
gh api -X DELETE /user/packages/container/calorimeter_ai%2Fbot/versions/VERSION_ID
```

### Make Images Public

1. Go to https://github.com/doguz2509?tab=packages
2. Click on the package (e.g., `calorimeter_ai/bot`)
3. Click "Package settings"
4. Scroll to "Danger Zone"
5. Click "Change visibility" → "Public"

## Benefits of This Naming Structure

1. **Organization**: All calorimeter_ai services are grouped together
2. **Discovery**: Easy to find all related images
3. **Permissions**: Single package with multiple sub-images
4. **Clarity**: Clear hierarchy showing service belongs to calorimeter_ai

## Migration from Old Names

If you have images at the root level, you can retag and push them:

```bash
# Pull old image
docker pull ghcr.io/doguz2509/calorimeter-bot:latest

# Retag to new naming convention
docker tag ghcr.io/doguz2509/calorimeter-bot:latest ghcr.io/doguz2509/calorimeter_ai/bot:latest

# Push with new name
docker push ghcr.io/doguz2509/calorimeter_ai/bot:latest

# Optionally, delete old package from GitHub UI
```
