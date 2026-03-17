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
│   │   │   ├── environment.env        # TYPE=k8s, BACKEND=kind (version controlled)
│   │   │   ├── .env                   # Local secrets (NOT version controlled)
│   │   │   └── namespaces/
│   │   │       └── my-app/
│   │   │           ├── project.env    # Project config (version controlled)
│   │   │           └── .env           # Local secrets (NOT version controlled)
│   │   ├── gpu-worker/
│   │   │   ├── environment.env        # TYPE=vm, BACKEND=terraform-vm
│   │   │   └── .env
│   │   └── quick-test/
│   │       ├── environment.env        # TYPE=container, BACKEND=docker
│   │       └── .env
│   │
│   ├── workspace.env                  # Workspace config (version controlled)
│   ├── .env                           # Local secrets (NOT version controlled)
│   └── (users run AI agents themselves, KDE-CLI does not manage them)
│
├── Workspace B (User B) ─── backend: lima
│   └── ...
└── Workspace C (User C) ─── backend: ssh (remote VM)
    └── ...
```

---

## Execution Model: Host vs. Guest

KDE-CLI operates in two contexts:

1. **Guest mode** (default): KDE-CLI runs inside a workspace, managing environments and projects. It does not know or care whether it's on bare metal, a VM, or a container. This is the normal user-facing mode.
2. **Host mode**: KDE-CLI runs on a host machine to manage multiple workspaces for different users (multi-tenant). Host mode only uses workspace commands (`kde workspace create/start/stop/exec/...`).

Detection: if `KDE_WORKSPACE_BACKEND` is set to a non-local backend and `kde workspace` commands are used, KDE-CLI is in host mode. Otherwise it's in guest mode. Workspaces do not nest — a workspace cannot create sub-workspaces.

KDE-CLI installation inside workspaces is handled by the workspace backend's provisioning step (e.g., Lima template mounts or installs KDE-CLI; SSH backend assumes KDE-CLI is already installed; DinD backend includes it in the image).

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
workspace_info()       # Print key=value pairs to stdout (IP, OS, CPUS, MEMORY)

# Optional — backends implement if capable
workspace_create()     # Create workspace
workspace_start()      # Start a stopped workspace
workspace_delete()     # Delete workspace
workspace_stop()       # Stop workspace (resumable)
workspace_snapshot()   # Snapshot management
workspace_expose()     # Port forwarding
```

**Optional operation handling:** Unimplemented optional functions are defined as stubs by the dispatcher that print `"Operation not supported by backend: ${KDE_WORKSPACE_BACKEND}"` and return 1. The CLI layer can check capability before showing commands via `workspace_supports <operation>`, which tests whether the function has been overridden from the stub.

### Provisioning Hooks

When a non-local workspace starts (via `workspace_create` or `workspace_start`), KDE-CLI automatically executes provisioning scripts if they exist. This replaces hardcoded provisioning logic (like the current Lima template).

```
<workspace_path>/
├── hooks/
│   ├── workspace-init.sh          # Runs on first create only
│   └── workspace-start.sh         # Runs on every start
```

Each hook script declares its execution mode in a comment header:

```bash
#!/bin/bash
# KDE_HOOK_EXEC_MODE=direct        # Execute directly inside workspace (default)
# KDE_HOOK_EXEC_MODE=container      # Execute inside a container (requires KDE_HOOK_IMAGE)
# KDE_HOOK_IMAGE=ubuntu:24.04       # Container image (only for container mode)

# Install AI runtimes, dev tools, etc.
apt-get update && apt-get install -y nodejs
npm install -g @anthropic-ai/claude-code
```

**Execution modes:**

| Mode | Behavior | Use case |
|------|----------|----------|
| `direct` | `workspace_exec` runs the script inside the workspace | Install packages, configure system |
| `container` | Script runs in a Docker container inside the workspace, with workspace filesystem mounted | Hermetic builds, tools that need specific OS/deps |

**Execution order:**
1. `workspace-init.sh` — runs once after `workspace_create`. A marker file (`.workspace-initialized`) prevents re-runs.
2. `workspace-start.sh` — runs on every `workspace_start` (including after create).

### Backends

| Backend | Description | workspace_exec() | Optional ops |
|---------|-------------|-------------------|--------------|
| `local` | Default. Just a folder on host | Runs in a subshell with workspace env vars sourced | None |
| `lima` | Lima microVM (existing sandbox) | `limactl shell` | create, delete, stop, snapshot, expose |
| `ssh` | Remote VM (already exists) | `ssh user@host` | None |
| `dind` | Docker-in-Docker container | `docker exec` | create, delete, stop |
| `pve` | Proxmox VE VM | API + SSH | create, delete, stop, snapshot |
| `esxi` | ESXi VM | API + SSH | create, delete, stop, snapshot |
| `cloud-vm` | Cloud VM (AWS/GCP/Azure) | SSH | create, delete, stop |
| `custom` | User-defined backend | Defined by user scripts | Defined by user scripts |

### Custom Backend

When `KDE_WORKSPACE_BACKEND="custom"`, the dispatcher does not load a built-in backend file. Instead, it sources user-provided scripts from the workspace directory:

```
<workspace_path>/
├── backend/
│   └── workspace.sh       # User implements workspace_* functions here
├── workspace.env
└── ...
```

The user implements whichever `workspace_*` functions they need in `backend/workspace.sh`. For example, a Terraform-based workspace:

```bash
# backend/workspace.sh
workspace_create() {
    cd "${KDE_PATH}/backend"
    terraform init && terraform apply -auto-approve
}

workspace_exec() {
    local ip=$(terraform -chdir="${KDE_PATH}/backend" output -raw ip)
    ssh "user@${ip}" "$@"
}

workspace_status() {
    terraform -chdir="${KDE_PATH}/backend" output -raw status 2>/dev/null && echo "reachable" || echo "unreachable"
}

workspace_delete() {
    cd "${KDE_PATH}/backend"
    terraform destroy -auto-approve
}
```

The dispatcher loads it the same way:

```bash
load_workspace_backend() {
    local backend="${KDE_WORKSPACE_BACKEND:-local}"

    if [[ "$backend" == "custom" ]]; then
        source "${KDE_PATH}/backend/workspace.sh"
    else
        source "${KDE_SCRIPTS_PATH}/utils/workspace/${backend}.sh"
    fi
}
```

This allows users to integrate any infrastructure (Terraform, Pulumi, Vagrant, cloud APIs, internal tools) without forking KDE-CLI.

### Configuration

```bash
# workspace.env (version controlled)
KDE_WORKSPACE_BACKEND="local"      # Default: local (no VM)

# .env (NOT version controlled, gitignored)
# Local secrets, API keys, credentials
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
```

Note: `env_exec()` is type-specific, not shared. What "exec into" means differs fundamentally by type (K8s: exec into node container; VM: SSH; container: docker exec; compose: exec into a service). Each type defines its own exec semantics.

#### Type-specific operations

```bash
# type: k8s
env_k8s_exec()                  # exec into K8s node container
env_k8s_load_kubeconfig()
env_k8s_create_namespace()
env_k8s_delete_namespace()

# type: vm
env_vm_exec()                   # SSH into VM
env_vm_info()

# type: container
env_container_exec()            # docker exec into container
env_container_logs()
env_container_attach()

# type: compose
env_compose_exec()              # exec into a compose service
env_compose_service_list()
env_compose_service_logs()
```

### Provisioning Hooks

Environments also support provisioning hooks, following the same pattern as workspace hooks.

```
environments/<env-name>/
├── hooks/
│   ├── env-init.sh                # Runs on first create only
│   └── env-start.sh               # Runs on every start
├── environment.env
└── namespaces/
```

Same execution mode header as workspace hooks:

```bash
#!/bin/bash
# KDE_HOOK_EXEC_MODE=direct        # Execute directly inside the environment (default)
# KDE_HOOK_EXEC_MODE=container      # Execute inside a container
# KDE_HOOK_IMAGE=deploy-env:latest  # Container image (only for container mode)

# Example: install CRDs, configure cluster add-ons
kubectl apply -f https://raw.githubusercontent.com/...
```

**Context differences from workspace hooks:**
- `direct` mode uses `env_<type>_exec()` (e.g., exec into K8s node, SSH into VM) rather than `workspace_exec()`
- `container` mode runs a container with the environment's credentials mounted (e.g., kubeconfig for K8s type)
- Environment hooks run after the environment is up and healthy (`env_status` returns running)

**Execution order:**
1. `env-init.sh` — runs once after `env_create`. Marker file: `.env-initialized`.
2. `env-start.sh` — runs on every `env_start` (including after create).

### Type-Backend Matrix

| Type | Backends |
|------|----------|
| `k8s` | `kind`, `k3d`, `k8s` (external), `terraform-k8s`, `ansible-k8s` |
| `vm` | `terraform-vm`, `ansible-vm` |
| `container` | `docker` |
| `compose` | `docker-compose` |

### Configuration

```bash
# environments/<env-name>/environment.env (new format)
KDE_ENVIRONMENT_TYPE="k8s"
KDE_ENVIRONMENT_BACKEND="kind"
```

#### Backward Compatibility

Existing `kde.env` and `k8s.env` files continue to work. The config loader checks for the new names first, then falls back:
- `workspace.env` → fallback to `kde.env`
- `environment.env` → fallback to `k8s.env` with implicit `KDE_ENVIRONMENT_TYPE="k8s"`

No migration script needed — old format works indefinitely.

### Configuration Hierarchy (load order)

Each layer loads its versioned config first, then overlays local secrets:

```
1. workspace.env          → workspace config (version controlled)
2. .env                   → workspace secrets (NOT version controlled)
3. environment.env        → environment config (version controlled)
4. .env                   → environment secrets (NOT version controlled)
5. project.env            → project config (version controlled)
6. .env                   → project secrets (NOT version controlled)
7. .pipeline.env          → auto-generated inter-stage variables
```

Later values override earlier ones. The `.env` at each layer is for credentials, API keys, and machine-specific settings that should never enter version control.

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

**Loading order and responsibility split:**

1. Backend file is sourced first — it implements shared operations (`env_create`, `env_start`, etc.) using a `_backend_` prefix (e.g., `_backend_env_create()`).
2. Type file is sourced second — it wraps backend functions with type-specific logic and exposes the public `env_*` interface.

Example for K8s + Kind:
```bash
# backends/kind.sh defines: _backend_env_create(), _backend_env_start(), ...
# types/k8s.sh wraps them:
env_create() {
    _backend_env_create "$@"
    env_k8s_load_kubeconfig    # K8s-specific post-create step
}
```

This avoids Bash function name collisions and makes the responsibility clear: backends do the low-level work, types add the domain semantics.

The type file should validate that all required `_backend_*` functions exist after sourcing:
```bash
# types/k8s.sh (at the top)
for fn in _backend_env_create _backend_env_start _backend_env_stop _backend_env_delete _backend_env_status; do
    declare -f "$fn" > /dev/null || { echo "Backend missing required function: $fn"; exit 1; }
done
```

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

One host runs KDE-CLI to manage multiple workspaces for different users. Each workspace is an isolated environment (VM, container, or remote machine). Isolation is provided by the workspace backend itself (VM boundary, container boundary, or separate machine). User-to-workspace mapping and access control mechanisms are deferred to the platform API layer (future work) — the current scope focuses on the workspace lifecycle primitives that the platform layer will build upon.

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
