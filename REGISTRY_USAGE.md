# Using In-Cluster Docker Registry

## Registry Information

**Registry URL (from within cluster):** `docker-registry.github-runners.svc.cluster.local:5000`
**Registry URL (from localhost via NodePort):** `localhost:30500`

## From GitHub Actions Workflows

The registry is already configured in your runners. Use it in workflows:

### Example 1: Build and Push to Registry

```yaml
name: Build and Deploy
on: [push]

jobs:
  build:
    runs-on: [self-hosted, kubernetes]
    steps:
      - uses: actions/checkout@v4
      
      - name: Build image
        run: |
          docker build -t $REGISTRY_URL/myapp:${{ github.sha }} .
          docker build -t $REGISTRY_URL/myapp:latest .
      
      - name: Push to registry
        run: |
          docker push $REGISTRY_URL/myapp:${{ github.sha }}
          docker push $REGISTRY_URL/myapp:latest
```

### Example 2: Use Image from Registry

```yaml
      - name: Run tests with registry image
        run: |
          docker run $REGISTRY_URL/myapp:latest npm test
```

### Example 3: Deploy to Kubernetes

```yaml
      - name: Deploy to Kubernetes
        run: |
          kubectl set image deployment/myapp \
            myapp=$REGISTRY_URL/myapp:${{ github.sha }} \
            -n my-namespace
```

## From Your Local Machine

### Push image to cluster registry:

```bash
# Build image
docker build -t myapp:latest .

# Tag for cluster registry
docker tag myapp:latest localhost:30500/myapp:latest

# Push to cluster
docker push localhost:30500/myapp:latest
```

### Pull image from cluster registry:

```bash
docker pull localhost:30500/myapp:latest
```

## Registry Management

### View images in registry:

```bash
# List all repositories
curl http://localhost:30500/v2/_catalog

# List tags for a specific image
curl http://localhost:30500/v2/myapp/tags/list
```

### Delete an image:

```bash
# Get digest
DIGEST=$(curl -I -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  http://localhost:30500/v2/myapp/manifests/latest 2>/dev/null | \
  grep Docker-Content-Digest | awk '{print $2}' | tr -d '\r')

# Delete by digest
curl -X DELETE http://localhost:30500/v2/myapp/manifests/$DIGEST
```

### Check registry status:

```bash
kubectl get pods -n github-runners -l app=local-registry
kubectl logs -n github-runners -l app=local-registry
```

## Environment Variables Available in Workflows

- `REGISTRY_URL`: `docker-registry.github-runners.svc.cluster.local:5000`
- `DOCKER_CONFIG_PATH`: `/etc/docker`

## Notes

- Registry is configured as **insecure** (HTTP, not HTTPS) for simplicity
- Storage: 50Gi persistent volume
- Runs on `desktop-worker` node
- Accessible within cluster via service name
- Accessible from localhost via NodePort 30500
