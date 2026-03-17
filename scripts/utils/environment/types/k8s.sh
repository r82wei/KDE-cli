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
