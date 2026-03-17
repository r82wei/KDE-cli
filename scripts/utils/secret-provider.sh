#!/bin/bash

# Secret provider execution engine.
# Runs provider scripts that output key=value pairs to stdout.
# Supports direct and container execution modes (same header convention as hooks).

# Reuse hook parsing functions if available
if [[ -f "${KDE_SCRIPTS_PATH}/utils/workspace/hooks.sh" ]]; then
    source "${KDE_SCRIPTS_PATH}/utils/workspace/hooks.sh"
fi

# Fallback definitions if hooks.sh is not available
if ! declare -f parse_hook_exec_mode > /dev/null 2>&1; then
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
fi

# Run a secret provider script and capture its key=value output.
# Args: $1=script_path $2=project_path
# Returns: key=value pairs on stdout (one per line)
run_secret_provider() {
    local script_path="$1"
    local project_path="$2"

    if [[ -z "$script_path" ]]; then
        return 0
    fi

    # Resolve relative paths against project directory
    if [[ "$script_path" != /* ]]; then
        script_path="${project_path}/${script_path}"
    fi

    if [[ ! -f "$script_path" ]]; then
        echo "錯誤：找不到 secret provider: $script_path" >&2
        return 1
    fi

    local mode
    mode=$(parse_hook_exec_mode "$script_path")

    case "$mode" in
        direct)
            bash "$script_path"
            ;;
        container)
            local image
            image=$(parse_hook_image "$script_path")
            if [[ -z "$image" ]]; then
                echo "錯誤：secret provider 指定 container 模式但未設定 KDE_HOOK_IMAGE: $script_path" >&2
                return 1
            fi
            docker run --rm \
                -v "${project_path}:/project" \
                -w /project \
                "$image" \
                bash "/project/$(realpath --relative-to="$project_path" "$script_path")"
            ;;
        *)
            echo "錯誤：不支援的 secret provider 執行模式: $mode" >&2
            return 1
            ;;
    esac
}

# Convert key=value output to Docker --env flags.
# Args: $1=multiline key=value string
# Returns: string of "--env KEY=VALUE" flags
secrets_to_docker_env_flags() {
    local secrets="$1"
    local flags=""

    if [[ -z "$secrets" ]]; then
        echo ""
        return 0
    fi

    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        if [[ "$line" == *=* ]]; then
            flags="${flags} --env ${line}"
        fi
    done <<< "$secrets"

    echo "$flags"
}

# Get the secret provider path for a given pipeline stage.
# Checks stage-specific provider first, then global provider.
# Args: $1=stage_name
get_stage_secret_provider() {
    local stage_name="$1"
    local stage_var
    stage_var=$(echo "$stage_name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

    local stage_provider_var="KDE_PIPELINE_STAGE_${stage_var}_SECRET_PROVIDER"
    local stage_provider="${!stage_provider_var:-}"

    if [[ -n "$stage_provider" ]]; then
        echo "$stage_provider"
        return
    fi

    echo "${KDE_PIPELINE_SECRET_PROVIDER:-}"
}
