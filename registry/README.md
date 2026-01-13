# Local Docker Registry

A local Docker registry for Kubernetes to store container images built by CI/CD pipelines.

## Architecture

- **Service**: `docker-registry` on port 5000
- **Storage**: 50Gi PersistentVolumeClaim
- **Access**: Cluster-internal via `docker-registry.<namespace>.svc.cluster.local:5000`

## Deployment

```bash
# Deploy to dev namespace
kubectl apply -f k8s/registry-pvc.yaml -n calorimeter-dev
kubectl apply -f k8s/registry.yaml -n calorimeter-dev

# Verify
kubectl get pods -n calorimeter-dev -l app=docker-registry
kubectl get svc -n calorimeter-dev docker-registry
```

## Usage

### From CI/CD (port-forward)
```bash
kubectl port-forward -n calorimeter-dev svc/docker-registry 5000:5000 &
docker push localhost:5000/myimage:tag
```

### From Pods (cluster DNS)
```yaml
spec:
  containers:
  - name: myapp
    image: docker-registry.calorimeter-dev.svc.cluster.local:5000/myimage:tag
    imagePullPolicy: Always
```

## Maintenance

### List images
```bash
kubectl port-forward -n calorimeter-dev svc/docker-registry 5000:5000 &
curl http://localhost:5000/v2/_catalog
```

### Delete image
```bash
# Set REGISTRY_STORAGE_DELETE_ENABLED=true (already enabled)
curl -X DELETE http://localhost:5000/v2/<name>/manifests/<digest>
```

### Cleanup unused images
```bash
kubectl exec -n calorimeter-dev deployment/docker-registry -- registry garbage-collect /etc/docker/registry/config.yml
```
