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

### If `$KDE_PATH` is set, you are inside a `kde openclaw` container

`$KDE_PATH` points at the workspace mounted from the host (same absolute path inside and
outside the container). `kde` reads it directly, so **`kde` works from any cwd — you never
need to `cd` first**.

Your own cwd is the OpenClaw agent workspace (`~/.openclaw/workspace`) — your home base for
`AGENTS.md` / `SOUL.md` / `USER.md` / `memory/`. It is **not** the KDE workspace, and nothing
about the K8s environment lives there. Project source code is under the mounted workspace:

```
$KDE_PATH/environments/<env>/namespaces/<project>/<repo>/
```

So read and edit project files through `$KDE_PATH`, not through paths relative to your cwd.

Never run `kde init` here to "fix" a missing `kde.env`: it writes a whole workspace template
(`kde.env`, templates, docs) into whatever `KDE_PATH` resolves to — in the container that
would be your own home directory.

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

### OpenClaw agent (containerized, DooD-enabled)

`kde openclaw` runs an OpenClaw agent gateway in a container that has `kde` and `docker`
available inside it (DooD), so the agent can operate the K8s environment from within its
own container. The container's entire home is mounted at `${KDE_PATH}/.openclaw-home`, so all
state — `~/.openclaw`, plus provider credential dirs like `~/.codex` and `~/.claude` — lives there.

The container also gets `-e KDE_PATH` and this skill mounted read-only into
`~/.agents/skills/kde-usage`, so the agent inside it starts out knowing `kde` and can run it
from any cwd. See "If `$KDE_PATH` is set" under Step 1.

**Action order matters** — `onboard` must run before `run`, and `run` must succeed before
`tui`/`exec`:

```bash
kde openclaw onboard     # 1. one-time interactive wizard (no gateway needed yet)
kde openclaw run          # 2. background-start the gateway (fails if not onboarded)
kde openclaw tui          # 3. interactive OpenClaw TUI (fails if not running)
kde openclaw exec "<cmd>"  #    or run one command through bash, non-interactively
kde openclaw log -f       # 4. tail the gateway logs
kde openclaw dashboard     # 5. first browser visit to the dashboard (see below)
kde openclaw stop          # 6. stop + remove the container (idempotent)
kde openclaw restart       # 7. stop + run in one step, keeping the current port
kde openclaw backup        # 8. snapshot .openclaw-home on demand (stops the container)
kde openclaw upgrade       # 8. pull a newer image; restarts only if it actually changed
kde openclaw downgrade     # 10. restore data + image from a backup
```

**Gotchas Claude commonly hits**:
- `kde openclaw run` on a never-initialized workspace fails with "尚未初始化" and tells you
  to run `kde openclaw onboard` first — it will **not** auto-run onboarding for you.
- `kde openclaw tui` and `kde openclaw exec` fail with "未在運行" if the gateway container
  isn't up — run `kde openclaw run` first. `kde openclaw log` only needs the container to
  **exist**, so it still works after a crash (that is when you need it most).
- `kde openclaw reset` (deletes `.openclaw-home`) refuses while the container is running — run
  `kde openclaw stop` first.
- `kde openclaw backup` takes the same snapshot on demand. It stops the container first (a hot
  copy of the SQLite files can be inconsistent — the packing takes ~9s), asks before doing so,
  and starts it back up afterwards; `-f` skips the prompt. Answering anything but `y` cancels.
- `upgrade` snapshots `.openclaw-home` before swapping versions (tarball in
  `<workspace>/.openclaw-backups/`, newest 3 kept), taken **after** the container stops so the
  SQLite files are quiescent. `kde openclaw downgrade` restores one — data *and* image version.
  It records the image in `<workspace>/.openclaw-image` rather than editing `kde.env`, because
  `kde.env` is versioned and a local rollback must not follow the repo to teammates. `run` and
  `restart` honour that pin and say so in their output; `upgrade` clears it. Never commit
  `.openclaw-image` or a `kde.env` edited to pin an image — a locally built tag will not exist
  on anyone else's machine.
- **A new release does NOT reach a workspace by itself.** `docker run`'s default pull policy
  is `missing`: if the tag already exists locally, Docker uses it and never asks the registry.
  So after `latest` is re-released, `run`/`restart` keep silently running the old image with
  no hint that anything is stale. `kde openclaw upgrade` is the way to move: it pulls, and
  restarts **only if the image ID actually changed** (no new version → no needless gateway
  interruption). If a pull fails it aborts before touching the container. Diagnose a suspected
  skew with `docker run --rm $OPENCLAW_IMAGE openclaw --version` against the image, and note
  that a locally built image can be the culprit — `build.sh` deliberately does not tag
  `latest` for exactly this reason.
- `kde openclaw restart` is `stop` + `run`, with one addition: when you do NOT pass `-p`, it
  reuses the port the running container currently publishes rather than falling back to the
  built-in default, so a container started with `-p 19000` stays on 19000 (otherwise a paired
  browser's bookmark and any minted dashboard link would silently break). An explicit
  `-p 18789` still wins over the reused port, and so does `OPENCLAW_PORT`. If `stop` fails,
  `restart` aborts instead of running — you get one error, not a contradictory pair.
- The container has **no baked-in `kde`** — `/usr/local/bin/kde` is a wrapper around the
  host's CLI, bind-mounted read-only at `/usr/local/lib/kde`. That mount has no opt-out on
  purpose: the workspace is mounted read-write, so a version skew would have two `kde`
  versions writing the same state files. If `kde` inside the container reports
  `command not found` (or the wrapper's "找不到 kde CLI" error), the mount point went empty
  because the host directory was replaced after the container started — bind mounts track
  the inode. Fix by rebuilding the container: `kde openclaw restart`.
  Nothing is lost; state lives in `${KDE_PATH}/.openclaw-home`.
- `exec` is plain bash and does NOT prepend `openclaw` — write the command exactly as it
  runs in the container: `kde openclaw exec "openclaw doctor"` (positional, or `--command`;
  only one of them, and quote the whole command). Without a command it drops you in an
  interactive bash. The interactive OpenClaw TUI is `kde openclaw tui`.
- `-f` is action-scoped: `--force` for `onboard`/`reset`, `--follow` for `log`.
- Getting the dashboard token: `kde openclaw token` (stdout is only the token, so it pipes
  cleanly; works even when the gateway is stopped). Do NOT use
  `openclaw gateway auth-token` — on 2026.8.2 it refuses to print outside an interactive
  terminal, and `openclaw config get gateway.auth.token` returns `__OPENCLAW_REDACTED__`.
- The token alone is NOT enough for a browser's first visit: OpenClaw also requires a
  one-time **device pairing** approval per browser profile, or the browser just shows
  `disconnected (1008): pairing required`. The loopback auto-approval exception does not
  apply here — the gateway is in a container, so the host browser arrives from the Docker
  bridge, not `127.0.0.1`. Run `kde openclaw dashboard` to mint the owner pairing link
  (~10 min, single use, binds only the browser profile that opens it). It cannot be
  pre-done during `onboard`; do not suggest that.
- `onboard` pins `--agent-name main` on purpose, so the wizard never asks for a first-agent
  name. Do not remove it: naming the first agent anything else makes the wizard store the
  provider OAuth credential under an agent it then drops from the config roster, and the
  gateway (which runs `main`) answers every chat with
  `401 Missing bearer or basic authentication in header`. If a workspace was onboarded that
  way by an older `kde`, `openclaw doctor` reports "agent directory on disk without a
  matching agents.list entry" — recovery is in `docs/core/dev-tools/openclaw.md`.

Full flag reference: `docs/core/dev-tools/openclaw.md` (or `kde openclaw -h`).

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
