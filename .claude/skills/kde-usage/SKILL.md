---
name: kde-usage
description: >
  Guide for Claude on how to operate the KDE-CLI tool (the `kde` command).
  Trigger this skill whenever the user is working inside a KDE workspace (any directory
  containing or under a `kde.env` file) and asks you to perform any operation: creating
  or managing environments, deploying projects, running pipelines, checking logs, using
  dev tools (k9s, headlamp, code-server, expose, telepresence), or troubleshooting. Also
  trigger when the user says things like "start my environment", "deploy this project",
  "run the pipeline", "check the logs", "service didn't come up", "set up KDE", or any
  variant that implies operating the `kde` command — even if they don't say "KDE" explicitly.
---

# KDE-CLI Usage Guide

KDE-CLI (`kde`) is a Bash-based tool that wraps Kubernetes environment management,
project lifecycle, and a container-based CI/CD pipeline into a single command.
Only Docker is required on the host — everything runs inside containers.

## Step 1: Orient Yourself

Before acting, understand the current state. Run in parallel:

```bash
kde current        # what environment is active?
kde proj ls        # what projects exist?
```

If `kde.env` does not exist anywhere up the directory tree, the user needs to run
`kde init` first. Ask before proceeding.

## Step 2: Pick the Right Workflow

### Typical end-to-end workflow (first time setup)

```bash
kde start <env_name> [kind|k3d|k8s]   # create + start K8s environment
                                        # (no need to check if it exists first —
                                        #  if it doesn't exist, start creates it)
kde proj create <project_name>          # interactive: asks for git URL, images,
                                        # creates project.env + build.sh + deploy.sh
                                        # (includes git clone — no separate fetch needed)
# → review/edit project.env, build.sh, deploy.sh
kde proj deploy <project_name>          # run the pipeline
```

### Day-to-day: hot reload vs redeploy

**Kind + volume mount (hot reload mode)** — the most common local dev workflow:

When using Kind with local-path storage, the project directory is volume-mounted directly
into the pod. The application runs with a file watcher (e.g. nodemon, air, watchexec).
In this case, **editing code on the host is enough** — the pod detects the change and
restarts automatically. No redeploy needed.

```bash
# Just edit your code — the pod picks it up automatically.
# Use logs to confirm the watcher restarted:
kde proj tail <project_name>                            # interactive (human)
kde proj tail <project_name> <pod_name> --no-tty        # non-interactive (AI agent)
```

**Pipeline redeploy** — use when the image or deployment config changes:

```bash
kde proj pull <project_name>          # git pull latest code
kde proj redeploy <project_name>      # undeploy + run full pipeline (rebuild image etc.)
```

Use `redeploy` when: changing the Docker image, modifying K8s manifests, adding env vars,
or when the project is NOT set up with volume mounts.

### Pipeline with stage control

```bash
kde proj pipeline <project_name> --only build    # run only the build stage
kde proj pipeline <project_name> --from test     # run from test stage onwards
kde proj pipeline <project_name> --to test       # run up to test stage (skip deploy)
kde proj pipeline <project_name> --from build --to test   # run build + test only
kde proj pipeline <project_name> --manual        # also run MANUAL_ONLY stages (auto-execute scripts)
kde proj pipeline <project_name> --shell         # enter interactive shell per stage (for debugging, implies --manual)
kde proj pipeline <project_name> --only build --shell  # enter only the build stage's interactive environment
kde proj pipeline <project_name> --no-tty             # run without TTY (for AI agents / CI — no interactive prompts)
kde proj pipeline <project_name> --only build --no-tty  # single stage, no TTY
```

### Debugging a project that won't start / has errors

When a service was deployed but isn't running, work through these steps:

```bash
# 1. List pods (names only — use this to pick the right pod)
kde proj pod <project_name>

# 2. Check logs of the problematic pod
kde proj tail <project_name>                            # interactive pod selection
kde proj tail <project_name> <pod_name> 200             # specific pod, 200 lines
kde proj tail <project_name> <pod_name> --no-tty        # non-interactive (AI agent / scripts)
kde proj tail <project_name> <pod_name> 200 --no-tty    # non-interactive, 200 lines

# 3. Exec into the pod shell for interactive investigation
kde proj pod-exec <project_name>                   # interactive pod selection
kde proj pod-exec <project_name> <pod_name>        # specific pod
kde proj pod-exec <project_name> <pod_name> --command "<cmd>"  # non-interactive (AI agent); pod name required
kde proj pod-exec -h                               # detailed help

# Also: exec into the project container with optional volumes and non-interactive mode
kde proj exec <project_name>                             # interactive (develop container)
kde proj exec <project_name> deploy                      # interactive (deploy container)
kde proj exec <project_name> -v /local/path:/path        # interactive with extra volume
kde proj exec <project_name> --command "ls -la"          # non-interactive (AI agent)
kde proj exec <project_name> --command "ls /d" -v /h:/d  # non-interactive with volume

# 4. Exec into the K8s node container for node-level debugging
kde exec                                            # interactive bash session
kde exec --command "kubectl get nodes"              # non-interactive (AI agent / scripts)
kde exec <env_name> --command "kubectl get pods -A" # specific environment, non-interactive

# 5. Visual dashboards (recommended for full picture)
kde k9s          # terminal UI: press d=describe, l=logs, s=shell, :events=events
kde headlamp     # web UI at localhost:4466
```

**Note:** `kde proj pod` only lists pod names. It does not show status or details.
Use `kde k9s` or `kde headlamp` to see status, events, and resource details visually.

### Port forwarding / external access

```bash
kde expose <namespace> service <svc_name> <target_port> <local_port>
kde ngrok service                                          # quick Ngrok tunnel
kde cloudflare-tunnel service -d <domain>                  # Cloudflare Tunnel
```

### Environment lifecycle

```bash
kde stop [env_name]       # stop K8s cluster
kde restart [env_name]    # restart K8s cluster
kde status                # show all environment status
kde use <env_name>        # switch active environment
kde rm <env_name>         # remove environment
```

## Key Project Files

When working with a project at `environments/<env>/namespaces/<project>/`:

| File | Purpose |
|------|---------|
| `project.env` | Pipeline config, git repo, image vars — **read this first** |
| `.env` | Local overrides (gitignored) |
| `.pipeline.env` | Inter-stage variable passing (auto-generated) |
| `build.sh`, `deploy.sh`, etc. | Pipeline stage scripts |

Variables load in this order (later overrides earlier):
`kde.env` → `k8s.env` → env `.env` → `project.env` → project `.env` → `.pipeline.env`

## `kde proj create` vs `kde proj fetch`

| Command | Use when |
|---------|---------|
| `kde proj create <name>` | Starting from scratch — interactive, asks for git URL + images, creates all scaffold files |
| `kde proj fetch <name> <url> <branch>` | Project directory already exists but needs a git repo cloned non-interactively |

## Pipeline Configuration Quick Reference

In `project.env`:

```bash
KDE_PIPELINE_STAGES="build,test,deploy"

KDE_PIPELINE_STAGE_build_IMAGE=node:20
KDE_PIPELINE_STAGE_build_SCRIPT=build.sh

KDE_PIPELINE_STAGE_test_ALLOW_FAILURE=true
KDE_PIPELINE_STAGE_deploy_MANUAL_ONLY=true
KDE_PIPELINE_STAGE_deploy_WORKDIR=/app
```

Stage-level options: `_IMAGE`, `_SCRIPT`, `_WORKDIR`, `_SKIP`, `_MANUAL_ONLY`,
`_ALLOW_FAILURE`, `_PAUSE`, `_MOUNT_*`.

**Note**: Stage names with hyphens use underscores in variable names —
`security-scan` → `KDE_PIPELINE_STAGE_security_scan_*`

## Command Aliases

| Short form | Full form |
|-----------|-----------|
| `kde ls` | `kde list` |
| `kde cur` | `kde current` |
| `kde rm` | `kde remove` |
| `kde proj` / `kde ns` | `kde project` |
| `kde proj ls` | `kde project list` |
| `kde proj rm` | `kde project remove` |
| `kde proj deploy` | `kde project pipeline` |

## Common Gotchas

- **No `kde.env`**: Run `kde init` in the workspace root first.
- **Wrong active environment**: Run `kde use <env_name>` to switch.
- **Image not found in Kind/K3D**: Use `kde load-image <image>` to push local images into the cluster.
- **Hyphen vs underscore**: Pipeline variable names always use underscores, even when stage names use hyphens.
- **Pipeline stage fails**: Check the stage script with `bash -n <script>` for syntax errors; check `.pipeline.env` for missing variables from prior stages.
- **CrashLoopBackOff / pod not starting**: Start with `kde proj tail` for logs, then `kde k9s` for full picture (Events section is especially useful).

## Full Command Reference

For complete syntax and options, read `references/quick-reference.md` in this skill directory.
