#!/bin/bash
set -e

NAMESPACE="${1:-calorimeter-dev}"

echo "Deploying Docker Registry to namespace: $NAMESPACE"

# Create namespace if it doesn't exist
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Deploy registry (replace namespace in manifests on the fly)
cat k8s/registry-pvc.yaml | sed "s/namespace: registry/namespace: $NAMESPACE/" | kubectl apply -f -
cat k8s/registry.yaml | sed "s/namespace: registry/namespace: $NAMESPACE/" | kubectl apply -f -

# Wait for rollout
echo "Waiting for registry to be ready..."
kubectl rollout status deployment/local-registry -n "$NAMESPACE" --timeout=2m

# Show status
echo ""
echo "Registry deployed successfully!"
kubectl get pods -n "$NAMESPACE" -l app=local-registry
kubectl get svc -n "$NAMESPACE" docker-registry
echo ""
echo "Registry URL: docker-registry.$NAMESPACE.svc.cluster.local:5000"
