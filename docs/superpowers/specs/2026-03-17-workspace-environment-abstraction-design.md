# KDE-CLI Architecture Abstraction: Workspace + Environment Layer

## Summary

Refactor KDE-CLI from a K8s-focused CLI into a backend-agnostic development environment platform by introducing two abstraction layers:

1. **Workspace** — any environment that can run KDE-CLI (local folder, Lima VM, remote VM, DinD, PVE, ESXi, ...)
2. **Environment** — infrastructure inside a workspace, split into **type** (what it produces) and **backend** (how it's created)

This abstraction enables KDE-CLI to serve as an AI agent playground: users get isolated workspaces with pre-installed AI runtimes (Claude Code, Codex, etc.), and can create any type of infrastructure inside to develop, test, and deploy.

## Goals

- Abstract workspace and environment layers with pluggable backends
- Maintain pure Bash implementation
- Preserve backward compatibility with existing Kind/K3D/K8s workflows
- Enable multi-tenant isolation (multiple workspaces on one host for different users)
- Support AI coding agents running inside workspaces with full dev-to-deploy capability

## Non-Goals

- Agent lifecycle management (users manage their own agent processes)
- Task queue or agent orchestration
- Inter-agent communication
- Billing or API layer (deferred to future work)

---

## Architecture

```
Host (physical / cloud VM / any machine)
│
│  KDE-CLI manages multiple workspaces (multi-tenant)
│
├── Workspace A (User A) ─── backend: lima | ssh | dind | pve | esxi | local | ...
│   │
│   │  KDE-CLI runs inside the workspace
│   │
│   ├── environments/
│   │   ├── dev-env/
│   │   │   ├── environment.env        # TYPE=k8s, BACKEND=kind
│   │   │   └── namespaces/
│   │   │       └── my-app/            # project: git + pipeline
│   │   ├── gpu-worker/
│   │   │   └── environment.env        # TYPE=vm, BACKEND=terraform-vm
│   │   └── quick-test/
│   │       └── environment.env        # TYPE=container, BACKEND=docker
│   │
│   ├── kde.env
│   └── (users run AI agents themselves, KDE-CLI does not manage them)
│
├── Workspace B (User B) ─── backend: lima
│   └── ...
└── Workspace C (User C) ─── backend: ssh (remote VM)
    └── ...
```

---

## Layer 1: Workspace

### Definition

**Workspace = any environment that can run KDE-CLI.** KDE-CLI does not assume it created the workspace — it may already exist. The core assumption shifts from "I manage this machine" to "I work inside this machine."

### Interface

```bash
# Required — all backends must implement
workspace_connect()    # Connect to workspace (local=noop, lima=limactl shell, remote=ssh)
workspace_exec()       # Execute command inside workspace
workspace_status()     # Return status (reachable / unreachable)
workspace_info()       # Return basic info (IP, OS, resources)

# Optional — backends implement if capable
workspace_create()     # Create workspace
workspace_delete()     # Delete workspace
workspace_stop()       # Stop workspace
workspace_snapshot()   # Snapshot management
workspace_expose()     # Port forwarding
```

### Backends

| Backend | Description | workspace_exec() | Optional ops |
|---------|-------------|-------------------|--------------|
| `local` | Default. Just a folder on host | Direct execution | None |
| `lima` | Lima microVM (existing sandbox) | `limactl shell` | create, delete, stop, snapshot, expose |
| `ssh` | Remote VM (already exists) | `ssh user@host` | None |
| `dind` | Docker-in-Docker container | `docker exec` | create, delete, stop |
| `pve` | Proxmox VE VM | API + SSH | create, delete, stop, snapshot |
| `esxi` | ESXi VM | API + SSH | create, delete, stop, snapshot |
| `cloud-vm` | Cloud VM (AWS/GCP/Azure) | SSH | create, delete, stop |

### Configuration

```bash
# kde.env
KDE_WORKSPACE_BACKEND="local"      # Default: local (no VM)
```

### Dispatcher

```bash
# scripts/utils/workspace/workspace.sh
load_workspace_backend() {
    local backend="${KDE_WORKSPACE_BACKEND:-local}"

    source "${KDE_SCRIPTS_PATH}/utils/workspace/${backend}.sh"
}
```

### Directory Structure

```
scripts/utils/workspace/
├── workspace.sh        # Dispatcher
├── local.sh            # Backend: local folder (default, mostly noop)
├── lima.sh             # Backend: Lima VM (refactored from sandbox/lima.sh)
├── ssh.sh              # Backend: remote SSH
└── dind.sh             # Backend: Docker-in-Docker
```

---

## Layer 2: Environment

### Definition

An environment is infrastructure inside a workspace where projects are deployed. It has two dimensions:

- **Type**: what the environment produces (K8s cluster, VM, container, compose stack)
- **Backend**: how the environment is created (kind, terraform, ansible, docker, ...)

### Type Interfaces

#### Shared operations (all types must implement)

```bash
env_create()        # Create environment
env_start()         # Start environment
env_stop()          # Stop environment
env_delete()        # Delete environment
env_status()        # Return status
env_exec()          # Execute command inside environment
```

#### Type-specific operations

```bash
# type: k8s
env_k8s_load_kubeconfig()
env_k8s_create_namespace()
env_k8s_delete_namespace()

# type: vm
env_vm_ssh()
env_vm_info()

# type: container
env_container_logs()
env_container_attach()

# type: compose
env_compose_service_list()
env_compose_service_logs()
```

### Type-Backend Matrix

| Type | Backends |
|------|----------|
| `k8s` | `kind`, `k3d`, `k8s` (external), `terraform-k8s`, `ansible-k8s` |
| `vm` | `terraform-vm`, `ansible-vm` |
| `container` | `docker` |
| `compose` | `docker-compose` |

### Configuration

```bash
# environments/<env-name>/environment.env
KDE_ENVIRONMENT_TYPE="k8s"
KDE_ENVIRONMENT_BACKEND="kind"
```

### Dispatcher

```bash
# scripts/utils/environment/environment.sh
load_environment() {
    local type="${KDE_ENVIRONMENT_TYPE}"
    local backend="${KDE_ENVIRONMENT_BACKEND}"

    source "${KDE_SCRIPTS_PATH}/utils/environment/backends/${backend}.sh"
    source "${KDE_SCRIPTS_PATH}/utils/environment/types/${type}.sh"
}
```

Backend implements the shared operations (`env_create`, `env_start`, etc.). Type layer sources the backend and adds type-specific operations on top.

### Directory Structure

```
scripts/utils/environment/
├── environment.sh          # Dispatcher (type + backend)
├── types/
│   ├── k8s.sh             # K8s operation set
│   ├── vm.sh              # VM operation set
│   ├── container.sh       # Container operation set
│   └── compose.sh         # Compose operation set
└── backends/
    ├── kind.sh            # Existing, refactored
    ├── k3d.sh             # Existing, refactored
    ├── k8s.sh             # Existing, refactored
    ├── terraform-k8s.sh   # New
    ├── terraform-vm.sh    # New
    ├── ansible-k8s.sh     # New
    ├── ansible-vm.sh      # New
    ├── docker.sh          # New
    └── docker-compose.sh  # New
```

---

## Layer 3: Project (Unchanged)

Project = git repo + `project.env` + pipeline scripts. The existing abstraction is sufficient. Projects live inside environment namespaces and execute pipeline stages in containers.

---

## AI Agent Playground

No dedicated agent layer is needed. The playground is achieved through:

1. **Workspace isolation** — each user gets their own workspace (VM/container/remote)
2. **Pre-installed AI runtimes** — workspace provisioning templates install Claude Code, Codex, etc.
3. **Full capability inside workspace** — agent processes can use Docker, K8s, deploy services
4. **User autonomy** — users start/stop agents themselves, KDE-CLI manages infrastructure only
5. **Collaboration** — users attach to agent sessions via `workspace_exec --tmux`

### Multi-Tenant Model

One host runs KDE-CLI to manage multiple workspaces for different users. Each workspace is an isolated environment (VM, container, or remote machine). Users cannot access each other's workspaces.

---

## Migration from Current Codebase

| # | Work Item | Type | Description |
|---|-----------|------|-------------|
| 1 | Define workspace interface + dispatcher | New | `scripts/utils/workspace/workspace.sh` |
| 2 | Refactor `sandbox/lima.sh` → `workspace/lima.sh` | Refactor | Rename functions to `workspace_*` convention |
| 3 | Implement `workspace/local.sh` | New | Thin backend, most operations are noop or direct exec |
| 4 | Define environment type interfaces | New | `scripts/utils/environment/types/*.sh` |
| 5 | Define environment backend interface | New | Standardize function signatures |
| 6 | Move `kind.sh`, `k3d.sh`, `k8s.sh` to `backends/` | Refactor | Unify function naming to `env_*` convention |
| 7 | Extract K8s shared logic to `types/k8s.sh` | Refactor | Kubeconfig, namespace ops shared across K8s backends |
| 8 | Create `scripts/workspace/command.sh` CLI command | New | `kde workspace create\|start\|stop\|exec\|...` |
| 9 | Update `kde.sh` routing | Modify | Add workspace command, update environment routing |
| 10 | Workspace provision templates with AI runtimes | New | Pre-install Claude Code, Codex in Lima/VM templates |

### Recommended Order

**Phase 1**: Workspace abstraction (items 1-3, 8-9) — enables multi-backend workspace management
**Phase 2**: Environment abstraction (items 4-7) — enables multi-type, multi-backend environments
**Phase 3**: AI runtime provisioning (item 10) — completes the agent playground story

---

## Key Design Decisions

1. **Pure Bash** — no language change, use convention over enforcement for interfaces
2. **Directory = registry** — backends are discovered by file existence, no explicit registration
3. **Local is default** — `KDE_WORKSPACE_BACKEND=local` means workspace is just a folder, no VM overhead
4. **Workspace is passive** — KDE-CLI doesn't assume it created the workspace; it connects to whatever exists
5. **Agent management is out of scope** — users run agents themselves, KDE-CLI provides the environment
6. **Backward compatible** — existing `kde start dev-env kind` workflows continue to work
