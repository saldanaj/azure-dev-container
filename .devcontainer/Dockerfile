# syntax=docker/dockerfile:1.4

ARG BASE_IMAGE=mcr.microsoft.com/devcontainers/base:ubuntu
FROM ${BASE_IMAGE}

ARG TERRAFORM_VERSION=1.6.6
ARG BICEP_VERSION=0.26.54
ARG APT_ALLOW_INSECURE=true
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    PIPX_HOME=/opt/pipx \
    PIPX_BIN_DIR=/opt/pipx/bin \
    PATH=/opt/pipx/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    AZURE_EXTENSION_DIR=/usr/lib/azure-cli/extensions \
    NPM_CONFIG_PREFIX=/usr/local

# Base packages and locale
RUN bash <<'EOF'
set -euo pipefail
if [ "${APT_ALLOW_INSECURE}" = "true" ]; then
  cat >/etc/apt/apt.conf.d/99allow-insecure <<'EOC'
Acquire::AllowInsecureRepositories "true";
Acquire::AllowDowngradeToInsecureRepositories "true";
APT::Get::AllowUnauthenticated "true";
EOC
fi
apt-get update
# Work around limited /var/cache/apt space in some builders
mkdir -p /tmp/apt-archives
rm -rf /var/cache/apt/archives || true
ln -s /tmp/apt-archives /var/cache/apt/archives
apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    direnv \
    git \
    jq \
    less \
    locales \
    lsb-release \
    openssh-client \
    pkg-config \
    python3-pip \
    python3-venv \
    software-properties-common \
    sudo \
    tar \
    unzip \
    wget \
    xz-utils \
    zip
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/apt-archives/*
EOF

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Upgrade pip/pipx tooling (ensurepip is disabled in Ubuntu, use pip3 directly)
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel pipx && \
    pipx ensurepath

# Install Terraform
RUN case "${TARGETARCH}" in \
        "amd64") TERRAFORM_ARCH="amd64" ;; \
        "arm64") TERRAFORM_ARCH="arm64" ;; \
        *) echo "Unsupported TARGETARCH: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -fsSLo /tmp/terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TERRAFORM_ARCH}.zip && \
    unzip /tmp/terraform.zip -d /usr/local/bin && \
    rm /tmp/terraform.zip

# Install Azure CLI
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/azure-cli.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends azure-cli && \
    rm -rf /var/lib/apt/lists/*

# Install Azure Developer CLI
RUN curl -fsSL https://aka.ms/install-azd.sh | bash

# Install Bicep CLI
RUN case "${TARGETARCH}" in \
        "amd64") BICEP_ARCH="x64" ;; \
        "arm64") BICEP_ARCH="arm64" ;; \
        *) echo "Unsupported TARGETARCH ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -fsSLo /usr/local/bin/bicep https://github.com/Azure/bicep/releases/download/v${BICEP_VERSION}/bicep-linux-${BICEP_ARCH} && \
    chmod +x /usr/local/bin/bicep

# Preinstall Azure CLI extensions for AI, security, and infrastructure workflows
RUN mkdir -p ${AZURE_EXTENSION_DIR} && \
    az config set extension.use_dynamic_install=yes_without_prompt && \
    for ext in ml azure-devops azure-iot application-insights front-door resource-graph security k8s-extension azure-firewall; do \
        az extension add --system --name "${ext}" || echo "Warning: could not install Azure CLI extension ${ext}"; \
    done

# Python Azure SDKs and Dev tooling
RUN python3 -m pip install --no-cache-dir \
        azure-identity \
        azure-keyvault-secrets \
        azure-mgmt-resource \
        azure-mgmt-security \
        azure-mgmt-subscription \
        azure-storage-blob \
        azure-ai-ml \
        azure-ai-textanalytics \
        black \
        pre-commit && \
    pipx install poetry

# Helpful shell defaults
RUN echo 'eval "$(direnv hook zsh)"' >> /etc/zsh/zprofile && \
    echo 'eval "$(direnv hook bash)"' >> /etc/profile.d/direnv.sh && \
    chmod +x /etc/profile.d/direnv.sh

WORKDIR /workspaces
