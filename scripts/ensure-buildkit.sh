#!/bin/bash

# Ensure BuildKit is running in Lima VM
# Usage: ./ensure-buildkit.sh [lima-vm-name]

set -e

LIMA_VM="${1:-k3s}"

echo "Checking BuildKit status in Lima VM: $LIMA_VM..."

# Check if buildkitd is running
if limactl shell $LIMA_VM pgrep -x buildkitd >/dev/null 2>&1; then
    echo "✓ BuildKit is already running"
    exit 0
fi

echo "Starting BuildKit daemon..."

# Kill any stale instances and remove lock
limactl shell $LIMA_VM -- bash -c '
    sudo pkill -9 buildkitd 2>/dev/null || true
    sudo rm -f /var/lib/buildkit/buildkitd.lock
    sudo mkdir -p /run/buildkit
'

# Start buildkitd in background
limactl shell $LIMA_VM -- bash -c '
    sudo nohup /usr/local/bin/buildkitd \
        --oci-worker=false \
        --containerd-worker=true \
        --containerd-worker-addr=/run/k3s/containerd/containerd.sock \
        >/tmp/buildkit.log 2>&1 &
'

# Wait for buildkitd to start
echo "Waiting for BuildKit to start..."
for i in {1..10}; do
    sleep 1
    if limactl shell $LIMA_VM pgrep -x buildkitd >/dev/null 2>&1; then
        echo "✓ BuildKit started successfully"
        exit 0
    fi
done

echo "✗ Failed to start BuildKit"
echo "Check logs with: limactl shell $LIMA_VM cat /tmp/buildkit.log"
exit 1
