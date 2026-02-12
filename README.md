# KDE-cli

[English](./README.md) | [繁體中文](./README.zh-TW.md)

> **Kubernetes Development Environment CLI** - A development environment and delivery workflow management tool for Kubernetes

KDE-cli is a unified management tool for Kubernetes development environments that integrates a complete development toolchain, enabling full lifecycle management from environment creation to deployment. It consolidates scattered Kubernetes development tools into a unified command interface, allowing developers to complete the entire Kubernetes development workflow—from environment creation, development, testing, to deployment—using **one toolset and one command interface**.

## ✨ Core Features

### 🔄 Environment Consistency (Dev/Prod Parity)
- Quickly start Kind/K3D Kubernetes development environments
- Quickly connect to existing Kubernetes environments (via kubeconfig)
- Development environment achieves real-time code sync and Hot Reload via PVC mounting
- Intercept remote Kubernetes traffic to local development containers via Telepresence
- Development and production environments both run inside Kubernetes
- All tools run inside containers, ensuring environment consistency

### 📦 Version Controllable, Reproducible, Portable
- Environment configuration (`k8s.env`) can be version controlled
- Project configuration (`project.env`) can be version controlled
- CI/CD Pipeline configuration can be version controlled
- Unified tool version management (`kde.env`)
- Quickly sync and migrate multiple environments, projects, and CI/CD Pipelines across different computers via GitHub/GitLab
- Team members can quickly replicate identical development environments
- Rapid onboarding for new members

### 🚀 Script-Driven CI/CD Pipeline
- Define CI/CD workflows using Shell Scripts
- Customize pipeline stages and execution environments
- Support manual mode for development and debugging
- Flexible error handling mechanism

### 🔒 Project Isolation
- Each project corresponds to an independent Kubernetes Namespace with complete resource isolation
- Development containers are isolated from each other, allowing simultaneous development of multiple projects without interference
- Resource isolation: Set independent resource quotas and limits for each project
- Environment variable isolation: Each project's configuration and environment variables do not affect each other
- Multiple projects can run simultaneously in the same Workspace without conflicts

### 🐳 Container First
- Only Docker installation needed to execute all functions
- All tools run inside containers
- Avoid polluting the local environment
- Ensure environment consistency

### 🎯 Unified Tool Entry Point
Integrates 9+ Kubernetes development tools into a unified CLI interface, reducing the learning curve:

```bash
kde start               # Create/start environment (Kind/K3D/K8s)
kde k9s                 # Launch K9s terminal management tool
kde headlamp            # Launch Headlamp Web UI
kde telepresence        # Launch Telepresence traffic interception
kde code-server         # Launch VSCode Web IDE
kde cloudflare-tunnel   # Launch Cloudflare Tunnel
kde ngrok               # Launch Ngrok external connection
kde expose              # Port Forward
```

## 🎯 Target Audience

### Organizations
- Want to align development and production environments
- Need to manage multiple environments and projects
- Need to standardize development workflows and version control environment configurations
- Teams want to maintain environment consistency
- Need rapid onboarding (one-click environment startup)
- Want to test CI/CD workflows and validate K8s configurations in development environments

### Projects
- Projects deployed to Kubernetes in production
- Microservices architecture
- Need to deploy to multiple K8s environments

### Users (Developer/DevOps/SRE/QA)
- Quickly create simulation environments
- Convenient for development/debugging
- Convenient for K8s environment and CI/CD Pipeline simulation/development/debugging
- Version-controlled environment configuration management
- Local simulation of complete K8s environments

## 🚀 Quick Start

### System Requirements

- **Docker**: Installed and running
- **Operating System**: Linux / macOS / Windows (WSL)
- **Shell**: Bash
- **Permissions**: Requires sudo permissions for installation

### Installation

#### Method 1: One-Click Installation (Recommended)

```bash
# Using curl (requires sudo permissions)
curl -fsSL https://code.anyong.com.tw/ay/v4/quick-start/kde-env/cli/-/raw/anyong/install.sh?ref_type=heads | sudo bash

# Or using wget (requires sudo permissions)
wget -qO- https://code.anyong.com.tw/ay/v4/quick-start/kde-env/cli/-/raw/anyong/install.sh?ref_type=heads | sudo bash

# Verify installation
kde --version
```

#### Method 2: Manual Installation

```bash
# 1. Clone the project
git clone https://github.com/r82wei/KDE-cli.git
cd KDE-cli

# 2. Run installation (requires sudo permissions)
sudo ./local-install.sh

# 3. Verify installation
kde --version
```

### 5-Minute Quick Experience

```bash
# 1. Initialize Workspace
mkdir my-workspace && cd my-workspace
kde init

# 2. Start Kind development environment
kde start dev-env kind

# 3. Create project
kde proj create myapp
# Choose to fetch from Git repository or create local project
# Set development image (e.g., node:20)

# 4. Run CI/CD Pipeline deployment
kde proj pipeline myapp

# 5. Launch K9s for monitoring
kde k9s
```

Congratulations! You have successfully created your first Kubernetes development environment and deployed a project.

## 📚 Core Concepts

### Workspace
Workspace is the core organizational unit of KDE-cli, used to centrally manage:
- **Environment Definitions**: One or more Kubernetes clusters (local or remote)
- **Project Definitions**: Each project corresponds to a K8s Namespace
- **CI/CD Workflow Definitions**: Each project can define independent Pipeline workflows

### Environment
Supports three environment types:
- **Kind**: Kubernetes in Docker, suitable for local development
- **K3D**: K3s in Docker, lightweight local development environment
- **External K8s**: Connect to cloud or on-premises K8s clusters

### Project
- Each project corresponds to a Kubernetes Namespace
- Contains application source code, build scripts, deployment scripts
- Supports fetching from Git repositories or local development

### CI/CD Pipeline
- Script-driven CI/CD workflows
- Default workflow: `build` → `deploy`
- Customizable stages: `test` → `lint` → `build` → `security-scan` → `release` → `deploy`
- Each stage can specify execution environment (Docker image)

## 🛠️ Integrated Tool Ecosystem

| Category | Tool | Function |
|------|------|------|
| **Local K8s** | Kind, K3D | Quickly start local Kubernetes environments |
| **K8s Management** | K9s | TUI terminal graphical interface |
| | Headlamp | Web UI graphical management interface |
| **Development Integration** | Dev Container | DEVELOP_IMAGE container environment |
| | Kind/K3D + PVC Mount | Real-time code sync via local-path-provisioner |
| | Telepresence | Remote Pod traffic forwarding and environment simulation |
| | code-server | VSCode development environment with Web UI |
| | Port Forward | Forward Service/Pod ports to local |
| **External Connectivity** | Cloudflare Tunnel | Secure external connection (custom domain) |
| | Ngrok | Quick temporary external connection |

## 📖 Basic Usage

### Environment Management

```bash
# List all environments
kde list
kde ls

# Start/create environment
kde start dev-env kind        # Kind environment
kde start test-env k3d        # K3D environment
kde start prod-env k8s        # External K8s environment

# Switch environment
kde use dev-env

# View environment status
kde status

# Stop environment
kde stop dev-env

# Restart environment
kde restart dev-env

# Remove environment
kde remove dev-env
kde rm dev-env
```

### Project Management

```bash
# List projects
kde proj list
kde proj ls

# Create project
kde proj create myapp

# Run CI/CD Pipeline deployment
kde proj pipeline myapp
kde proj deploy myapp

# Update project code
kde proj pull myapp

# Redeploy
kde proj redeploy myapp

# Undeploy project
kde proj undeploy myapp

# Remove project
kde proj remove myapp
kde proj rm myapp
```

### Development Mode

```bash
# Enter development container (DEVELOP_IMAGE)
kde proj exec myapp develop
kde proj exec myapp dev

# Enter development container with port mapping
kde proj exec myapp develop 3000

# Enter deployment container (DEPLOY_IMAGE, includes kubectl/helm)
kde proj exec myapp deploy
kde proj exec myapp dep
```

### Monitoring and Debugging

```bash
# Launch K9s (terminal UI)
kde k9s

# Launch Headlamp (Web UI)
kde headlamp

# View project Pod logs
kde proj tail myapp
```

### External Connectivity

```bash
# Port Forward (local access)
kde expose myapp service myapp-service 3000 3000

# Cloudflare Tunnel (secure external access)
kde cloudflare-tunnel myapp.example.com service

# Ngrok (quick external access)
kde ngrok service
```

### Advanced CI/CD Pipeline Operations

```bash
# Execute complete Pipeline
kde proj pipeline myapp

# Start from specific stage
kde proj pipeline myapp --from build

# Execute to specific stage
kde proj pipeline myapp --to test

# Execute only specific stage
kde proj pipeline myapp --only build

# Manual mode (debugging)
kde proj pipeline myapp --manual
kde proj pipeline myapp --only build --manual
```

## 🏗️ Development Modes

KDE-cli supports three development modes, adapting to different development scenarios:

### Mode 1: Development Container Mode
Enter `DEVELOP_IMAGE` container, mount project folder for development.

```bash
kde proj exec myapp develop [port]
```

**Use Cases**: Rapid development, unit testing, no K8s functionality needed

### Mode 2: K8s + PVC Mount Mode (Hot Reload)
Deploy application to K8s via K8s YAML or Helm, use `local-path-provisioner` to mount source code into Pod.

```
Local code → PVC → Real-time sync in Pod → Hot Reload
```

**Use Cases**: Integration testing, near-production environment development, needs K8s network functionality

### Mode 3: Telepresence Mode
Intercept remote K8s Pod traffic to local development container.

```bash
kde telepresence replace myapp myapp-deployment
```

**Use Cases**: Connect to remote K8s for development, need to access remote services

## 📖 Documentation

For complete documentation, refer to the `docs/` directory:

### Core Documentation
- **[KDE-cli Overview](./docs/core/overview.md)** - Core value and development lifecycle
- **[Workspace](./docs/core/workspace.md)** - Complete Workspace explanation
- **[Design Principles](./docs/principle.md)** - Design philosophy and workflows

### Environment Management
- **[Environment Overview](./docs/core/environment/environment-overview.md)** - Environment types and development modes
- **[Kubernetes Environment](./docs/core/environment/kubernetes/overview.md)** - Detailed K8s environment explanation
  - [Kind Environment](./docs/core/environment/kubernetes/kind.md)
  - [K3D Environment](./docs/core/environment/kubernetes/k3d.md)
  - [External K8s Environment](./docs/core/environment/kubernetes/external-kubernetes.md)
- **[Development Container](./docs/core/environment/dev-container.md)** - Detailed development container explanation

### Projects and CI/CD
- **[Project Management](./docs/core/project.md)** - Project configuration and management
- **[CI/CD Pipeline](./docs/core/cicd-pipeline.md)** - Script-driven CI/CD workflows

### Development Tools
- **[Development Tools Overview](./docs/dev-tools.md)** - Integrated tools overview
- **[K9s](./docs/core/dev-tools/k9s.md)** - Terminal K8s management tool
- **[Headlamp](./docs/core/dev-tools/headlamp.md)** - Web UI Dashboard
- **[Telepresence](./docs/core/dev-tools/telepresence.md)** - Remote traffic interception
- **[code-server](./docs/core/dev-tools/code-server.md)** - Web VSCode
- **[Port Forward](./docs/core/dev-tools/port-forward.md)** - Port forwarding
- **[Cloudflare Tunnel](./docs/core/dev-tools/cloudflare-tunnel.md)** - Secure external connection
- **[Ngrok](./docs/core/dev-tools/ngrok.md)** - Quick external connection

### Quick Reference
- **[Quick Reference Guide](./.cursor/rules/quick-reference.mdc)** - Quick command reference

## 🎓 Usage Examples

### Example 1: Team Collaborative Development Environment

```bash
# Administrator: Create and configure Workspace
mkdir team-workspace && cd team-workspace
kde init
kde start dev-env kind
kde proj create service-a
kde proj create service-b
# Configure projects...
git add . && git commit -m "Add dev environment" && git push

# Team members: One-click environment startup
git clone <team-workspace-repo-url>
cd team-workspace
kde start dev-env kind
kde proj pipeline service-a
kde proj pipeline service-b
kde k9s  # Start development
```

### Example 2: Multi-Environment Deployment

```bash
# Development environment
kde use dev-env
kde proj pipeline myapp

# Testing environment
kde use test-env
kde proj pipeline myapp

# Production environment
kde use prod-env
kde proj pipeline myapp
```

### Example 3: Using Telepresence to Connect to Remote K8s

```bash
# Connect to remote environment
kde start remote-env k8s

# Launch Telepresence to intercept traffic
kde telepresence replace myapp myapp-deployment

# Select project and enter development environment
# Local development, remote traffic directed to local
npm run dev
```

## 🔧 Debugging

Enable debug mode to track KDE-cli execution flow:

```bash
# Method 1: Temporary enable
KDE_DEBUG=true kde start dev-env kind
KDE_DEBUG=true kde proj pipeline myapp

# Method 2: Permanently enable in kde.env
echo "KDE_DEBUG=true" >> kde.env
kde proj pipeline myapp
```

Debug mode will display:
- Every shell command executed internally by KDE-cli
- Variable values and function calls
- Help track which step the issue occurred

## 📝 License

This project is licensed under the Apache 2.0 License - see the [LICENSE](./LICENSE) file for details

## 🔗 Related Resources

- **GitHub**: [r82wei/KDE-cli](https://github.com/r82wei/KDE-cli)
- **Documentation**: [docs/](./docs/)
- **Issues**: [GitHub Issues](https://github.com/r82wei/KDE-cli/issues)
- **Discussions**: [GitHub Discussions](https://github.com/r82wei/KDE-cli/discussions)

## 💡 Project Name Explanation

**KDE** = **Kubernetes Development Environment** = **Workspace**

These three terms refer to the same concept:
- **KDE** is the abbreviation, representing the entire development environment
- **Kubernetes Development Environment** is the full name
- **Workspace** is the actual organizational unit and directory structure
