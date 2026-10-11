# Custom GitHub Actions Runner, split into two flavors from a shared base:
#   deploy — lean, for build/push/helm-upgrade jobs (runs-on: [..., on-demand])
#   e2e    — deploy + Java/Allure + Chromium OS deps, for E2E jobs (runs-on: [..., e2e])
# Build with: docker build --target deploy ... / --target e2e ...
FROM summerwind/actions-runner-dind:latest AS base

USER root

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    jq \
    ca-certificates \
    nftables \
    iptables \
    sudo \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Add deadsnakes PPA for Python 3.11 and install it
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    && rm -rf /var/lib/apt/lists/*

# Install pip for Python 3.11 and expose common symlinks
RUN python3.11 -m ensurepip --upgrade \
    && ln -sf /usr/bin/pip3.11 /usr/local/bin/pip3.11 \
    && ln -sf /usr/bin/pip3.11 /usr/local/bin/pip3 \
    && ln -sf /usr/bin/pip3.11 /usr/local/bin/pip \
    && ln -sf /usr/bin/python3.11 /usr/local/bin/python3

# Add runner user to sudoers (no password required)
RUN echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create python3.11 symlink for convenience
RUN ln -sf /usr/bin/python3.11 /usr/local/bin/python3.11

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/kubectl \
    && kubectl version --client \
    && curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Docker buildx for both root and runner users
RUN BUILDX_VERSION=$(curl -s https://api.github.com/repos/docker/buildx/releases/latest | jq -r '.tag_name') \
    && mkdir -p /root/.docker/cli-plugins /home/runner/.docker/cli-plugins \
    && curl -Lo /root/.docker/cli-plugins/docker-buildx \
       "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.linux-arm64" \
    && chmod +x /root/.docker/cli-plugins/docker-buildx \
    && cp /root/.docker/cli-plugins/docker-buildx /home/runner/.docker/cli-plugins/docker-buildx \
    && chown -R runner:runner /home/runner/.docker

# Allow insecure local JFrog registry over HTTP (host gateway + loopback)
RUN mkdir -p /etc/docker \
    && echo '{ "insecure-registries": ["host.docker.internal:8081", "127.0.0.1:8081"] }' > /etc/docker/daemon.json

# Verify base installations
RUN echo "=== Installed versions (base) ===" \
    && kubectl version --client --short 2>/dev/null || kubectl version --client \
    && helm version \
    && echo "Docker buildx installed for root and runner users"

# ---------------------------------------------------------------------------
FROM base AS deploy
# Nothing extra: build/push/helm-upgrade jobs only need what's in `base`.
USER runner

# ---------------------------------------------------------------------------
FROM base AS e2e

# Java (JRE) for allure-commandline, which looks up `java` on PATH / JAVA_HOME
# and otherwise fails the "Generate Allure report" step outright.
RUN apt-get update && apt-get install -y default-jre-headless \
    && rm -rf /var/lib/apt/lists/*

# OS-level shared libs for headless Chromium. These are required at the ldconfig
# level regardless of which runtime launches the browser — Python's `playwright`
# pip package below, or the Node/npx-driven Chromium that Robot Framework's
# `Browser` library (rfbrowser) downloads fresh via its own actions/setup-node
# toolchain on every job. Listed explicitly (not via `playwright install
# --with-deps`, which only covers whatever Playwright revision happens to be
# invoked at bake time) so the fix holds even as that pinned revision drifts.
# Names are Ubuntu 24.04 (noble) t64-ABI package names — confirmed against
# this image's own /etc/os-release, not guessed.
RUN apt-get update && apt-get install -y \
    libnss3 \
    libatk1.0-0t64 \
    libatk-bridge2.0-0t64 \
    libcups2t64 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2t64 \
    libatspi2.0-0t64 \
    && rm -rf /var/lib/apt/lists/*

# Pre-bake the Python `playwright` pip package + its own Chromium, for any
# workflow step that imports Python's playwright directly (not every E2E job
# goes through rfbrowser/Node). Harmless if unused.
# PLAYWRIGHT_BROWSERS_PATH must be a real ENV (not a build-time export): without
# it the runner user looks in ~/.cache/ms-playwright and downloads anyway.
# Note: this does NOT dedupe the ~150-170MB Chromium download rfbrowser's
# Node-side install performs — that one lands under actions/setup-python's
# per-job hostedtoolcache path, which is wiped with the ephemeral pod. See
# gh-runners docs/REGISTRY-OPERATIONS.md (follow-up) for the persistent-cache
# option if that download cost needs eliminating too.
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN mkdir -p /ms-playwright \
    && python3 -m pip install --no-cache-dir 'playwright>=1.40,<2' \
    && python3 -m playwright install chromium \
    && chown -R runner:runner /ms-playwright

# Verify e2e-specific installations
RUN echo "=== Installed versions (e2e) ===" \
    && java -version \
    && python3 -m playwright --version \
    && ls /ms-playwright

USER runner
