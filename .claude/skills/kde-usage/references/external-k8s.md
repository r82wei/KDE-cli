# External K8s environments (`ENV_TYPE=k8s`)

Read this when the active environment connects to an existing cluster instead of a local
kind / k3d cluster. Check the type in `environments/<env>/k8s.env` (`ENV_TYPE=k8s`).

An external environment is only a kubeconfig plus the project directories. `kde` does not
create, stop, or own the cluster, and the cluster may be shared or production. Treat every
deploy and undeploy as affecting other people.

## What differs from kind / k3d

| Capability | kind / k3d | External K8s |
|---|---|---|
| `kde start` | Creates the cluster, then opens K9s | Copies the kubeconfig in, prints RUNNING / UNREADY, exits. No K9s. |
| `kde stop`, `kde restart` | Deletes / recreates the cluster containers | `stop` only prints a message; nothing is stopped |
| Hot reload (project directory mounted into the pod) | Yes | **No.** The cluster cannot see host files. Code changes need a rebuilt image and a deploy. |
| `kde load-image` | Loads a local image into the cluster | Not supported. Push the image to a registry the cluster can pull from. |
| `kde exec` (node shell) | Works | **Fails.** There is no node container; `docker exec` is run against the API server address. |
| `kde proj undeploy` with no `undeploy.sh` | Deletes the namespace | **Refuses** (exit 1) and asks for an `undeploy.sh` |
| Docker network for tool containers | `kde-<env>` | `bridge` |

Everything that goes through `kubectl` in a tool container works the same: `kde proj pod`,
`tail`, `pod-exec`, `proj exec`, the pipeline, `k9s`, `headlamp`, `expose`.

## Creating one

```bash
kde start <env> k8s <path-to-kubeconfig>
# or
KUBECONFIG_PATH=<path-to-kubeconfig> kde start <env> k8s
```

With the path given either way, this does not prompt and does not open K9s. Without it,
`kde` asks for the path. `~` is expanded. The kubeconfig is **copied** into
`environments/<env>/kubeconfig/config`; later edits to the original file are not picked up.

The API server must be reachable from a container on Docker's default `bridge` network. A
kubeconfig that points at `127.0.0.1` or `localhost` will not work from inside the tool
containers.

## Things to be careful with

- **`kde proj undeploy` and `kde proj redeploy` need an `undeploy.sh`.** Without it they
  fail on purpose, so nothing is deleted from a shared cluster by default. `redeploy` aborts
  before running the pipeline. Do not work around this by deleting the namespace yourself
  unless the user asks for exactly that.
- **`kde reset <env>` is not blocked** even though the docs say it is unsupported. It deletes
  the environment's local config, including the copied kubeconfig and `k8s.env`. The cluster
  itself is untouched, but the environment has to be created again.
- **`kde rm <env>` deletes the local environment directory with all its projects** and their
  source checkouts, without confirmation. Workloads already deployed to the cluster stay
  there, now with nothing local that tracks them.
- **`kde proj rm <project>`** undeploys first when the cluster is reachable. Without an
  `undeploy.sh` that step fails and the removal stops there, so the project directory stays.
  With one, the directory and its source checkout are deleted without confirmation.
- **`kde telepresence replace` stops the remote pod.** On a shared cluster prefer
  `intercept`, `wiretap` or `ingest`, and confirm with the user first.
- The project name is used as the namespace name. Check that deploying to that namespace on
  this cluster is what the user intends.
