#!/bin/bash

# Workspace/Environment provisioning hook execution engine.
# Parses hook script headers for execution mode and runs them accordingly.

parse_hook_exec_mode() {
    local script_file="$1"
    local mode
    mode=$(grep -m1 '^# KDE_HOOK_EXEC_MODE=' "$script_file" 2>/dev/null | sed 's/^# KDE_HOOK_EXEC_MODE=//')
    echo "${mode:-direct}"
}

parse_hook_image() {
    local script_file="$1"
    local image
    image=$(grep -m1 '^# KDE_HOOK_IMAGE=' "$script_file" 2>/dev/null | sed 's/^# KDE_HOOK_IMAGE=//')
    echo "$image"
}

# Execute a single hook script based on its declared execution mode.
# Args: $1=script_path $2=workspace_path
_execute_hook_script() {
    local script_file="$1"
    local workspace_path="$2"
    local mode
    mode=$(parse_hook_exec_mode "$script_file")

    case "$mode" in
        direct)
            workspace_exec bash "$script_file"
            ;;
        container)
            local image
            image=$(parse_hook_image "$script_file")
            if [[ -z "$image" ]]; then
                echo "錯誤：hook 指定 container 模式但未設定 KDE_HOOK_IMAGE: $script_file"
                return 1
            fi
            workspace_exec docker run --rm \
                -v "${workspace_path}:/workspace" \
                -w /workspace \
                "$image" \
                bash "/workspace/hooks/$(basename "$script_file")"
            ;;
        *)
            echo "錯誤：不支援的 hook 執行模式: $mode (in $script_file)"
            return 1
            ;;
    esac
}

# Run workspace hooks for a given phase.
# Args: $1=phase (init|start) $2=workspace_path
run_workspace_hooks() {
    local phase="$1"
    local workspace_path="$2"
    local hooks_dir="${workspace_path}/hooks"
    local hook_file="${hooks_dir}/workspace-${phase}.sh"

    # No hooks directory or no hook file — silently return
    if [[ ! -f "$hook_file" ]]; then
        return 0
    fi

    # Init hooks: skip if already initialized
    if [[ "$phase" == "init" ]]; then
        local marker="${workspace_path}/.workspace-initialized"
        if [[ -f "$marker" ]]; then
            echo "Workspace 已初始化，跳過 init hook"
            return 0
        fi
        _execute_hook_script "$hook_file" "$workspace_path"
        touch "$marker"
    else
        _execute_hook_script "$hook_file" "$workspace_path"
    fi
}

# Run environment hooks for a given phase.
# Args: $1=phase (init|start) $2=env_path
run_environment_hooks() {
    local phase="$1"
    local env_path="$2"
    local hooks_dir="${env_path}/hooks"
    local hook_file="${hooks_dir}/env-${phase}.sh"

    if [[ ! -f "$hook_file" ]]; then
        return 0
    fi

    if [[ "$phase" == "init" ]]; then
        local marker="${env_path}/.env-initialized"
        if [[ -f "$marker" ]]; then
            echo "Environment 已初始化，跳過 init hook"
            return 0
        fi
        _execute_hook_script "$hook_file" "$env_path"
        touch "$marker"
    else
        _execute_hook_script "$hook_file" "$env_path"
    fi
}
