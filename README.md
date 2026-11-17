# KDE-cli

[English](./README.md) | [繁體中文](./README.zh-TW.md)

> **Kubernetes Development Environment CLI** - A development environment and delivery workflow management tool for Kubernetes

KDE-cli is a unified management tool for Kubernetes development environments that integrates a complete development toolchain, enabling full lifecycle management from environment creation to deployment. It consolidates scattered Kubernetes development tools into a unified command interface, allowing developers to complete the entire Kubernetes development workflow—from environment creation, development, testing, to deployment—using **one toolset and one command interface**.

## 💡 Unique Value
KDE-CLI turns "getting our services running on a local K8s cluster" from something each person figures out alone into a workspace you can `git clone`. Every team member runs their own cluster on their own machine and brings up the same projects from the same configuration.

### Value for a development team

- **Fast onboarding**: after cloning the team workspace, `kde start` plus `kde proj deploy` gives a new member the same cluster, projects, and pipelines as everyone else. If a project's repo is not on the machine yet, it is cloned automatically from `project.env`.
- **How to deploy is a shared, versioned asset**: `project.env` and the stage scripts live in Git, so when someone changes how a service is deployed, everyone else gets it with a pull.
- **Consistent tool versions**: the versions of Kind, K9s, kubectl, Helm, and the other tools are recorded in `kde.env` and run inside containers.
- **Machine differences stay local**: ports, paths, and secrets go in `.env` files that are not versioned, so each person can have their own settings.
- **A fast loop while developing inside the cluster**: in Kind/K3D environments a PVC maps directly to the project folder on the host, so code changes do not need an image rebuild. Problems with Ingress, Services, and mounted configuration show up on your machine first.
- **A fixed interface for AI agents**: the `--no-tty` commands and the skill installed by `kde claude-skill` let every member's agent deploy, read logs, and exec into pods with the same commands.

### With AI agents: what asking an agent to deploy cannot replace

An AI agent can write deployment scripts and can create a cluster. What it cannot provide is something that stays fixed: an agent regenerates its work each time, and a team needs things that do not change.

- **Consistency across the team**: if everyone asks their own agent to deploy, everyone gets a different directory layout and a different style of script. The workspace structure and `project.env` are a convention that exists outside any agent.
- **Daily operations that need no agent**: `kde proj redeploy` behaves the same every time, uses no tokens, and works offline.
- **A development loop, not a single deployment**: Hot Reload depends on the PVC-to-host-folder mapping that is set up when the cluster is created. It is a property of the environment, not a deployment step.
- **Guardrails for the agent itself**: every command mounts only that environment's own kubeconfig and never reads the host's `~/.kube/config`, so an agent cannot touch another cluster because the wrong context was active. Tools run in containers, so the agent installs nothing on the host. On an external cluster, undeploy refuses to delete the namespace unless an `undeploy.sh` exists.
- **Details that are already handled**: containers run as the host UID, the kubeconfig is rewritten to an address other containers can reach, source code on the host is kept when a PVC is deleted, and so on. None of this has to be rediscovered by trial and error.

The recommended split: the agent writes `build.sh` and `deploy.sh` and investigates problems; KDE makes those scripts run the same way on everyone's machine.

### What the team still owns

- **The deployment itself**: `kde proj create` generates empty `build.sh` and `deploy.sh` files. How closely the result matches production depends on what you put in them.
- **Distributing secrets**: a project's `.env` is not versioned and has to be provided to each member separately.
- **Start order across projects**: projects are deployed one at a time, and the team decides the order of dependent services.
- **Isolation and permissions on a shared cluster**: KDE's model is one local cluster per person. When several people connect to the same external cluster, permissions and staying out of each other's way are up to the cluster and the team.

### Another way to use it: a shared development environment

Instead of one local cluster per person, you can put a single workspace on a shared host, start one Kind cluster, and open one code-server per project. Members reach the project they are responsible for from a browser, and people in any role can discuss a question with Claude inside that project's code-server.

```bash
# Run from the workspace root; one code-server per project, each with its own name and port
kde code-server -d -n api -p 8081 -w environments/dev/namespaces/api -a claude
kde code-server -d -n web -p 8082 -w environments/dev/namespaces/web -a claude
```

**What it gives you**

- **Non-engineering roles can reach the running system**: PMs, QA, and designers install nothing and open the project in a browser. The Claude inside can read the code and use `kde` to read logs and exec into pods, so its answers are based on the services that are actually running.
- **Project context accumulates**: each code-server keeps its own home in `.code-server/<name>`, so Claude's settings and conversation history stay with the project. Every role talks to the same Claude that already knows this project.
- **An integration environment for free**: all projects run in the same cluster, so services can call each other directly and nobody has to run other people's services locally.
- **One environment to maintain**: one machine and one cluster, with no drift between individual setups.

**Limits to know before using it**

- **No isolation between projects**: the commands above mount the whole workspace, and every code-server can use the host's Docker and runs as the same host user. Anyone (and any Claude) can operate the whole cluster and other people's code-servers. "Each person owns a different project" is a team agreement, not something the system enforces.
- **No individual identity**: each code-server has only the one password set when it starts. There are no accounts, so you cannot tell who performed an action. It is served over HTTP by default, so add TLS and access control yourself before exposing it.
- **Everyone affects everyone**: if one project uses up the resources, or someone runs `kde stop` or `kde reset`, everybody is interrupted.
- **One project is not meant for several people editing at once**: each project has a single working directory and a single Git identity.

**Claude seats**

Claude's login is stored in each code-server's home, so it follows the project, not the person. Seats on a Team plan follow the person, so decide which of these you want first:

- **One code-server per person, each signed in with their own seat**: usage and history map to people. Shared project context lives in the repo's `CLAUDE.md` and `.claude/`, so it is still shared across people.
- **One code-server per project, with one seat assigned to it**: closest to "the project's shared Claude", but you cannot tell who asked, and everyone draws on the same usage limit. Check that this fits the rules of your plan before adopting it.

This setup suits a small team whose members trust each other and that runs it on an internal network. If you need individual sign-in and access control, use the one-local-cluster-per-person model instead.


## ✨ Core Features

### 🔄 Environment Consistency
- Simulate production environments through Kind/K3D development environments
- Connect to existing Kubernetes environments via kubeconfig
- Use the same deployment methods and YAML as production to launch development environments, ensuring environment consistency
- All tools run inside containers, ensuring environment consistency

**💡 Core Value**: Eliminate "works on my machine" problems, fully align development and production environments, and identify environment-related issues early.

### 🧑‍💻 Real-time Development Inside Kubernetes Environment
- Development environments (Kind/K3D) mount local code via PVC, enabling real-time sync and Hot Reload
- Intercept remote Kubernetes traffic to local development containers via Telepresence, with code mounted via volume for real-time sync and Hot Reload

**💡 Core Value**: Develop in real Kubernetes environments, see code changes immediately without rebuilding images, dramatically accelerating development iteration speed.

### 🔒 Project Isolation
- Each project corresponds to an independent Kubernetes Namespace with complete resource isolation, allowing simultaneous development of multiple projects without interference
- Development containers are isolated from each other, allowing simultaneous development of multiple projects without interference
- Environment variable isolation: Each project's configuration and environment variables do not affect each other

**💡 Core Value**: Parallel multi-project development without conflicts, complete isolation of resources and configurations, making team collaboration safer and more efficient.

### 📦 Version Controllable, Shareable, Portable
- Configuration files can be version controlled
  - Environment configuration (`k8s.env`)
  - Project configuration (`project.env`)
  - CI/CD Pipeline scripts & execution environment image configuration (`*.sh` & `project.env`)
  - Development tool version configuration (`kde.env`)
- Project folders can be migrated or copied to other environments: Copy the project folder (including `project.env` and all scripts) to `namespaces/` in a different environment to quickly start services with the same configuration and workflow in the new environment without reconfiguration
- Quickly sync and migrate development workspaces across different computers via GitHub/GitLab
- Team members can quickly replicate the same development workspace
- Rapid onboarding for new members

**💡 Core Value**: Environment as Code, team members launch identical environments with one command, onboarding time reduced from days to minutes.

### 🚀 Script-Driven CI/CD Pipeline
- Define CI/CD workflows using Shell Scripts
- Customize pipeline stages and execution environments
- Support manual mode for development and debugging
- Flexible error handling mechanism

**💡 Core Value**: Develop and test CI/CD workflows locally, ensure workflow correctness before deploying to remote CI/CD systems, dramatically reducing trial-and-error costs.

### 🐳 Container First
- Only Docker installation needed to execute all functions
- All tools run inside containers
- Avoid polluting the local environment
- Ensure environment consistency

**💡 Core Value**: Zero environment configuration, only Docker needed to execute all functions, team members use the same tool versions, avoiding version conflicts.

### 🎯 Unified Tool Entry Point
Integrates 9+ Kubernetes development tools into a unified CLI interface, automatically handles tool-to-K8s environment connections, reducing the learning curve:

```bash
kde start               # Create/start/connect environment (Kind/K3D/K8s)
kde k9s                 # Launch K9s terminal management tool
kde headlamp            # Launch Headlamp Web UI
kde telepresence        # Launch Telepresence traffic interception
kde code-server         # Launch VSCode Web IDE
kde openclaw            # Launch OpenClaw AI agent (container-based, DooD)
kde cloudflare-tunnel   # Launch Cloudflare Tunnel
kde ngrok               # Launch Ngrok external connection
kde expose              # Port Forward
```

**💡 Core Value**: Complete all operations with one command set, tools automatically connect to the current environment, developers only need to focus on development without learning installation and configuration of multiple tools.

## 🎯 Target Audience

### Organization
- Want to align development and production environments
- Need to manage multiple environments and projects
- Need to standardize development workflows and version control environment configurations
- Teams want to maintain environment consistency
- Need rapid onboarding (one-click environment startup)
- Want to test CI/CD workflows and validate K8s configurations in development environments

### Project
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
curl -fsSL https://raw.githubusercontent.com/r82wei/KDE-cli/refs/heads/main/install.sh | sudo bash

# Or using wget (requires sudo permissions)
wget -qO- https://raw.githubusercontent.com/r82wei/KDE-cli/refs/heads/main/install.sh | sudo bash

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

#### Method 3: No Installation — Browser IDE via Docker (code-server)

If you don't want to install anything on the host, run the `kde-code-server` image
directly. It's a browser-based VSCode (code-server) with `kde-cli` **pre-installed**,
so you get the full `kde` toolchain inside the IDE with only Docker on the host.

```bash
# Create a workspace directory (used for your code and the IDE's config)
mkdir -p kde-workspace/.code-server && cd kde-workspace

docker run -it --rm \
  --name kde-code-server \
  -p 8080:8080 \
  -e PASSWORD=changeme \
  --group-add "$(stat -c '%g' /var/run/docker.sock)" \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v "$PWD:$PWD" -w "$PWD" \
  -v "$PWD/.code-server:/home/coder" \
  -u "$(id -u):$(id -g)" \
  -e DOCKER_USER="$USER" \
  r82wei/kde-code-server:latest \
  "$PWD"
```

Then open <http://localhost:8080> (password: `changeme`). In the IDE terminal,
`kde` is ready to use:

```bash
kde --version
```

> **Note**: The image bundles Docker CLI and mounts the host's Docker socket, so
> `kde` can create environments and run pipelines from inside the IDE (Docker outside
> of Docker). If you already have `kde-cli` installed on the host, prefer
> `kde code-server` instead — it mounts your host's `kde-cli` into the container so the
> version always matches.

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
| | OpenClaw | Container-based OpenClaw AI agent with DooD access to the host |
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
- **[OpenClaw](./docs/core/dev-tools/openclaw.md)** - Container-based OpenClaw AI agent
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

# Select project and enter container development environment
# Develop in container, remote traffic directed to container
npm run dev
```

### Example 4: Migrate Projects to Other Environments for Quick Deployment

```bash
# Scenario: Quickly copy a project from dev environment to test environment

# 1. Project already configured in development environment
kde use dev-env
kde proj list
# Output: myapp (with project.env and all scripts configured)

# 2. Copy project folder to test environment
cp -r environments/dev-env/namespaces/myapp environments/test-env/namespaces/myapp

# 3. Modify environment variables for test environment
vi environments/test-env/namespaces/myapp/project.env

# 4. Switch to test environment and deploy
kde use test-env
kde proj pipeline myapp
# Use the same configuration and workflow to quickly start services in test environment

# 5. Can also use Git version control for synchronization
git add . && git commit -m "Add myapp configuration"
git push
```

**Core Advantages**:
- ✅ Project folder contains all CI/CD configurations
- ✅ All scripts (build.sh, deploy.sh, etc.) migrate together
- ✅ No need to reconfigure, ensuring multi-environment consistency
- ✅ Suitable for rapid expansion to multiple environments (dev → test → staging → prod)

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
