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
