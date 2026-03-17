#!/bin/bash

# Local workspace backend — 本機工作區後端
# The default backend. Workspace is just a folder on the host — no VM, no container.
# Implements the 4 required workspace operations; does NOT override any optional stubs.

workspace_connect() {
    # Noop — already on the host
    return 0
}

workspace_exec() {
    # Run in a subshell with workspace env vars sourced
    (
        if [[ -f "${KDE_PATH}/workspace.env" ]]; then
            set -a
            source "${KDE_PATH}/workspace.env"
            set +a
        fi
        if [[ -f "${KDE_PATH}/.env" ]]; then
            set -a
            source "${KDE_PATH}/.env"
            set +a
        fi
        "$@"
    )
}

workspace_status() {
    echo "reachable"
}

workspace_info() {
    echo "OS=$(uname -s)"
    echo "ARCH=$(uname -m)"
    echo "CPUS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo unknown)"
    echo "MEMORY=$(free -h 2>/dev/null | awk '/^Mem:/{print $2}' || sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.0fGiB", $1/1073741824}' || echo unknown)"
}
