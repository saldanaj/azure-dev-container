#!/usr/bin/env bash
set -euo pipefail

PYTHON_BIN="${PYTHON_BIN:-python3}"
APT_ALLOW_INSECURE="${APT_ALLOW_INSECURE:-true}"
ARCH="$(dpkg --print-architecture)"
NODE_VERSION="20.11.1"
TERRAFORM_VERSION="1.6.6"
PROJECT_ROOT="/workspaces/$(basename "$(pwd)")"

echo "Running post-create automation for ${PROJECT_ROOT}"

if command -v terraform >/dev/null 2>&1; then
  echo "Setting up Terraform autocomplete"
  terraform -install-autocomplete || true
fi

if command -v az >/dev/null 2>&1; then
  echo "Upgrading pinned Azure CLI extensions (safe to re-run)"
  EXTENSIONS=(ml azure-devops azure-iot application-insights front-door resource-graph security k8s-extension azure-firewall)
  for ext in "${EXTENSIONS[@]}"; do
    az extension update --name "${ext}" || az extension add --name "${ext}" || true
  done
fi

if [ -f requirements.dev.txt ] && command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "Installing Python dev dependencies from requirements.dev.txt"
  "${PYTHON_BIN}" -m pip install --user -r requirements.dev.txt
elif [ -f .devcontainer/requirements.txt ] && command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "Installing Python dependencies from .devcontainer/requirements.txt"
  "${PYTHON_BIN}" -m pip install --user -r .devcontainer/requirements.txt
elif [ -f requirements.txt ] && command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "Installing Python dependencies from requirements.txt"
  "${PYTHON_BIN}" -m pip install --user -r requirements.txt
fi

if [ -f pyproject.toml ] && command -v poetry >/dev/null 2>&1; then
  echo "Installing Python project via Poetry (no root package)"
  poetry install --no-root
fi

if [ -f package-lock.json ]; then
  echo "Detected npm project, installing dependencies"
  npm ci
elif [ -f pnpm-lock.yaml ]; then
  echo "Detected pnpm project, installing dependencies"
  pnpm install --frozen-lockfile
elif [ -f yarn.lock ]; then
  echo "Detected yarn project, installing dependencies"
  yarn install --frozen-lockfile
fi

if [ -f terraform/.terraform.lock.hcl ]; then
  echo "Initializing Terraform modules (skippable if state not configured)"
  (cd terraform && terraform init -upgrade || true)
fi

echo "Post-create automation complete."
if [ "${APT_ALLOW_INSECURE}" = "true" ]; then
  echo "Configuring apt to allow insecure repos (corporate proxy workaround)"
  sudo tee /etc/apt/apt.conf.d/99allow-insecure >/dev/null <<'EOC'
Acquire::AllowInsecureRepositories "true";
Acquire::AllowDowngradeToInsecureRepositories "true";
APT::Get::AllowUnauthenticated "true";
EOC
fi

# Optional: Install Java via apt to avoid brittle tarball URLs
echo "Ensuring OpenJDK 17 is installed"
sudo apt-get update -y || true
sudo apt-get install -y --no-install-recommends openjdk-17-jdk || true

# Install Azure CLI (Debian/Ubuntu script uses apt internally)
if ! command -v az >/dev/null 2>&1; then
  echo "Installing Azure CLI"
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash || true
fi

# Install Azure Developer CLI
if ! command -v azd >/dev/null 2>&1; then
  echo "Installing Azure Developer CLI (azd)"
  curl -fsSL https://aka.ms/install-azd.sh | bash || true
fi

# Install Bicep binary
if ! command -v bicep >/dev/null 2>&1; then
  echo "Installing Bicep CLI"
  case "${ARCH}" in
    amd64) BICEP_ARCH=x64 ;;
    arm64) BICEP_ARCH=arm64 ;;
    *) echo "Unsupported arch ${ARCH}" ; BICEP_ARCH=arm64 ;;
  esac
  sudo curl -fsSL -o /usr/local/bin/bicep "https://github.com/Azure/bicep/releases/download/v0.26.54/bicep-linux-${BICEP_ARCH}" && sudo chmod +x /usr/local/bin/bicep || true
fi

# Install Terraform binary
if ! command -v terraform >/dev/null 2>&1; then
  echo "Installing Terraform ${TERRAFORM_VERSION}"
  case "${ARCH}" in
    amd64) TF_ARCH=amd64 ;;
    arm64) TF_ARCH=arm64 ;;
    *) echo "Unsupported arch ${ARCH}" ; TF_ARCH=arm64 ;;
  esac
  curl -fsSLo /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TF_ARCH}.zip" && \
  sudo unzip -o /tmp/terraform.zip -d /usr/local/bin && rm -f /tmp/terraform.zip || true
fi

# Install Node.js from tarball
if ! command -v node >/dev/null 2>&1; then
  echo "Installing Node.js ${NODE_VERSION}"
  case "${ARCH}" in
    amd64) NODE_ARCH=linux-x64 ;;
    arm64) NODE_ARCH=linux-arm64 ;;
    *) echo "Unsupported arch ${ARCH}" ; NODE_ARCH=linux-arm64 ;;
  esac
  curl -fsSLo /tmp/node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-${NODE_ARCH}.tar.xz" && \
  sudo tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 && rm -f /tmp/node.tar.xz || true
  sudo npm install -g npm@latest yarn pnpm || true
fi

# Install global AI tooling via npm (after Node.js is available)
if command -v npm >/dev/null 2>&1; then
  echo "Installing global AI tooling via npm"
  sudo npm install -g @anthropic-ai/claude-code @openai/codex >/tmp/global-ai-install.log 2>&1 && cat /tmp/global-ai-install.log
fi

# Set az CLI to allow dynamic extension install (after install)
if command -v az >/dev/null 2>&1; then
  az config set extension.use_dynamic_install=yes_without_prompt || true
fi
