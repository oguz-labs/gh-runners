# Container Registry Operations Guide for k3s Environment

This guide explains how to work with the container registry in the k3s on Lima environment. Use this as reference for building, pushing, and pulling container images.

## Environment Overview

- **Container Runtime**: containerd (not Docker daemon)
- **CLI Tool**: nerdctl (Docker-compatible CLI)
- **Build Tool**: BuildKit
- **Registry Location**: `localhost:32000` (accessible from macOS host)
- **Containerd Socket**: `/run/k3s/containerd/containerd.sock`
- **Namespace**: `k8s.io` (k3s uses this namespace for all images)

## Prerequisites

### From macOS Host

All commands must be executed through Lima shell:
```bash
limactl shell k3s -- <command>
```

### Required Tools in Lima VM

- ✅ **nerdctl** v2.2.1 installed at `/usr/local/bin/nerdctl`
- ✅ **buildkitd** v0.12.5 installed at `/usr/local/bin/buildkitd`
- ✅ **k3s ctr** available via `k3s ctr` command

## Building Images

### Method 1: Using nerdctl (Recommended)

Nerdctl integrates directly with k3s containerd:

```bash
# Build an image
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  build -t localhost:32000/myapp:latest /path/to/context

# Build with Dockerfile in different location
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  build -t myapp:v1.0.0 -f /path/to/Dockerfile /path/to/context
```

**Important Notes:**
- Always specify `--address /run/k3s/containerd/containerd.sock`
- Always specify `--namespace k8s.io` (k3s namespace)
- Use `sudo` for root access
- Image is created directly in k3s containerd (no import needed)
- Build context must be accessible inside Lima VM

### Method 2: Using buildctl with BuildKit

First ensure BuildKit is running:

```bash
# Check if BuildKit is running
limactl shell k3s pgrep buildkitd

# Start BuildKit if not running
limactl shell k3s -- sudo /usr/local/bin/buildkitd \
  --oci-worker=false \
  --containerd-worker=true \
  --containerd-worker-addr=/run/k3s/containerd/containerd.sock \
  > /tmp/buildkit.log 2>&1 &
```

Then build:

```bash
limactl shell k3s -- sudo buildctl build \
  --frontend dockerfile.v0 \
  --local context=/path/to/context \
  --local dockerfile=/path/to/dockerfile \
  --output type=image,name=localhost:32000/myapp:latest
```

### Method 3: Using k3s ctr (Import Pre-built Images)

```bash
# Export from another source (if you have docker)
docker save myapp:latest -o myapp.tar

# Copy to Lima
limactl copy myapp.tar k3s:/tmp/

# Import to k3s
limactl shell k3s -- sudo k3s ctr images import /tmp/myapp.tar
```

## Tagging Images

### Using nerdctl

```bash
# Tag an image
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  tag SOURCE_IMAGE:TAG TARGET_IMAGE:TAG

# Example: Tag for registry
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  tag myapp:latest localhost:32000/myapp:latest
```

### Using k3s ctr

```bash
# Tag with k3s ctr
limactl shell k3s -- sudo k3s ctr images tag \
  SOURCE_IMAGE:TAG TARGET_IMAGE:TAG

# Example
limactl shell k3s -- sudo k3s ctr images tag \
  myapp:latest localhost:32000/myapp:v1.0.0
```

## Pushing Images to Registry

### Using nerdctl (Recommended)

```bash
# Push to local registry
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  push --insecure-registry localhost:32000/myapp:latest

# Push with plain HTTP (required for localhost:32000)
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  push --insecure-registry localhost:32000/myapp:latest
```

### Using k3s ctr

**Note:** k3s ctr can push but requires `--plain-http` flag:

```bash
limactl shell k3s -- sudo k3s ctr images push \
  --plain-http \
  localhost:32000/myapp:latest
```

## Pulling Images from Registry

### Using nerdctl

```bash
# Pull from registry
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  pull --insecure-registry localhost:32000/myapp:latest

# Pull from Docker Hub
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  pull alpine:latest
```

### Using k3s ctr

```bash
# Pull from registry
limactl shell k3s -- sudo k3s ctr images pull \
  --plain-http \
  localhost:32000/myapp:latest
```

## Listing Images

### Using nerdctl

```bash
# List all images in k8s.io namespace
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  images

# Filter images
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  images | grep myapp
```

### Using k3s ctr

```bash
# List all images
limactl shell k3s -- sudo k3s ctr images ls

# Filter by name
limactl shell k3s -- sudo k3s ctr images ls | grep myapp

# List images in registry
limactl shell k3s -- sudo k3s ctr images ls | grep localhost:32000
```

## Removing Images

### Using nerdctl

```bash
# Remove image
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  rmi IMAGE:TAG

# Remove multiple images
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  rmi IMAGE1:TAG IMAGE2:TAG

# Force remove
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  rmi -f IMAGE:TAG
```

### Using k3s ctr

```bash
# Remove image
limactl shell k3s -- sudo k3s ctr images rm IMAGE:TAG
```

## Registry API Operations

### Check Registry Health

```bash
# From macOS host
curl http://localhost:32000/v2/

# Expected response: {}
```

### List Repository Catalog

```bash
# List all repositories
curl http://localhost:32000/v2/_catalog

# Example output:
# {"repositories":["myapp","gh-runner","test-alpine"]}
```

### List Image Tags

```bash
# List tags for a repository
curl http://localhost:32000/v2/REPO_NAME/tags/list

# Example:
curl http://localhost:32000/v2/myapp/tags/list
# Output: {"name":"myapp","tags":["latest","v1.0.0"]}
```

### Get Image Manifest

```bash
curl http://localhost:32000/v2/REPO_NAME/manifests/TAG
```

## Common Workflows

### Workflow 1: Build and Push to Registry

```bash
# 1. Ensure build context is in Lima VM
limactl copy ./app-source k3s:/tmp/build-context/

# 2. Build image
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  build -t localhost:32000/myapp:v1.0.0 /tmp/build-context

# 3. Also tag as latest
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  tag localhost:32000/myapp:v1.0.0 localhost:32000/myapp:latest

# 4. Push both tags
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  push --insecure-registry localhost:32000/myapp:v1.0.0

limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  push --insecure-registry localhost:32000/myapp:latest

# 5. Verify in registry
curl http://localhost:32000/v2/myapp/tags/list
```

### Workflow 2: Pull Public Image and Push to Local Registry

```bash
# 1. Pull from Docker Hub
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  pull nginx:alpine

# 2. Tag for local registry
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  tag nginx:alpine localhost:32000/nginx:alpine

# 3. Push to local registry
limactl shell k3s -- sudo nerdctl \
  --address /run/k3s/containerd/containerd.sock \
  --namespace k8s.io \
  push --insecure-registry localhost:32000/nginx:alpine
```

### Workflow 3: Deploy Image from Registry to k3s

```bash
# 1. Create deployment using registry image
kubectl create deployment myapp \
  --image=localhost:32000/myapp:latest

# 2. Or with YAML
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: localhost:32000/myapp:latest
        imagePullPolicy: Always
EOF

# 3. Verify deployment
kubectl get pods
kubectl logs deployment/myapp
```

## Troubleshooting

### BuildKit Not Running

```bash
# Check BuildKit status
limactl shell k3s pgrep buildkitd

# View BuildKit logs
limactl shell k3s cat /tmp/buildkit.log

# Restart BuildKit
limactl shell k3s -- bash -c '
  sudo pkill -9 buildkitd
  sudo rm -f /var/lib/buildkit/buildkitd.lock
  sudo /usr/local/bin/buildkitd \
    --oci-worker=false \
    --containerd-worker=true \
    --containerd-worker-addr=/run/k3s/containerd/containerd.sock \
    > /tmp/buildkit.log 2>&1 &
'
```

### Cannot Connect to Containerd

```bash
# Verify socket exists
limactl shell k3s ls -la /run/k3s/containerd/containerd.sock

# Check k3s status
limactl shell k3s sudo systemctl status k3s

# Restart k3s if needed
limactl shell k3s sudo systemctl restart k3s
```

### Registry Not Accessible

```bash
# Check registry pod
kubectl get pods -n docker-registry

# Check registry service
kubectl get svc -n docker-registry

# Test registry from inside VM
limactl shell k3s curl http://localhost:32000/v2/

# Check port forwarding in Lima config
cat ~/.lima/k3s/lima.yaml | grep -A 5 portForwards
```

### Image Not Found After Build

```bash
# Verify image exists in correct namespace
limactl shell k3s -- sudo k3s ctr -n k8s.io images ls | grep myapp

# Check all namespaces
limactl shell k3s -- sudo k3s ctr namespaces ls
limactl shell k3s -- sudo k3s ctr -n default images ls
```

### Push/Pull Fails

```bash
# Always use --insecure-registry or --plain-http
# Registry is HTTP only (localhost:32000)

# Verify registry configuration in k3s
limactl shell k3s cat /etc/rancher/k3s/registries.yaml

# Should contain:
# mirrors:
#   "localhost:32000":
#     endpoint:
#       - "http://localhost:32000"
```

## Best Practices

1. **Always use k8s.io namespace** - This is where k3s expects all images
2. **Use --insecure-registry flag** - Registry runs on HTTP, not HTTPS
3. **Tag for registry before pushing** - Tag with `localhost:32000/` prefix
4. **Use BuildKit for builds** - More efficient than legacy build
5. **Keep BuildKit running** - Avoids startup delays
6. **Use nerdctl over ctr** - More Docker-like experience
7. **Copy build context to VM first** - Ensures files are accessible
8. **Clean up unused images** - Saves disk space in VM

## Helper Aliases

Add these to your shell profile for convenience:

```bash
# Add to ~/.zshrc or ~/.bashrc
alias lk3s='limactl shell k3s'
alias lnerd='limactl shell k3s -- sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io'
alias lbuild='lnerd build'
alias lpush='lnerd push --insecure-registry'
alias lpull='lnerd pull --insecure-registry'
alias limages='lnerd images'

# Usage examples:
# lbuild -t localhost:32000/myapp:latest /tmp/context
# lpush localhost:32000/myapp:latest
# limages | grep myapp
```

## Reference Links

- **k3s Documentation**: https://docs.k3s.io
- **nerdctl GitHub**: https://github.com/containerd/nerdctl
- **BuildKit Documentation**: https://github.com/moby/buildkit
- **containerd**: https://containerd.io
- **Lima**: https://lima-vm.io

---

*Last Updated: 2026-01-30*
*Environment: k3s v1.34.3 on Lima v2.0.3 (macOS)*
