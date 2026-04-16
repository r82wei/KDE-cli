# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KDE-CLI (Kubernetes Development Environment CLI) is a unified Kubernetes development environment management tool written entirely in Bash. It integrates environment creation, project management, a container-based CI/CD pipeline system, and development tools (K9s, Headlamp, code-server, Telepresence, etc.) into a single `kde` command. Version: `ay-v1.0.0-rc.6`.

Only Docker is required on the host; all tools run inside containers.

## Installation & Running

```bash
# Local install (copies to /usr/local/lib/kde, symlinks /usr/local/bin/kde)
source ./local-install.sh

# Entry point
kde <command>
```

There is no build step, no package manager, and no compilation. The project is pure Bash.

## Testing

Tests are standalone Bash scripts in `test/`:

```bash
bash test/test-pipeline-args.sh      # Pipeline argument parsing
bash test/test-allow-failure.sh      # Allow-failure stage behavior
bash test/test-only-manual.sh        # Manual-only stage behavior
bash test/test-exec-integration.sh   # Integration tests
```

`test.sh` at the root is a manual scratch harness (not a test runner).

## Architecture

### Three Core Components

1. **Environment Management** - Creates/manages isolated K8s clusters (Kind, K3D, or external K8s)
2. **Project Management** - Full project lifecycle within environments (create, fetch, deploy, undeploy)
3. **Pipeline System** - Script-driven CI/CD where each stage runs in its own Docker container

### Code Layout

- `kde.sh` - Main entry point and command router
- `scripts/<command>/command.sh` - Each CLI subcommand is a separate script
- `scripts/utils/` - Shared utility functions (pipeline engine, project helpers, K8s operations)
- `scripts/utils/environment/` - Environment-type-specific logic (kind.sh, k3d.sh, k8s.sh)
- `dockerfiles/` - Dockerfiles for all integrated tools
- `templates/init/` - Project initialization templates
- `examples/` - Example projects with pipeline configurations
- `docs/` - Documentation in Traditional Chinese and English

### Workspace Directory Structure (runtime, not in repo)

```
<workspace>/
├── kde.env                          # Workspace-wide config (versioned)
├── .env                             # Local overrides (gitignored)
├── current.env                      # Tracks active environment (gitignored)
└── environments/<env_name>/
    ├── k8s.env                      # Environment metadata (versioned)
    ├── .env                         # Environment local config (gitignored)
    ├── kubeconfig/config            # K8s connection config
    ├── init.sh                      # Environment init script
    └── namespaces/<project_name>/
        ├── project.env              # Project config with pipeline stages (versioned)
        ├── .env                     # Project local config (gitignored)
        ├── .pipeline.env            # Inter-stage variable passing
        ├── build.sh, deploy.sh ...  # Pipeline stage scripts
        └── <repo>/                  # Git repository
```

### Environment Variable Loading Order

Variables are sourced hierarchically (later overrides earlier):
1. `kde.env` (workspace-wide)
2. `environments/<env>/k8s.env` (environment config)
3. `environments/<env>/.env` (environment local)
4. `namespaces/<project>/project.env` (project config)
5. `namespaces/<project>/.env` (project local)
6. `namespaces/<project>/.pipeline.env` (pipeline inter-stage)

### Development Patterns

**Hot Reload (Kind + volume mount)** — the typical local dev workflow:
When using Kind with local-path storage, the project directory is volume-mounted into the
pod. The app runs with a file watcher (nodemon, air, watchexec, etc.). Editing code on the
host auto-restarts the app inside the pod — **no redeploy needed**. Use `kde proj tail`
to confirm the watcher picked up the change.

**Pipeline redeploy** — use when changing Docker image, K8s manifests, or env vars:
`kde proj redeploy <project>`

### Pipeline System

Configured in `project.env`. Each stage runs in a Docker container:

```bash
KDE_PIPELINE_STAGES="build,test,deploy"
KDE_PIPELINE_STAGE_build_IMAGE=node:20
KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
KDE_PIPELINE_STAGE_test_ALLOW_FAILURE=true
KDE_PIPELINE_STAGE_deploy_MANUAL_ONLY=true
```

Stage-level options: `_IMAGE`, `_SCRIPT`, `_WORKDIR`, `_SKIP`, `_MANUAL_ONLY`, `_ALLOW_FAILURE`, `_PAUSE`, `_MOUNT_*`.

Pipeline execution flags: `--only <stage>`, `--from <stage>`, `--to <stage>`, `--manual`, `--shell`.

## Bash Conventions

- All scripts use `set -eo pipefail`
- Functions use snake_case with descriptive prefixes: `is_*()` returns "true"/"false" strings, `get_*()` returns values, `create_*()` / `start_*()` / `stop_*()` for actions
- Code comments and user-facing messages are in Traditional Chinese (繁體中文)
- Debug mode: set `KDE_DEBUG=true` in kde.env to enable `set -x`
- Container execution uses DooD (Docker outside of Docker) pattern

## Key Files for Common Tasks

- Adding a new CLI command: create `scripts/<command>/command.sh` and add routing in `kde.sh`
- Modifying pipeline behavior: `scripts/utils/pipeline.sh`
- K8s operations: `scripts/utils/environment/k8s.sh` (~600 lines of kubectl wrappers)
- Project operations: `scripts/utils/project.sh` and `scripts/project/command.sh`

## Updating Documentation

When modifying CLI behavior, flags, or pipeline features, update **all** of the following:
- `docs/core/cicd-pipeline.md` — user-facing documentation
- `docs/core/quick-reference.md` — user-facing quick reference
- `.claude/skills/kde-usage/SKILL.md` — skill used by Claude Code (project-local, NOT the installed copy under `~/.claude/skills/`)
- `.claude/skills/kde-usage/references/quick-reference.md` — quick reference in the same skill

**Rule**: Any change to `docs/` that affects how the `kde` command is used (commands, flags, behavior, workflows) must also be reflected in the corresponding skill files under `.claude/skills/kde-usage/`.
