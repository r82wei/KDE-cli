#!/bin/bash

# Workspace dispatcher — loads the appropriate backend and defines stubs for optional operations.

# --- Optional operation stubs ---
# These are overridden by backends that support them.
# workspace_supports() checks if a function was overridden from its stub.

_workspace_stub_marker="__workspace_stub__"

_define_workspace_stubs() {
    local ops="create start delete stop snapshot expose"
    for op in $ops; do
        eval "workspace_${op}() { echo \"操作不支援：workspace_${op} (backend: \${KDE_WORKSPACE_BACKEND:-local})\"; return 1; }"
        eval "_workspace_stub_original_${op}=\$(declare -f workspace_${op})"
    done
}

workspace_supports() {
    local op="$1"
    local fn_name="workspace_${op}"
    # Check if function exists and differs from stub
    if ! declare -f "$fn_name" > /dev/null 2>&1; then
        return 1
    fi
    local current
    current=$(declare -f "$fn_name")
    local stub_var="_workspace_stub_original_${op}"
    if [[ "$current" == "${!stub_var}" ]]; then
        return 1  # Still a stub
    fi
    return 0
}

# --- Dispatcher ---

load_workspace_backend() {
    local backend="${KDE_WORKSPACE_BACKEND:-local}"

    # Define stubs first — backends override what they support
    _define_workspace_stubs

    if [[ "$backend" == "custom" ]]; then
        if [[ ! -f "${KDE_PATH}/backend/workspace.sh" ]]; then
            echo "錯誤：找不到自訂 workspace backend: ${KDE_PATH}/backend/workspace.sh"
            exit 1
        fi
        source "${KDE_PATH}/backend/workspace.sh"
    else
        local backend_file="${KDE_SCRIPTS_PATH}/utils/workspace/${backend}.sh"
        if [[ ! -f "$backend_file" ]]; then
            echo "錯誤：找不到 workspace backend: ${backend}"
            exit 1
        fi
        source "$backend_file"
    fi
}

load_workspace_backend
