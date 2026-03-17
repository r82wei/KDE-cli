# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KDE-CLI (Kubernetes Development Environment) is a pure Bash CLI tool for managing Kubernetes development environments with integrated CI/CD pipelines. It consolidates environment management, project lifecycle, and script-driven pipelines into a unified interface. Version: v1.0.0-rc.6.

**Primary language**: Bash (100% shell scripts). **Only host dependency**: Docker.

## Installation & Running

```bash
# Local install (creates symlink at /usr/bin/kde -> /usr/local/lib/kde/kde.sh)
sudo ./local-install.sh

# Or run via Docker
./run.sh

# Uninstall
./uninstall.sh
```

## Testing

```bash
# Individual test scripts in test/ directory
bash test/test-pipeline-args.sh
bash test/test-exec-integration.sh
bash test/test-allow-failure.sh
bash test/test-only-manual.sh
```

Note: `test.sh` at root is a manual scratch/debug script, not a test runner. The actual tests are in `test/`. Tests use custom Bash assertions (no external framework). Tests require a running KDE workspace with environments configured.

## Architecture

### Entry Point & Command Routing

`kde.sh` is the main entry point. It sets up path variables (KDE_CLI_PATH, KDE_PATH, KDE_SCRIPTS_PATH, etc.) by walking up from CWD to find `kde.env`, then routes commands to `scripts/<command>/command.sh`.

### Three Core Components

1. **Environment Management** (`scripts/utils/environment/`) - Manages Kind, K3D, and external K8s clusters. Each environment lives in `environments/<env_name>/` with `k8s.env` config.
2. **Project Management** (`scripts/utils/project.sh`) - Projects map 1:1 to K8s namespaces, stored in `environments/<env>/namespaces/<project>/`.
3. **Pipeline System** (`scripts/utils/pipeline.sh`, 642 lines) - Script-driven CI/CD executing stages in Docker containers. Stages defined in `project.env` via `KDE_PIPELINE_STAGE_<name>_*` variables.

### Script Organization

- `scripts/<command>/command.sh` - One file per CLI command (start, stop, project, sandbox, etc.)
- `scripts/utils/` - Shared utilities sourced by commands
- `scripts/utils/environment/` - Environment backends (kind.sh, k3d.sh, k8s.sh)
- `scripts/utils/sandbox/lima.sh` - Lima VM backend for sandbox feature
- `dockerfiles/` - 8 Dockerfile definitions for containerized tools

### Configuration Hierarchy (load order)

1. `${KDE_PATH}/kde.env` - Global workspace config (version controlled)
2. `environments/<env>/k8s.env` - Environment config (version controlled)
3. `environments/<env>/.env` - Local env secrets (NOT version controlled)
4. `namespaces/<proj>/project.env` - Project config (version controlled)
5. `namespaces/<proj>/.env` - Local project secrets (NOT version controlled)
6. `namespaces/<proj>/.pipeline.env` - Auto-generated inter-stage variables

### Key Patterns

- All scripts use `set -eo pipefail`
- Functions follow naming: `is_*()` for predicates, `create_*()`, `start_*()`, `stop_*()`, `load_*()` for actions
- Dynamic variable access via `${!VAR_NAME}` (indirect expansion) for pipeline stage configs
- Tools run in Docker containers (DooD pattern via Docker socket mount)
- Debug mode: `KDE_DEBUG=true kde <command>`

## Language

Code comments and UI strings are in Traditional Chinese (zh-TW). Documentation exists in both English and Chinese.

## Active Development

Current branch `main-features/sandbox-lima` is developing the Lima-based microVM sandbox feature (`scripts/sandbox/command.sh`, `scripts/utils/sandbox/lima.sh`, `templates/lima/`).
