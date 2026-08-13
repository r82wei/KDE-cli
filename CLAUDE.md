# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KDE-CLI (Kubernetes Development Environment CLI) is a unified Kubernetes development environment management tool written entirely in Bash. It integrates environment creation, project management, a container-based CI/CD pipeline system, and development tools (K9s, Headlamp, code-server, Telepresence, etc.) into a single `kde` command.

Only Docker is required on the host; all tools run inside containers.

## Installation & Running

```bash
# Local install — writes to /usr/local/lib/kde and symlinks /usr/local/bin/kde,
# so it needs write access to /usr/local (usually sudo).
bash ./local-install.sh

# Entry point
kde <command>
```

There is no build step, no package manager, and no compilation for the CLI itself —
it is pure Bash. (`dockerfiles/*/build.sh` and `release.sh` do build container images,
but those are released separately and are not part of running the CLI.)

## Testing

Tests are standalone Bash scripts in `test/`. Run one with `bash test/<name>.sh`;
each prints its own pass/fail summary and exits non-zero on failure.

**Several tests need `KDE_SCRIPTS_PATH` exported first**, or they fail with
`/utils/...: No such file or directory` — that is a missing variable, not a real
failure: `test-allow-failure.sh`, `test-only-manual.sh`, `test-kind-config-env.sh`,
`cloudflare.sh`.

```bash
export KDE_SCRIPTS_PATH="$PWD/scripts"   # needed by the four tests listed above
for t in test/test-*.sh; do bash "$t"; done
```

Current tests, grouped by what they cover:

| Area | Tests |
|---|---|
| Pipeline | `test-pipeline-args.sh`, `test-allow-failure.sh`, `test-only-manual.sh` |
| Non-interactive execution | `test-exec-no-tty.sh`, `test-pod-exec-args.sh`, `test-proj-exec-volumes.sh`, `test-exec-integration.sh` |
| code-server | `test-code-server-mounts.sh`, `test-code-server-agent-args.sh`, `test-agent-entrypoint.sh`, `test-install-scripts.sh` |
| Environment | `test-kind-config-env.sh` |

`test.sh` and `test/cloudflare.sh` are manual scratch harnesses, not test runners.

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
- `docs/core/` - User-facing docs; `dev-tools/` has one file per integrated tool
- `.claude/skills/kde-usage/` - Skill Claude Code loads when operating the `kde` command

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

Stage-level options (the complete set read by `scripts/utils/pipeline.sh`):
`_IMAGE`, `_SCRIPT`, `_WORKDIR`, `_SKIP`, `_MANUAL_ONLY`, `_ALLOW_FAILURE`, `_PAUSE`.

Pipeline execution flags: `--only <stage>`, `--from <stage>`, `--to <stage>`,
`-m`/`--manual`, `-s`/`--shell`, `--no-tty`.

## Bash Conventions

- `kde.sh` and everything under `scripts/` use `set -eo pipefail`. Build/release
  helpers under `dockerfiles/` and the installer scripts do not, and a few container
  entrypoints omit `set -e` **deliberately** — read the file's header comment before
  "fixing" one. (`dockerfiles/code-server/entrypoint.d/10-ai-agents.sh` is the current
  example: adding `set -e` there would abort the loop on the first failing agent, and
  a non-zero exit is deliberately never propagated.)
- Functions use snake_case with descriptive prefixes: `is_*()` returns "true"/"false" strings, `get_*()` returns values, `create_*()` / `start_*()` / `stop_*()` for actions
- Code comments and user-facing messages are in Traditional Chinese (繁體中文)
- Debug mode: set `KDE_DEBUG` in kde.env to anything other than `false` to enable `set -x`
- Container execution uses DooD (Docker outside of Docker) pattern

## Key Files for Common Tasks

- Adding a new CLI command: create `scripts/<command>/command.sh` and add routing in `kde.sh`
- Modifying pipeline behavior: `scripts/utils/pipeline.sh`
- K8s operations: `scripts/utils/environment/k8s.sh` (the kubectl wrappers; the largest file in the repo)
- Project operations: `scripts/utils/project.sh` and `scripts/project/command.sh`

## Updating Documentation

When modifying CLI behavior, flags, or pipeline features, update **all** of the following:
- `docs/core/quick-reference.md` — user-facing quick reference
- `docs/core/cicd-pipeline.md` — when the change touches the pipeline
- `docs/core/dev-tools/<tool>.md` — **the canonical per-flag reference for each integrated
  tool** (`code-server.md`, `k9s.md`, `telepresence.md`, …). Easy to miss: a flag added to
  `kde code-server` belongs in `dev-tools/code-server.md`, not only in the quick reference.
- `kde.sh`'s `show_help()` — the top-level one-line summary per command
- `.claude/skills/kde-usage/SKILL.md` — skill used by Claude Code (project-local, NOT the installed copy under `~/.claude/skills/`)
- `.claude/skills/kde-usage/references/quick-reference.md` — quick reference in the same skill

The two quick-reference files are near-duplicates and are meant to stay in sync — edit both
in the same change. They have drifted before, so when you touch one, diff it against the
other rather than assuming they still match.

**Rule**: Any change to `docs/` that affects how the `kde` command is used (commands, flags, behavior, workflows) must also be reflected in the corresponding skill files under `.claude/skills/kde-usage/`.
