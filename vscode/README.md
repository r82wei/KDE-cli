# KDE (K8s Dev Environments) – VS Code Extension

This extension adds a tree view in the Activity Bar to manage Kubernetes-based development environments and projects.

## Requirements

- `kde` CLI is installed and available in your shell. (https://github.com/r82wei/KDE-cli)
- `docker` installed.

## Usage

1. Open the Activity Bar view "KDE" and the tree "K8S DEV Environments".
2. Use "Add" to create an environment (choose `kind`/`k3d`/`k8s`).
3. Use "Create Project" to create a project and enter the project settings.

- `a git remote repo`: the project folder will be created by cloning from the remote git repository
- `a git local repo`: the project folder will be created locally from an existing local repository

4. Implement `build.sh` and `deploy.sh` scripts for the CI/CD pipeline.
5. Click the "Deploy" button at the project level to deploy your project.
6. Expand an environment to load projects; expand a project to load Pods.
7. Use inline buttons or context menu actions at each level to operate.

## Output and progress

- All background command output and errors are written to the Output Channel named "k8s-dev-environments".
  - Open it via: View → Output → select "k8s-dev-environments".
- Loading projects/Pods shows a progress indicator in the window status area.
- Errors are surfaced with the underlying stderr text.

## Terminals and Tasks

- New terminal sessions are created for long-running/interactive tools (K9s, Headlamp, Logs, Exec, Port Forward). These terminals auto-exit after the command finishes.
- Long-running operations (create/stop/deploy/undeploy/redeploy/create project) run as VS Code Tasks. Non-zero exit codes are reported via VS Code notifications.

## How it works

- Environments are listed using `kde ls`.
- Environment status is read via `kde status json` and shown with icons:
  - RUNNING → filled circle (passed color)
  - UNREADY → outline circle (disabled color)
  - error → filled circle (failed color)
- Expanding an environment runs `kde use <env>` followed by `kde project ls` to list projects.
- Expanding a project runs `kde use <env>` then `kde project pod <project>` to list Pods.

## Commands and actions

### View actions (title bar)

- Add: interactive environment creation flow (see below)
- Refresh: refresh the tree

### Environment-level commands

- Add (interactive):
  - Pick an environment type: `kind`, `k3d`, or `k8s`.
  - You will be prompted to enter an environment name, a kube-api-server port, and an ingress port.
  - For `k8s`, you will be prompted to select a kubeconfig file.
  - Executes: `kde init && kde create <envName> <type>` (for `k8s`: `kde init && kde create <envName> k8s <kubeconfigPath>`), as a VS Code Task.
  - You can edit the settings for kind or k3d by modifying kind-config.yaml or k3d-config.yaml after this task.
- Create:
  - Depending on the ENV_TYPE specified in `k8s.env`, either create a local Kubernetes environment (kind/k3d) or connect to a remote Kubernetes cluster
  - Executes: `kde create <envName>` (Task)
  - For ENV_TYPE=`k8s`, you will be prompted to select a kubeconfig file.
- Stop:
  - Stop the local Kubernetes environment.
  - Executes: `kde stop <envName>` (Task).
- K9s:
  - Start K9s (a TUI Kubernetes dashboard).
  - Executes: `kde use <envName> && kde k9s` (New terminal)
- Headlamp:
  - Start Headlamp (a Web UI for Kubernetes dashboard).
  - Executes: `kde use <envName> && kde headlamp` (New terminal)
- Port Forward (environment):
  - Expose a service or pod in K8S
  - Executes: `kde use <envName> && kde expose` (New terminal)
- Create Project:
  - Add a kde-based project with CI/CD shell.
  - You will be prompted to input a project name.
  - Executes: `kde use <envName> && kde project create <project>` (Task)

### Project-level commands

- Deploy:
  - Uses the DEVELOP_IMAGE and DEPLOY_IMAGE specified in project.env to start build.sh and deploy.sh respectively, executing CI/CD.
  - Executes: `kde use <envName> && kde project deploy <project>` (Task)
  - For more details, please refer to the "Run CI/CD deployment" section in https://github.com/r82wei/KDE-cli
- Undeploy:
  - Undeploy project by running undeploy.sh
  - If undeploy.sh does not exist, the default action is to delete the namespace with the same name as the project.
  - Executes: `kde use <envName> && kde project undeploy <project>` (Task)
  - For more details, please refer to the "Undeploy" section in https://github.com/r82wei/KDE-cli
- Redeploy:
  - Redeploys the project by sequentially performing the undeploy and deploy actions.
  - Executes: `kde use <envName> && kde project redeploy <project>` (Task)
- Develop Env:
  - Starts a container using the DEVELOP_IMAGE specified in project.env, allowing the user to enter the development environment.
  - Executes:`kde use <envName> && kde project exec <project> develop` (new terminal)
  - For more details, please refer to the "Enter the local container development environment" section in https://github.com/r82wei/KDE-cli
- Deploy Env:

  - Starts a container using the DEPLOY_IMAGE specified in project.env, allowing the user to enter the deployment environment.
  - Executes: `kde use <envName> && kde project exec <project> deploy` (new terminal)
  - For more details, please refer to the "Enter the local container development environment" section in https://github.com/r82wei/KDE-cli

- Telepresence Replace:
  - Starts a container using the DEPLOY_IMAGE specified in project.env, and intercepts the traffic from the specified remote K8S pod to the local development environment.
  - The environment variables from the Pod will also be injected into the local development container.
  - The local development container can also connect to services inside the remote K8S cluster.
  - Executes: `kde use <envName> && kde telepresence replace <project>` (new terminal)
  - For more details, please refer to the "Remote debugging" section in https://github.com/r82wei/KDE-cli

### Pod-level commands

- Logs:
  - You will be prompted to enter a number of lines to show.
  - Executes:`kde use <envName> && kde project tail <project> <pod> <lines>` (new terminal)
- Port Forward (single Pod):
  - prompts `localPort` and `targetPort`
  - Executes: `kde use <envName> && kde expose <project> pod <pod> <localPort> <targetPort>` (new terminal)
- Exec:
  - Enter the Pod using kubectl exec
  - Executes: `kde use <envName> && kde project pod-exec <project> <pod>` (new terminal)
