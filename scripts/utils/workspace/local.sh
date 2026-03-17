#!/bin/bash

# Local workspace backend — 本機工作區後端
# Implements the 4 required workspace operations for local (host) environments.

workspace_connect() {
    echo "本機工作區：已連線"
    return 0
}

workspace_exec() {
    local cmd="$1"
    shift
    eval "$cmd" "$@"
}

workspace_status() {
    echo "running"
    return 0
}

workspace_info() {
    echo "backend: local"
    echo "path: ${KDE_PATH:-unknown}"
    return 0
}
