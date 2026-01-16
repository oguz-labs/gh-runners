#!/bin/bash

# install.sh - Setup script for gh-runners-k8s distribution
# Allows user to define deployment parameters interactively or via environment variables

set -e

# Prompt for input if not set via environment variables
TARGET_TYPE=${TARGET_TYPE:-}
TARGET_NAME=${TARGET_NAME:-}
MIN_REPLICA_COUNT=${MIN_REPLICA_COUNT:-1}
MAX_REPLICA_COUNT=${MAX_REPLICA_COUNT:-}
GITHUB_TOKEN=${GITHUB_TOKEN:-}

# Interactive prompts if not set
if [ -z "$TARGET_TYPE" ]; then
  read -rp "Enter target type (project/organisation): " TARGET_TYPE
fi

if [ -z "$TARGET_NAME" ]; then
  read -rp "Enter target name: " TARGET_NAME
fi

if [ -z "$MIN_REPLICA_COUNT" ]; then
  read -rp "Enter min replica count [default: 1]: " MIN_REPLICA_COUNT
  MIN_REPLICA_COUNT=${MIN_REPLICA_COUNT:-1}
fi

if [ -z "$MAX_REPLICA_COUNT" ]; then
  read -rp "Enter max replica count (mandatory): " MAX_REPLICA_COUNT
fi

if [ -z "$MAX_REPLICA_COUNT" ]; then
  echo "Error: max replica count is mandatory." >&2
  exit 1
fi

# Prompt for GitHub token if not set
if [ -z "$GITHUB_TOKEN" ]; then
  read -rsp "Enter your GitHub Personal Access Token (GITHUB_TOKEN): " GITHUB_TOKEN
  echo
fi

# Export for use in other scripts or k8s manifests
echo "\nConfiguration:"
echo "  Target type: $TARGET_TYPE"
echo "  Target name: $TARGET_NAME"
echo "  Min replica count: $MIN_REPLICA_COUNT"
echo "  Max replica count: $MAX_REPLICA_COUNT"

echo "  GitHub token: ${GITHUB_TOKEN:+***hidden***}"

# Write the GitHub token to k8s/secrets.yaml
SECRETS_FILE="k8s/secrets.yaml"
if [ ! -f "$SECRETS_FILE" ]; then
  cp k8s/secrets.yaml.example "$SECRETS_FILE"
fi

# Replace the github_token value in secrets.yaml
sed -i '' "s|github_token:.*|github_token: \"$GITHUB_TOKEN\"|" "$SECRETS_FILE"

echo "GitHub token stored in $SECRETS_FILE as a Kubernetes secret."

echo "\nConfiguration saved to install-config.env. Use this file to template your deployment."
