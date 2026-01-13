# Custom GitHub Actions Runner with kubectl and buildx pre-installed
FROM summerwind/actions-runner-dind:latest

USER root

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/kubectl \
    && kubectl version --client

# Install Docker buildx for both root and runner users
RUN BUILDX_VERSION=$(curl -s https://api.github.com/repos/docker/buildx/releases/latest | jq -r '.tag_name') \
    && mkdir -p /root/.docker/cli-plugins /home/runner/.docker/cli-plugins \
    && curl -Lo /root/.docker/cli-plugins/docker-buildx \
       "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.linux-amd64" \
    && chmod +x /root/.docker/cli-plugins/docker-buildx \
    && cp /root/.docker/cli-plugins/docker-buildx /home/runner/.docker/cli-plugins/docker-buildx \
    && chown -R runner:runner /home/runner/.docker

# Verify installations
RUN echo "=== Installed versions ===" \
    && kubectl version --client --short 2>/dev/null || kubectl version --client \
    && echo "Docker buildx installed for root and runner users"

USER runner
