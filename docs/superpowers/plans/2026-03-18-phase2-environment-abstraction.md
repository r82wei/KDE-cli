# Phase 2: Environment Abstraction — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the environment layer into type (what it produces) and backend (how it's created), with a dispatcher, backend validation, provisioning hooks, custom backend support, and backward compatibility for existing Kind/K3D/K8s workflows.

**Architecture:** Create `scripts/utils/environment/types/` and `scripts/utils/environment/backends/`. Backend files implement `_backend_env_*` functions. Type files validate backend functions exist, wrap them with type-specific logic, and expose the public `env_*` interface. A dispatcher loads both based on `KDE_ENVIRONMENT_TYPE` and `KDE_ENVIRONMENT_BACKEND` from `environment.env`.

**Tech Stack:** Pure Bash, Kind (existing), K3D (existing), external K8s (existing)

**Spec:** `docs/superpowers/specs/2026-03-17-workspace-environment-abstraction-design.md`

**Depends on:** Phase 1 (workspace abstraction) must be complete — particularly the hooks engine (`scripts/utils/workspace/hooks.sh`) which is reused here.

---

## File Structure

### New Files

| File | Responsibility |
|------|----------------|
| `scripts/utils/environment/environment.sh` | Dispatcher: load type + backend, handle custom backends |
| `scripts/utils/environment/types/k8s.sh` | K8s type: validate backend, wrap with kubeconfig/namespace ops |
| `scripts/utils/environment/backends/kind.sh` | Kind backend: `_backend_env_*` functions extracted from current `kind.sh` |
| `scripts/utils/environment/backends/k3d.sh` | K3D backend: `_backend_env_*` functions extracted from current `k3d.sh` |
| `scripts/utils/environment/backends/k8s.sh` | External K8s backend: `_backend_env_*` for existing cluster |
| `test/test-environment-dispatcher.sh` | Tests for dispatcher loading and backend validation |
| `test/test-environment-k8s-type.sh` | Tests for K8s type wrapper logic |

### Modified Files

| File | Change |
|------|--------|
| `scripts/start/command.sh` | Refactor to use `env_create` / `env_start` instead of direct `create_kind_env` / `start_kind` calls |
| `scripts/stop/command.sh` | Refactor to use `env_stop` instead of direct `stop_kind` / `stop_k3d` calls |
| `scripts/utils/environment/k8s.sh` | Extract shared K8s functions to `types/k8s.sh`; keep as compatibility shim during transition |
| `kde.sh` | Update `KDE_ENV_FILE` loading to check `environment.env` with `k8s.env` fallback |

### Preserved (Reference)

| File | Reason |
|------|--------|
| `scripts/utils/environment/kind.sh` (original) | Kept as reference; new code in `backends/kind.sh` |
| `scripts/utils/environment/k3d.sh` (original) | Kept as reference; new code in `backends/k3d.sh` |

---

## Task 1: Environment Dispatcher

**Files:**
- Create: `scripts/utils/environment/environment.sh`
- Test: `test/test-environment-dispatcher.sh`

- [ ] **Step 1: Write the test file**

```bash
#!/bin/bash
set -eo pipefail

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $desc"
        ((PASS++))
    else
        echo "  FAIL: $desc (expected='$expected', actual='$actual')"
        ((FAIL++))
    fi
}

assert_fn_exists() {
    local desc="$1" fn_name="$2"
    if declare -f "$fn_name" > /dev/null 2>&1; then
        echo "  PASS: $desc"
        ((PASS++))
    else
        echo "  FAIL: $desc (function '$fn_name' not defined)"
        ((FAIL++))
    fi
}

# Setup
export KDE_SCRIPTS_PATH="$(cd "$(dirname "$0")/../scripts" && pwd)"
export KDE_PATH="/tmp/test-env-dispatcher-$$"
export ENV_PATH="/tmp/test-env-dispatcher-$$/environments/test-env"
mkdir -p "${ENV_PATH}"

echo "=== Test: Dispatcher fails without type ==="
unset KDE_ENVIRONMENT_TYPE
unset KDE_ENVIRONMENT_BACKEND
EXIT_CODE=0
bash -c "source ${KDE_SCRIPTS_PATH}/utils/environment/environment.sh" 2>/dev/null || EXIT_CODE=$?
assert_eq "fails without type" "1" "$EXIT_CODE"

echo ""
echo "=== Test: Custom backend loads from env directory ==="
export KDE_ENVIRONMENT_TYPE="custom"
export KDE_ENVIRONMENT_BACKEND="custom"
mkdir -p "${ENV_PATH}/backend"
cat > "${ENV_PATH}/backend/environment.sh" << 'EOF'
_backend_env_create() { echo "custom create"; }
_backend_env_start() { echo "custom start"; }
_backend_env_stop() { echo "custom stop"; }
_backend_env_delete() { echo "custom delete"; }
_backend_env_status() { echo "running"; }
env_custom_exec() { echo "custom exec"; }
EOF
source "${KDE_SCRIPTS_PATH}/utils/environment/environment.sh"
RESULT=$(_backend_env_create)
assert_eq "custom backend loaded" "custom create" "$RESULT"

# Cleanup
rm -rf "${KDE_PATH}"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]] || exit 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash test/test-environment-dispatcher.sh`
Expected: FAIL — `environment.sh` does not exist

- [ ] **Step 3: Write the dispatcher**

```bash
#!/bin/bash

# Environment dispatcher — loads type + backend based on configuration.
# Backend is sourced first (implements _backend_env_*), then type (wraps into env_*).

load_environment() {
    local type="${KDE_ENVIRONMENT_TYPE:-}"
    local backend="${KDE_ENVIRONMENT_BACKEND:-}"

    if [[ -z "$type" ]]; then
        echo "錯誤：未設定 KDE_ENVIRONMENT_TYPE"
        exit 1
    fi

    if [[ -z "$backend" ]]; then
        echo "錯誤：未設定 KDE_ENVIRONMENT_BACKEND"
        exit 1
    fi

    # Load backend
    if [[ "$backend" == "custom" ]]; then
        if [[ ! -f "${ENV_PATH}/backend/environment.sh" ]]; then
            echo "錯誤：找不到自訂 environment backend: ${ENV_PATH}/backend/environment.sh"
            exit 1
        fi
        source "${ENV_PATH}/backend/environment.sh"
    else
        local backend_file="${KDE_SCRIPTS_PATH}/utils/environment/backends/${backend}.sh"
        if [[ ! -f "$backend_file" ]]; then
            echo "錯誤：找不到 environment backend: ${backend}"
            exit 1
        fi
        source "$backend_file"
    fi

    # Load type
    if [[ "$type" != "custom" ]]; then
        local type_file="${KDE_SCRIPTS_PATH}/utils/environment/types/${type}.sh"
        if [[ ! -f "$type_file" ]]; then
            echo "錯誤：找不到 environment type: ${type}"
            exit 1
        fi
        source "$type_file"
    fi
    # custom type: user defines everything in backend/environment.sh
}

# Load environment config with backward compatibility
load_environment_config() {
    local env_path="$1"

    if [[ -f "${env_path}/environment.env" ]]; then
        source "${env_path}/environment.env"
    elif [[ -f "${env_path}/k8s.env" ]]; then
        # Backward compat: old format implies k8s type
        source "${env_path}/k8s.env"
        export KDE_ENVIRONMENT_TYPE="${KDE_ENVIRONMENT_TYPE:-k8s}"
        # Infer backend from ENV_TYPE (old variable)
        export KDE_ENVIRONMENT_BACKEND="${KDE_ENVIRONMENT_BACKEND:-${ENV_TYPE:-kind}}"
    fi

    # Load local secrets
    if [[ -f "${env_path}/.env" ]]; then
        source "${env_path}/.env"
    fi
}

load_environment
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash test/test-environment-dispatcher.sh`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/utils/environment/environment.sh test/test-environment-dispatcher.sh
git commit -m "feat(environment): add type+backend dispatcher with custom support"
```

---

## Task 2: Kind Backend

**Files:**
- Create: `scripts/utils/environment/backends/kind.sh`

- [ ] **Step 1: Create backends directory**

```bash
mkdir -p scripts/utils/environment/backends
```

- [ ] **Step 2: Write Kind backend with `_backend_env_*` functions**

Extract from current `scripts/utils/environment/kind.sh` and rename:

```bash
#!/bin/bash

# Environment backend: Kind
# Creates local K8s clusters using Kind (Kubernetes in Docker).

_backend_env_create() {
    # From create_kind_env(): set container name, docker network, storage class
    export K8S_CONTAINER_NAME="kind-${ENV_NAME}-control-plane"
    export DOCKER_NETWORK="kind"
    export STORAGE_CLASS="standard"
    echo "K8S_CONTAINER_NAME=${K8S_CONTAINER_NAME}" >> ${K8S_ENV_FILE_PATH}
    echo "DOCKER_NETWORK=${DOCKER_NETWORK}" >> ${K8S_ENV_FILE_PATH}
    echo "STORAGE_CLASS=${STORAGE_CLASS}" >> ${K8S_ENV_FILE_PATH}
}

_backend_env_init() {
    # From init_kind_config(): generate kind-config.yaml from template
    envsubst < ${KDE_TEMPLATES_PATH}/kind/kind-config.yaml > ${ENV_PATH}/kind-config.yaml
}

_backend_env_start() {
    # From start_kind(): create docker network, run kind create cluster
    docker network create -d bridge ${DOCKER_NETWORK} 2>/dev/null || true

    docker run --rm \
        --net ${DOCKER_NETWORK} \
        -v ${ENV_PATH}/kind-config.yaml:/kind-config.yaml \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        ${KDE_KIND_IMAGE:-kindest/node:v1.28.0} \
        kind create cluster --name ${ENV_NAME} --config /kind-config.yaml --kubeconfig /dev/null

    # Copy kubeconfig
    docker exec ${K8S_CONTAINER_NAME} cat /etc/kubernetes/admin.conf > ${KUBECONFIG}
}

_backend_env_stop() {
    # From stop_kind(): stop kind containers
    local containers
    containers=$(docker ps -a --filter "name=kind-${ENV_NAME}" --format '{{.Names}}' 2>/dev/null)
    if [[ -n "$containers" ]]; then
        echo "$containers" | xargs docker stop 2>/dev/null || true
        echo "$containers" | xargs docker rm 2>/dev/null || true
    fi
}

_backend_env_delete() {
    _backend_env_stop
    # Remove kind cluster metadata
    kind delete cluster --name "${ENV_NAME}" 2>/dev/null || true
}

_backend_env_status() {
    local container_status
    container_status=$(docker inspect -f '{{.State.Running}}' "${K8S_CONTAINER_NAME}" 2>/dev/null)
    if [[ "$container_status" == "true" ]]; then
        echo "running"
    else
        echo "stopped"
    fi
}

_backend_env_exec_node() {
    docker exec -it ${K8S_CONTAINER_NAME} bash
}

_backend_env_load_image() {
    local image="$1"
    kind load docker-image "$image" --name "${ENV_NAME}"
}
```

**IMPORTANT:** The actual function bodies should be adapted from the existing `kind.sh`. The above is a reference structure — the implementer must read the current `kind.sh` (130 lines) and faithfully translate each function, preserving all Docker flags, network setup, and error handling.

- [ ] **Step 3: Verify syntax**

Run: `bash -n scripts/utils/environment/backends/kind.sh`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add scripts/utils/environment/backends/kind.sh
git commit -m "feat(environment): add Kind backend with _backend_env_* interface"
```

---

## Task 3: K3D Backend

**Files:**
- Create: `scripts/utils/environment/backends/k3d.sh`

- [ ] **Step 1: Write K3D backend with `_backend_env_*` functions**

Same pattern as Kind backend. Extract from current `scripts/utils/environment/k3d.sh`:

```bash
#!/bin/bash

# Environment backend: K3D
# Creates local K8s clusters using K3D (K3s in Docker).

_backend_env_create() {
    export K8S_CONTAINER_NAME="k3d-${ENV_NAME}-serverlb"
    export DOCKER_NETWORK="k3d-${ENV_NAME}"
    export STORAGE_CLASS="local-path"
    echo "K8S_CONTAINER_NAME=${K8S_CONTAINER_NAME}" >> ${K8S_ENV_FILE_PATH}
    echo "DOCKER_NETWORK=${DOCKER_NETWORK}" >> ${K8S_ENV_FILE_PATH}
    echo "STORAGE_CLASS=${STORAGE_CLASS}" >> ${K8S_ENV_FILE_PATH}
}

_backend_env_init() {
    envsubst < ${KDE_TEMPLATES_PATH}/k3d/k3d-config.yaml > ${ENV_PATH}/k3d-config.yaml
}

_backend_env_start() {
    k3d cluster create ${ENV_NAME} --config ${ENV_PATH}/k3d-config.yaml
    k3d kubeconfig get ${ENV_NAME} > ${KUBECONFIG}
}

_backend_env_stop() {
    local containers
    containers=$(docker ps -a --filter "name=k3d-${ENV_NAME}" --format '{{.Names}}' 2>/dev/null)
    if [[ -n "$containers" ]]; then
        echo "$containers" | xargs docker stop 2>/dev/null || true
        echo "$containers" | xargs docker rm 2>/dev/null || true
    fi
}

_backend_env_delete() {
    k3d cluster delete "${ENV_NAME}" 2>/dev/null || true
}

_backend_env_status() {
    local container_status
    container_status=$(docker inspect -f '{{.State.Running}}' "${K8S_CONTAINER_NAME}" 2>/dev/null)
    if [[ "$container_status" == "true" ]]; then
        echo "running"
    else
        echo "stopped"
    fi
}

_backend_env_exec_node() {
    local server_container="k3d-${ENV_NAME}-server-0"
    docker exec -it "${server_container}" sh
}

_backend_env_load_image() {
    local image="$1"
    k3d image import "$image" -c "${ENV_NAME}"
}
```

**Same note as Kind:** Adapt from actual `k3d.sh` code. The above is reference structure.

- [ ] **Step 2: Verify syntax**

Run: `bash -n scripts/utils/environment/backends/k3d.sh`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add scripts/utils/environment/backends/k3d.sh
git commit -m "feat(environment): add K3D backend with _backend_env_* interface"
```

---

## Task 4: External K8s Backend

**Files:**
- Create: `scripts/utils/environment/backends/k8s.sh`

- [ ] **Step 1: Write External K8s backend**

```bash
#!/bin/bash

# Environment backend: External K8s
# Connects to an existing K8s cluster via kubeconfig.
# No create/start/stop — the cluster is managed externally.

_backend_env_create() {
    export DOCKER_NETWORK="bridge"
    echo "DOCKER_NETWORK=${DOCKER_NETWORK}" >> ${K8S_ENV_FILE_PATH}
}

_backend_env_init() {
    # From init_external_k8s(): copy kubeconfig, extract server IP
    if [[ -n "${EXTERNAL_KUBECONFIG:-}" ]]; then
        cp "${EXTERNAL_KUBECONFIG}" "${KUBECONFIG}"
    fi
    # Extract server IP for display
    local server_url
    server_url=$(kubectl --kubeconfig="${KUBECONFIG}" config view -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)
    echo "K8S_SERVER=${server_url}" >> ${K8S_ENV_FILE_PATH}
}

_backend_env_start() {
    # External cluster: nothing to start
    echo "外部 K8S 叢集，無需啟動"
}

_backend_env_stop() {
    # External cluster: nothing to stop
    echo "外部 K8S 叢集，請自行管理"
}

_backend_env_delete() {
    echo "外部 K8S 叢集，僅移除本地設定"
    # Only remove local config, not the actual cluster
}

_backend_env_status() {
    if kubectl --kubeconfig="${KUBECONFIG}" get nodes &>/dev/null; then
        echo "running"
    else
        echo "unreachable"
    fi
}

_backend_env_exec_node() {
    echo "外部 K8S 叢集不支援直接 exec 進入 node"
    return 1
}
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n scripts/utils/environment/backends/k8s.sh`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add scripts/utils/environment/backends/k8s.sh
git commit -m "feat(environment): add external K8s backend"
```

---

## Task 5: K8s Type

**Files:**
- Create: `scripts/utils/environment/types/k8s.sh`
- Test: `test/test-environment-k8s-type.sh`

- [ ] **Step 1: Write the test file**

```bash
#!/bin/bash
set -eo pipefail

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $desc"
        ((PASS++))
    else
        echo "  FAIL: $desc (expected='$expected', actual='$actual')"
        ((FAIL++))
    fi
}

assert_fn_exists() {
    local desc="$1" fn_name="$2"
    if declare -f "$fn_name" > /dev/null 2>&1; then
        echo "  PASS: $desc"
        ((PASS++))
    else
        echo "  FAIL: $desc (function '$fn_name' not defined)"
        ((FAIL++))
    fi
}

# Setup: mock a minimal backend
export KDE_SCRIPTS_PATH="$(cd "$(dirname "$0")/../scripts" && pwd)"

_backend_env_create() { echo "mock create"; }
_backend_env_start() { echo "mock start"; }
_backend_env_stop() { echo "mock stop"; }
_backend_env_delete() { echo "mock delete"; }
_backend_env_status() { echo "running"; }

echo "=== Test: K8s type sources successfully with valid backend ==="
source "${KDE_SCRIPTS_PATH}/utils/environment/types/k8s.sh"
assert_eq "sourced ok" "0" "$?"

echo ""
echo "=== Test: K8s type wraps backend create ==="
RESULT=$(env_create)
assert_eq "env_create calls backend" "mock create" "$RESULT"

echo ""
echo "=== Test: K8s type defines type-specific functions ==="
assert_fn_exists "env_k8s_exec exists" "env_k8s_exec"
assert_fn_exists "env_k8s_create_namespace exists" "env_k8s_create_namespace"
assert_fn_exists "env_k8s_delete_namespace exists" "env_k8s_delete_namespace"
assert_fn_exists "env_k8s_load_kubeconfig exists" "env_k8s_load_kubeconfig"

echo ""
echo "=== Test: Backend validation catches missing function ==="
# Unset one required function and try to source again
unset -f _backend_env_create
EXIT_CODE=0
bash -c "
_backend_env_start() { :; }
_backend_env_stop() { :; }
_backend_env_delete() { :; }
_backend_env_status() { :; }
source ${KDE_SCRIPTS_PATH}/utils/environment/types/k8s.sh
" 2>/dev/null || EXIT_CODE=$?
assert_eq "validation catches missing _backend_env_create" "1" "$EXIT_CODE"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]] || exit 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash test/test-environment-k8s-type.sh`
Expected: FAIL — `types/k8s.sh` does not exist

- [ ] **Step 3: Write K8s type**

```bash
#!/bin/bash

# Environment type: K8s
# Wraps backend functions with K8s-specific operations (kubeconfig, namespaces, etc.)
# Expects backend to provide: _backend_env_create, _backend_env_start, _backend_env_stop,
# _backend_env_delete, _backend_env_status

# --- Backend validation ---
for fn in _backend_env_create _backend_env_start _backend_env_stop _backend_env_delete _backend_env_status; do
    declare -f "$fn" > /dev/null || { echo "Backend 缺少必要函式: $fn"; exit 1; }
done

# --- Public interface: wrap backend with K8s semantics ---

env_create() {
    _backend_env_create "$@"
}

env_start() {
    _backend_env_start "$@"
    env_k8s_load_kubeconfig
    # Run environment hooks if available
    if declare -f run_environment_hooks > /dev/null 2>&1; then
        run_environment_hooks "start" "${ENV_PATH}"
    fi
}

env_stop() {
    _backend_env_stop "$@"
}

env_delete() {
    _backend_env_delete "$@"
}

env_status() {
    _backend_env_status "$@"
}

# --- K8s type-specific operations ---

env_k8s_exec() {
    if declare -f _backend_env_exec_node > /dev/null 2>&1; then
        _backend_env_exec_node "$@"
    else
        echo "此 backend 不支援 exec 進入 K8s node"
        return 1
    fi
}

env_k8s_load_kubeconfig() {
    if [[ -f "${KUBECONFIG:-}" ]]; then
        export KUBECONFIG
    fi
}

env_k8s_create_namespace() {
    local namespace="$1"
    # Use deploy-env container to run kubectl
    exec_script_in_deploy_env "kubectl create namespace ${namespace}"
}

env_k8s_delete_namespace() {
    local namespace="$1"
    exec_script_in_deploy_env "kubectl delete namespace ${namespace}"
}

env_k8s_load_image() {
    if declare -f _backend_env_load_image > /dev/null 2>&1; then
        _backend_env_load_image "$@"
    else
        echo "此 backend 不支援載入 Docker image"
        return 1
    fi
}
```

**NOTE:** The `exec_script_in_deploy_env` function is defined in the current `k8s.sh` utility file. It must remain available (either kept in `k8s.sh` or extracted to a shared K8s utilities file). The implementer should check where `exec_script_in_deploy_env` and related container execution functions live after refactoring.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash test/test-environment-k8s-type.sh`
Expected: All PASS

- [ ] **Step 5: Create types directory structure**

```bash
mkdir -p scripts/utils/environment/types
```

- [ ] **Step 6: Commit**

```bash
git add scripts/utils/environment/types/k8s.sh test/test-environment-k8s-type.sh
git commit -m "feat(environment): add K8s type with backend validation and namespace ops"
```

---

## Task 6: Environment Provisioning Hooks

**Files:**
- Modify: `scripts/utils/environment/types/k8s.sh` (add hook calls)

The hooks engine already exists from Phase 1 (`scripts/utils/workspace/hooks.sh` with `run_environment_hooks`). This task wires it into the environment lifecycle.

- [ ] **Step 1: Update `env_create` in `types/k8s.sh` to run init hooks**

Add at the end of `env_create()`:

```bash
env_create() {
    _backend_env_create "$@"
    # Run init hooks after creation
    source "${KDE_SCRIPTS_PATH}/utils/workspace/hooks.sh"
    run_environment_hooks "init" "${ENV_PATH}"
}
```

- [ ] **Step 2: Verify `env_start` already runs start hooks**

Check that `env_start()` in `types/k8s.sh` already calls `run_environment_hooks "start"` (added in Task 5 Step 3). Confirm it's there.

- [ ] **Step 3: Commit**

```bash
git add scripts/utils/environment/types/k8s.sh
git commit -m "feat(environment): wire provisioning hooks into K8s type lifecycle"
```

---

## Task 7: Refactor Command Routing (start/stop/create)

**Files:**
- Modify: `scripts/start/command.sh`
- Modify: `scripts/stop/command.sh`

This is the most delicate task — the existing commands must keep working while using the new abstractions.

- [ ] **Step 1: Read current `scripts/start/command.sh` carefully**

Run: Read the full file. Understand the three phases: creation, initialization, start. Map each phase to the new interface.

- [ ] **Step 2: Add environment dispatcher loading to start command**

At the top of `scripts/start/command.sh`, after the existing environment loading:

```bash
# Load new environment dispatcher if environment.env exists
if [[ -f "${ENV_PATH}/environment.env" ]]; then
    source ${KDE_SCRIPTS_PATH}/utils/environment/environment.sh
    USE_NEW_ENV=true
else
    USE_NEW_ENV=false
fi
```

- [ ] **Step 3: Add new-style path in the start execution**

Wrap the existing `case` blocks with a check:

```bash
if [[ "$USE_NEW_ENV" == "true" ]]; then
    # New path: use environment abstraction
    if [[ $(is_env_exist ${ENV_NAME}) != "true" ]]; then
        env_create
    fi
    env_start
else
    # Legacy path: existing Kind/K3D/K8s routing (unchanged)
    # ... existing code ...
fi
```

- [ ] **Step 4: Apply same pattern to stop command**

```bash
if [[ "$USE_NEW_ENV" == "true" ]]; then
    env_stop
else
    # Legacy path
    # ... existing code ...
fi
```

- [ ] **Step 5: Verify syntax**

Run: `bash -n scripts/start/command.sh && bash -n scripts/stop/command.sh`
Expected: No errors

- [ ] **Step 6: Manually test with existing Kind environment**

Run: `kde start dev-env kind` (or equivalent existing command)
Expected: Works exactly as before (takes legacy path since no `environment.env` exists)

- [ ] **Step 7: Commit**

```bash
git add scripts/start/command.sh scripts/stop/command.sh
git commit -m "feat(environment): add new-style env dispatcher path in start/stop commands"
```

---

## Task 8: Config File Backward Compatibility

**Files:**
- Modify: `kde.sh`

- [ ] **Step 1: Update environment config loading in kde.sh**

Find the section where `k8s.env` is loaded for the current environment. Add `environment.env` check:

```bash
# In the load_enviroment_env function or wherever k8s.env is sourced:
load_environment_env() {
    ENV_NAME=${1:-${CUR_ENV}}
    export ENV_PATH=${ENVIROMENTS_PATH}/${ENV_NAME}

    # New format first, then fallback
    if [[ -f "${ENV_PATH}/environment.env" ]]; then
        source "${ENV_PATH}/environment.env"
    elif [[ -f "${ENV_PATH}/k8s.env" ]]; then
        source "${ENV_PATH}/k8s.env"
        # Infer type from old ENV_TYPE variable
        export KDE_ENVIRONMENT_TYPE="${KDE_ENVIRONMENT_TYPE:-k8s}"
        export KDE_ENVIRONMENT_BACKEND="${KDE_ENVIRONMENT_BACKEND:-${ENV_TYPE:-kind}}"
    fi

    if [[ -f "${ENV_PATH}/.env" ]]; then
        source "${ENV_PATH}/.env"
    fi

    if [[ -f "${ENV_PATH}/${KUBE_CONFIG_DIR}/config" ]]; then
        export KUBECONFIG="${ENV_PATH}/${KUBE_CONFIG_DIR}/config"
    fi
}
```

**NOTE:** The existing function is `load_enviroment_env` (with typo). Decide whether to fix the typo now or keep it for compat. Recommendation: create `load_environment_env` (fixed) and keep `load_enviroment_env` as an alias.

- [ ] **Step 2: Verify existing workflows**

Run: `bash -n kde.sh`
Expected: No syntax errors

- [ ] **Step 3: Commit**

```bash
git add kde.sh scripts/utils/environment/k8s.sh
git commit -m "feat(environment): add environment.env with k8s.env backward compat"
```

---

## Summary

| Task | Description | Files | Depends On |
|------|-------------|-------|------------|
| 1 | Environment dispatcher | environment.sh + test | — |
| 2 | Kind backend | backends/kind.sh | Task 1 |
| 3 | K3D backend | backends/k3d.sh | Task 1 |
| 4 | External K8s backend | backends/k8s.sh | Task 1 |
| 5 | K8s type | types/k8s.sh + test | Task 1 |
| 6 | Environment hooks wiring | types/k8s.sh | Task 5, Phase 1 |
| 7 | Refactor start/stop routing | start/stop command.sh | Tasks 2-5 |
| 8 | Config backward compat | kde.sh | Task 1 |

**Total: 8 tasks, ~30 steps**

**Parallel opportunities:**
- Tasks 2, 3, 4 can all run in parallel after Task 1
- Task 5 can run in parallel with Tasks 2-4
- Task 8 can run in parallel with Tasks 2-5
