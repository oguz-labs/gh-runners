
# gh-runners-k8s: Distributable GitHub Runner on Kubernetes

## Quick Start (Distribution)

1. **Clone the repository:**
   ```sh
   git clone https://github.com/oguz-labs/gh-runners.git
   cd gh-runners
   ```

2. **Run the install script:**
   ```sh
   ./install.sh
   ```
   The script will prompt you for:
   - Target type (`project` or `organisation`)
   - Target name (string)
   - Min replica count (optional, default: 1)
   - Max replica count (mandatory)

   You can also set these as environment variables:
   ```sh
   TARGET_TYPE=project TARGET_NAME=myrepo MIN_REPLICA_COUNT=2 MAX_REPLICA_COUNT=5 ./install.sh
   ```

   The configuration will be saved to `install-config.env` for use in deployment manifests.

3. **Deploy to Kubernetes:**
   Update your deployment manifests (e.g., `k8s/arc/runner-deployment.yaml`) to use the variables from `install-config.env`.

## Parameters

- **TARGET_TYPE**: `project` or `organisation` (required)
- **TARGET_NAME**: Name of the target (required)
- **MIN_REPLICA_COUNT**: Minimum number of runner replicas (optional, default: 1)
- **MAX_REPLICA_COUNT**: Maximum number of runner replicas (required)

## Distribution

This project is designed for easy distribution. Anyone can clone the repository, run the install script, and deploy their own GitHub runners to Kubernetes with custom configuration.

# GitHub Runners on Kubernetes

Kubernetes setup for running GitHub Actions self-hosted runners on-demand using Actions Runner Controller (ARC).

## Overview

This project provides a production-ready Kubernetes configuration for deploying GitHub Actions runners that:
- **Auto-scale on demand**: Runners are created when jobs are queued and terminated after completion
- **Ephemeral by design**: Each runner handles a single job for enhanced security
- **Resource efficient**: No idle runners consuming resources
- **Easy to manage**: Uses Actions Runner Controller (official GitHub solution)
- **GHCR Integration**: Uses GitHub Container Registry (ghcr.io) for container images

## Architecture

- **Namespace**: `github-runners` - Isolated environment for runner resources
- **Actions Runner Controller**: Manages runner lifecycle and scaling
- **Auto-scaling**: Webhook or polling-based scaling from 0 to N runners
- **RBAC**: Minimal permissions for runner pods

## Prerequisites

- Kubernetes cluster (1.20+)
- `kubectl` configured with cluster access
- Helm 3.x
- GitHub Personal Access Token (PAT) or GitHub App credentials

### Required GitHub PAT Scopes

For **repository runners**:
- `repo` (Full control of private repositories)

For **organization runners**:
- `admin:org` (Full control of orgs and teams)
- `repo` (Full control of private repositories)

## Quick Start

### 1. Configure Environment Variables

Copy the example .env file and fill in your values:

```bash
cp .env.example .env
```

Edit `.env` and configure:
- `GITHUB_TOKEN`: Your GitHub Personal Access Token
- `GITHUB_OWNER` and `GITHUB_REPOSITORY`: Your repository details
- `RUNNER_SCOPE`: Set to `repository`, `organization`, or `enterprise`
- `RUNNER_LABELS`: Custom labels for your runners (comma-separated)

**Important**: Never commit `.env` to version control!

### 2. Generate Kubernetes Secrets

Generate the secrets manifest from your .env:

```bash
./scripts/generate-secrets.sh
```

This creates `k8s/secrets.yaml` with your GitHub credentials.

### 3. Run Setup Script

```bash
./scripts/setup.sh
```

This script will:
1. Validate your .env configuration
2. Create the namespace
3. Apply RBAC configuration
4. Generate and create secrets
5. Install Actions Runner Controller
6. Update and deploy runner configuration

### 4. Verify Installation

```bash
# Check ARC controller is running
kubectl get pods -n actions-runner-system

# Check runner deployment
kubectl get runners -n github-runners
kubectl get pods -n github-runners
```

### 5. Test with a Workflow

Create a workflow in your repository:

```yaml
name: Test Self-Hosted Runner
on: [push]

jobs:
  test:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - run: echo "Running on self-hosted runner!"
      - run: uname -a
      
  build-and-push:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      
      - name: Login to GHCR
        run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
      
      - name: Build and push image
        run: |
          docker build -t ghcr.io/${{ github.repository }}/myapp:${{ github.sha }} .
          docker push ghcr.io/${{ github.repository }}/myapp:${{ github.sha }}
```

## Configuration

### Environment Variables

All configuration is managed through the `.env` file:

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `GITHUB_TOKEN` | Yes | GitHub PAT with appropriate scopes | `ghp_xxx...` |
| `RUNNER_SCOPE` | Yes | Runner scope type | `repository`, `organization`, or `enterprise` |
| `GITHUB_OWNER` | If repo | GitHub username or org name | `myusername` |
| `GITHUB_REPOSITORY` | If repo | Repository name | `myrepo` |
| `GITHUB_ORGANIZATION` | If org | Organization name | `myorg` |
| `GITHUB_ENTERPRISE` | If ent | Enterprise name | `myenterprise` |
| `RUNNER_LABELS` | No | Comma-separated runner labels | `self-hosted,kubernetes,on-demand` |
| `MIN_REPLICAS` | No | Minimum idle runners (default: 0) | `0` |
| `MAX_REPLICAS` | No | Maximum concurrent runners (default: 10) | `10` |
| `RUNNER_CPU_REQUEST` | No | CPU request per runner (default: 1) | `1` |
| `RUNNER_CPU_LIMIT` | No | CPU limit per runner (default: 2) | `2` |
| `RUNNER_MEMORY_REQUEST` | No | Memory request (default: 2Gi) | `2Gi` |
| `RUNNER_MEMORY_LIMIT` | No | Memory limit (default: 4Gi) | `4Gi` |

### Updating Configuration

After modifying `.env`:

```bash
# Regenerate secrets
./scripts/generate-secrets.sh
kubectl apply -f k8s/secrets.yaml

# Update runner deployment
./scripts/update-runner-deployment.sh
kubectl apply -f k8s/arc/runner-deployment.yaml
```

### Scaling Configuration

Edit [k8s/arc/runner-deployment.yaml](k8s/arc/runner-deployment.yaml) to adjust scaling settings, or modify the corresponding variables in `.env` and regenerate:

- **Min replicas**: `MIN_REPLICAS` in .env (default: 0)
- **Max replicas**: `MAX_REPLICAS` in .env (default: 10)
- **Resources**: `RUNNER_CPU_*` and `RUNNER_MEMORY_*` in .env

### Runner Scope

Runners can be configured at different levels:

- **Repository level**: Runners for a specific repo
- **Organization level**: Runners shared across all repos in org
- **Enterprise level**: Runners shared across the enterprise

See the deployment YAML for configuration examples.

## Manual Operations

### Scale Runners Manually

```bash
# Scale to specific number
kubectl scale runnerdeployment gh-runner -n github-runners --replicas=5

# Check current scale
kubectl get runnerdeployment -n github-runners
```

### View Runner Logs

```bash
# List runner pods
kubectl get pods -n github-runners

# View logs
kubectl logs <pod-name> -n github-runners
```

### Restart Runners

```bash
kubectl rollout restart deployment/<runner-deployment> -n github-runners
```

## Security Considerations

1. **Secrets Management**: Store GitHub PAT in Kubernetes secrets, never in code
2. **RBAC**: Runners have minimal permissions within the cluster
3. **Network Policies**: Consider adding network policies to restrict egress
4. **Image Security**: Use trusted runner images, scan for vulnerabilities
5. **Ephemeral Runners**: Each runner handles one job then terminates

## Troubleshooting

### Runners Not Appearing in GitHub

1. Check controller logs:
   ```bash
   kubectl logs -n actions-runner-system deployment/arc-controller-manager
   ```

2. Verify secrets:
   ```bash
   kubectl get secrets -n github-runners
   kubectl describe secret github-token -n github-runners
   ```

3. Check runner deployment status:
   ```bash
   kubectl describe runnerdeployment gh-runner -n github-runners
   ```

### Runners Not Scaling

1. Check webhook configuration (if using webhook mode)
2. Verify GitHub PAT has correct permissions
3. Check ARC logs for errors
4. Ensure GitHub webhook can reach your cluster (if applicable)

### Pods Stuck in Pending

1. Check node resources:
   ```bash
   kubectl top nodes
   ```

2. Check pod events:
   ```bash
   kubectl describe pod <pod-name> -n github-runners
   ```

## Cleanup

To remove all resources:

```bash
# Delete namespace and all resources
kubectl delete namespace github-runners

# Uninstall Actions Runner Controller
helm uninstall arc -n actions-runner-system
kubectl delete namespace actions-runner-system
```

## Project Structure

```
gh_runners_k8s/
├──Container Registry

This setup uses **GitHub Container Registry (GHCR)** for storing container images.


For local registry setup, see https://github.com/oguz-labs/local-registry.git

**Image naming convention:**
```
ghcr.io/doguz2509/calorimeter_ai/bot:tag
ghcr.io/doguz2509/calorimeter_ai/backend:tag
ghcr.io/doguz2509/calorimeter_ai/llm:tag
```

## Resources

- [Actions Runner Controller Documentation](https://github.com/actions/actions-runner-controller)
- [GitHub Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry
│   ├── rbac.yaml                      # Service accounts and roles
│   ├── secrets.yaml.example           # Example secrets template
│   └── arc/                           # Actions Runner Controller config
│       ├── install.sh                 # ARC installation script
│       └── runner-deployment.yaml     # Runner deployment config
└── scripts/                           # Helper scripts
    └── setup.sh                       # Automated setup script
```

## Resources

- [Actions Runner Controller Documentation](https://github.com/actions/actions-runner-controller)
- [GitHub Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## License

MIT
