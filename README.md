# Azure Dev Container

This repo contains a **reusable VS Code Dev Container** focused on Azure infrastructure, AI, and automation work. The container image is automatically built and published to GitHub Container Registry on every merge to `main`.

## 🚀 Quick Start

### Using in Your Own Projects

Add this to your project's `.devcontainer/devcontainer.json`:

```json
{
  "name": "My Azure Project",
  "image": "ghcr.io/YOUR_USERNAME/azure-dev-container:latest",
  "postCreateCommand": "npm install",  // Your project-specific setup
  "customizations": {
    "vscode": {
      "extensions": [
        // Add any additional extensions your project needs
      ]
    }
  }
}
```

Replace `YOUR_USERNAME` with your GitHub username.

### Building This Container

This repo contains the source for the dev container. Open the folder in VS Code and when prompted choose **Reopen in Container**. VS Code will build the Docker image defined under `.devcontainer/` and attach your workspace.

## What you get

- Prebuilt image `mcr.microsoft.com/devcontainers/python:1-3.11-bookworm` (multi-arch) – no local Docker build needed
- Post-create installs: OpenJDK 17, Node 20, Terraform 1.6.x, Bicep, Azure CLI + azd, npm CLIs (Claude Code, OpenAI)
- VS Code extensions preconfigured (Copilot, Pylance, Python, Terraform, Azure tooling, Docker)

## Usage notes

1. Install the [VS Code Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) and ensure Docker Desktop (or Colima/Rancher) is running.
2. Open this folder in VS Code and run the *Dev Containers: Reopen in Container* command. It will pull the Python dev container and skip Dockerfile builds.
3. After the container starts, the `postCreateCommand` script will:
   - Refresh Azure CLI extensions
   - Install Claude Code/OpenAI CLIs globally
   - Install repo dependencies if it detects lockfiles (`requirements.dev.txt`, `poetry.lock`, `package-lock.json`, etc.)
   - Run `terraform init` if a `terraform/.terraform.lock.hcl` exists
4. Authenticate as needed:
   - `az login --use-device-code` for the Azure CLI
   - `azd auth login` for Azure Developer CLI
   - `gh auth login` if you use GitHub CLI

> Security note: `post-create.sh` enables an "allow insecure apt" mode by default so Azure CLI/JDK installs can succeed on networks that MITM or re-sign Ubuntu mirrors (common on corporate VPNs). To tighten, set `APT_ALLOW_INSECURE` to `false` under `containerEnv` in `.devcontainer/devcontainer.json` and reopen the container.

## Apple Silicon

Most tooling in the container ships with official `linux/arm64` builds. If you primarily work on Apple silicon Macs, set `"dev.containers.defaultPlatform": "linux/arm64"` in your VS Code settings so Docker pulls the correct architecture automatically. If you occasionally need `linux/amd64` for parity with CI, override the platform per-rebuild via the *Dev Containers: Rebuild Container* command.

## Customizing

- Adjust `.devcontainer/devcontainer.json` to add/remove VS Code extensions, tweak lifecycle commands, or inject environment variables/secrets.
- Update `.devcontainer/scripts/post-create.sh` to align with your repo conventions (e.g., add `pip install -r requirements.txt`, run linters, seed databases).
- If you need to pin different runtime versions, edit the build args in `devcontainer.json` and rebuild.

## 🔄 Automated Builds

This repository uses GitHub Actions to automatically build and publish the container image:

- **On PR:** Builds the image to validate changes (doesn't publish)
- **On merge to `main`:** Builds and pushes to GitHub Container Registry
- **Manual trigger:** Can be triggered via Actions tab

The workflow generates these tags:
- `latest` - Always points to the most recent main build
- `main` - Tagged with branch name
- `main-<sha>` - Tagged with specific commit SHA for reproducibility

### Making Changes

1. Create a branch and modify `.devcontainer/` files
2. Open a PR - the workflow will validate your changes
3. Merge to `main` - the image is automatically built and published
4. Use the new image in other repos by referencing `ghcr.io/YOUR_USERNAME/azure-dev-container:latest`

### Permissions

The workflow uses `GITHUB_TOKEN` which is automatically provided by GitHub Actions - **no secrets needed!** The token has permissions to:
- Read repository contents
- Write packages to GHCR

Make sure your repository has "Workflow permissions" set to "Read and write permissions" in Settings → Actions → General.

