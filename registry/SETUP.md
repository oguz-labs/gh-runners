# Local Registry Setup

## Prerequisites - IMPORTANT!

### Configure Docker Desktop for Insecure Registry

The local registry uses HTTP (not HTTPS), so Docker needs to be configured to allow insecure registry access.

**Method 1: Via Docker Desktop UI (Recommended)**
1. Open Docker Desktop
2. Click Settings (gear icon) → Docker Engine
3. Add `10.101.193.164:5000` and `localhost:30005` to insecure registries:
```json
{
  "insecure-registries": [
    "10.101.193.164:5000",
    "localhost:30005"
  ]
}
```
4. Click **Apply & Restart**
5. Wait for Docker to restart (~30 seconds)

**Method 2: For Kubernetes Nodes (if needed)**

For containerd-based Kubernetes:
```bash
# This is already handled if using Docker Desktop
# The registry NodePort (30005) should work once Docker Desktop is configured
```

## Quick Start

### 1. Verify Registry is Running

```bash
kubectl get pods -n registry
kubectl get svc -n registry

# Should show:
# - Pod: local-registry-xxx Running
# - Service: docker-registry NodePort 5000:30005/TCP
```

### 2. Test Registry Access

```bash
# Via NodePort (preferred for push/pull)
curl http://localhost:30005/v2/
# Should return: {}
```

### 3. Configure Kubernetes Nodes for Insecure Registry

Deploy the DaemonSet to configure containerd on all nodes:

```bash
# Apply containerd configuration
kubectl apply -f /Users/dmitryoguz/github/gh_runners_k8s/registry/configure-containerd.yaml

# Verify it's running
kubectl get pods -n kube-system -l app=registry-config

# Check logs
kubectl logs -n kube-system -l app=registry-config -c configure-containerd

# IMPORTANT: Restart Docker Desktop to apply containerd changes
# Via UI: Docker Desktop → Quit, then restart
# Or via command:
osascript -e 'tell application "Docker" to quit' && sleep 5 && open -a Docker
```

### 4. Build and Push Runner Image

```bash
cd /Users/dmitryoguz/github/gh_runners_k8s

# Build the image
./scripts/build-runner-image.sh v1.0.0

# Push to registry (requires port-forward from step 3)
docker push localhost:5000/gh-runner:v1.0.0
docker push localhost:5000/gh-runner:latest

# Verify image in registry
curl http://localhost:5000/v2/_catalog
curl http://localhost:5000/v2/gh-runner/tags/list
```

### 5. Update Runner Deployment

The runner deployment is already configured to use:
```yaml
image: docker-registry.registry.svc.cluster.local:5000/gh-runner:latest
```

Apply the deployment:
```bash
kubectl delete -f k8s/arc/runner-deployment.yaml
kubectl apply -f k8s/arc/runner-deployment.yaml

# Watch runners start (no more init containers!)
kubectl get pods -n github-runners -w
```

## Registry Access Patterns

### From Local Machine (CI/CD, development)
```bash
# Via port-forward
kubectl port-forward -n registry svc/docker-registry 5000:5000 &
docker push localhost:5000/myimage:tag
docker pull localhost:5000/myimage:tag
```

### From Kubernetes Pods
```yaml
image: docker-registry.registry.svc.cluster.local:5000/myimage:tag
```

### Via NodePort (if needed)
```bash
# Registry is exposed on port 30005
docker tag myimage:tag localhost:30005/myimage:tag
docker push localhost:30005/myimage:tag
```

## Maintenance

### List images in registry
```bash
curl http://localhost:5000/v2/_catalog
```

### List tags for an image
```bash
curl http://localhost:5000/v2/gh-runner/tags/list
```

### Storage info
```bash
kubectl exec -n registry deployment/local-registry -- du -sh /var/lib/registry
```

### Clean up unused images
```bash
kubectl exec -n registry deployment/local-registry -- \
  registry garbage-collect /etc/docker/registry/config.yml
```
