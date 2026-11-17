# Running `kde` without a TTY

Read this when you run `kde` through a tool call, in CI, or anywhere else with no terminal
attached and nobody to answer prompts. `kde` was designed around interactive menus; the
non-interactive paths were added later and do not cover every command.

A command can block you in two different ways:

| Failure | What you see | Cause |
|---|---|---|
| Needs a TTY | Immediate error: `cannot attach stdin to a TTY-enabled container because stdin is not a terminal` (older Docker: `the input device is not a TTY`) | The command runs `docker run -it` / `docker exec -it` |
| Asks a question | Hangs, loops on a menu, or exits on empty input | The command calls `read` or shows a selection menu |

Neither is a bug in your invocation. Do not retry the same command; switch to the
non-interactive form below, or hand the command to the user.

## Rules that avoid most problems

- **Always pass the project name.** Every `kde proj <action>` opens a selection menu when the
  name is missing.
- **Always pass the pod name** to `tail --no-tty` and `pod-exec --command`. Without it they
  exit 1 instead of opening a menu. Get names from `kde proj pod <project>`.
- **Pass the environment name** to `kde use`. Without it you get a menu.
- **Never rely on a command "falling back" to a prompt.** `kde expose` does exactly that when
  any argument is invalid (see below).

## Commands that work without a TTY

| Goal | Command |
|---|---|
| Active environment / all environments | `kde current`, `kde ls`, `kde status`, `kde status json` |
| Switch environment | `kde use <env>` |
| Stop / remove an environment | `kde stop [env] [-f]`, `kde rm <env>` (both destructive, see SKILL.md) |
| List projects / pods | `kde proj ls`, `kde proj pod <project>` |
| Pod logs | `kde proj tail <project> <pod> [lines] --no-tty` |
| Command in a pod | `kde proj pod-exec <project> <pod> --command "<cmd>"` |
| Command in the project container | `kde proj exec <project> [develop\|deploy] [-v host:ctr] --command "<cmd>"` |
| Command on the cluster node | `kde exec [env] --command "<cmd>"` (kind / k3d only) |
| Run the pipeline | `kde proj pipeline <project> [--only\|--from\|--to <stage>] --no-tty` (`deploy` is the same) |
| Redeploy | `kde proj redeploy <project> --no-tty` (needs an `undeploy.sh`, see below) |
| Clone a project | `kde proj fetch <project> <git_url> <branch>` (asks only if the directory already exists) |
| Update source | `kde proj pull <project> [-f]` |
| Port-forward | `kde expose -d <namespace> <pod\|service> <name> <target_port> <local_port>` |
| Web UI in the background | `kde headlamp -d [-p <port>]` |
| OpenClaw | `run`, `stop`, `restart`, `exec "<cmd>"`, `log`, `token`, `dashboard --json`, `backup -f`, `upgrade`, `downgrade <n> -f`, `reset -f` |
| Housekeeping | `kde version`, `kde init`, `kde claude-skill <install\|update\|status>` |

`kde status json` prints `[{"status":"RUNNING"|"UNREADY","environment":"<name>"}]` on stdout.

Details worth knowing:

- `tail --no-tty` returns a **snapshot** and exits. It does not follow. Run it again to see
  newer lines.
- `--no-tty` makes a pipeline stage's `_PAUSE=true` continue automatically instead of asking.
- `--shell` and `--no-tty` are mutually exclusive (the pipeline exits with an error).
- `kde proj redeploy` accepts only `--no-tty`. `--from`, `--to`, `--only` and `--manual` are
  silently ignored there.
- `kde expose` needs **all five** arguments to be valid: the namespace and resource must
  exist and both ports must be 1–65535. If any one is wrong it does not report an error, it
  opens the interactive menu. `-d` must be the first argument; without `-d` the forward runs
  in the foreground with `-it`.

## Commands that need a TTY

These have no flag that removes the TTY requirement.

| Command | Why |
|---|---|
| `kde start`, `kde create` (kind / k3d) | Cluster creation and the default-service install run `docker run -it`. `start` then opens K9s. A new environment also asks for two ports. |
| `kde restart` | Runs `kde stop` then `kde start` |
| `kde load-image` | `docker run -it` |
| `kde proj undeploy` | No `--no-tty` flag. Use `kde proj pipeline <project> --only undeploy --no-tty` when the project has an `undeploy.sh`. Without that script the default action (delete the namespace) runs with `-it`. |
| `kde proj redeploy --no-tty` on a project with no `undeploy.sh` | Same default action, same `-it` |
| `kde proj rm <project>` while the environment is running | Undeploys first, as above |
| `kde k9s`, `kde dashboard`, `kde headlamp` (no `-d`), `kde expose` (no `-d`) | Interactive tools / foreground containers |
| `kde exec`, `kde proj exec`, `kde proj pod-exec` without `--command` | Interactive shells |
| `kde proj pipeline --shell` | Interactive shell per stage |
| `kde openclaw onboard`, `kde openclaw tui` | Interactive by nature |

## Commands that ask questions

| Command | What it asks |
|---|---|
| `kde start` / `kde create` (new kind / k3d environment) | API server port (default 6443), ingress port (default 80) |
| `kde start <env> k8s` | kubeconfig path, unless given as the third argument or in `KUBECONFIG_PATH` |
| `kde proj create` | Use Git or not, repo URL, branch, develop image, deploy image |
| `kde proj link`, `kde projects link` | Directory path |
| `kde proj ingress` | Domain, service, port |
| `kde projects fetch`, `kde projects pull` | Per project: download the repo or not |
| `kde reset` | Two confirmations, no `-f` |
| `kde code-server` | Password, every time; no flag or environment variable replaces it |
| `kde ngrok service` / `pod` | Namespace, resource, port; the token on first use |
| `kde cloudflare-tunnel` | Anything not passed as a flag (`-n`, `-s`, `--pod`, `-p`, `-u`, `-d`); a custom domain needs a browser login on first use |
| `kde telepresence <action>` | CIDR, port mappings, which project |

## What to do when the command you need is in those lists

**Default: ask the user to run it in their own terminal**, and give them the exact command.
Starting an environment is the common case:

> Please run `kde start <env>` in your terminal. It asks for two ports (press Enter for the
> defaults) and then opens K9s; quit K9s with `:q` or Ctrl-C and tell me when it is up.

Then confirm with `kde status json` before you continue.

For `kde proj create`, the user can run it, or you can create the same result by hand in
`environments/<env>/namespaces/<project>/`: a `project.env` (`GIT_REPO_URL`,
`GIT_REPO_BRANCH`, `DEVELOP_IMAGE`, `DEPLOY_IMAGE`, `KDE_PIPELINE_STAGES`), plus executable
`build.sh` and `deploy.sh`. Copy an existing project's `project.env` as the template when
one exists.

**If the user wants you to start the cluster yourself**, this recipe follows from the code
but has not been run end to end. Say so before you use it, and fall back to asking the user
if it fails:

```bash
# 1. Answer the two port prompts in advance (they are skipped when the keys exist)
mkdir -p environments/<env>
printf 'K8S_API_SERVER_PORT=6443\nK8S_INGRESS_NGINX_PORT=80\n' > environments/<env>/.env

# 2. `create` instead of `start` (no K9s), under a pseudo-terminal for the `docker run -it` calls
script -qec "kde create <env> kind" /dev/null
```

Setting `ENABLE_K9S=false` in `kde.env` also stops `kde start` from opening K9s, but
`kde.env` is versioned and shared with the team, so do not add it without asking.
