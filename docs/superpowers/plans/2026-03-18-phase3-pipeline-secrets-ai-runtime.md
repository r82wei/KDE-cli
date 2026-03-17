# Phase 3: Pipeline Secret Injection + AI Runtime Provisioning — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add dynamic secret injection from external providers (Vault, AWS Secrets Manager, etc.) into pipeline stages, and create workspace provisioning templates that pre-install AI coding runtimes (Claude Code, Codex).

**Architecture:** Secret providers are executable scripts that output `key=value` pairs. The pipeline executor runs providers before each stage and injects results as container environment variables. AI runtime installation is handled by workspace hooks (from Phase 1).

**Tech Stack:** Pure Bash, Docker (existing), Pipeline system (existing)

**Spec:** `docs/superpowers/specs/2026-03-17-workspace-environment-abstraction-design.md` — sections "Pipeline: Dynamic Secret Injection" and "AI Agent Playground"

**Depends on:** Phase 1 (hooks engine) and Phase 2 (environment abstraction) should be complete.

---

## File Structure

### New Files

| File | Responsibility |
|------|----------------|
| `scripts/utils/secret-provider.sh` | Secret provider execution: parse exec mode, run provider, capture key=value output |
| `templates/hooks/ai-runtime-init.sh` | Example workspace init hook: install Claude Code, Codex CLI |
| `test/test-secret-provider.sh` | Tests for secret provider parsing and execution |
| `test/test-pipeline-secrets.sh` | Tests for pipeline integration with secret providers |

### Modified Files

| File | Change |
|------|--------|
| `scripts/utils/pipeline.sh` | Add secret injection step before each stage execution |

---

## Task 1: Secret Provider Engine

**Files:**
- Create: `scripts/utils/secret-provider.sh`
- Test: `test/test-secret-provider.sh`

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

assert_contains() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == *"$expected"* ]]; then
        echo "  PASS: $desc"
        ((PASS++))
    else
        echo "  FAIL: $desc (expected to contain '$expected', got='$actual')"
        ((FAIL++))
    fi
}

# Setup
export KDE_SCRIPTS_PATH="$(cd "$(dirname "$0")/../scripts" && pwd)"
export KDE_PATH="/tmp/test-secret-provider-$$"
export PROJECT_PATH="${KDE_PATH}/project"
mkdir -p "${PROJECT_PATH}/scripts"

echo "=== Test: Run direct-mode secret provider ==="
cat > "${PROJECT_PATH}/scripts/secrets.sh" << 'EOF'
#!/bin/bash
echo "DB_HOST=localhost"
echo "DB_PASS=s3cret"
echo "API_KEY=abc123"
EOF
chmod +x "${PROJECT_PATH}/scripts/secrets.sh"

source "${KDE_SCRIPTS_PATH}/utils/secret-provider.sh"

SECRETS=$(run_secret_provider "${PROJECT_PATH}/scripts/secrets.sh" "${PROJECT_PATH}")
assert_contains "has DB_HOST" "DB_HOST=localhost" "$SECRETS"
assert_contains "has DB_PASS" "DB_PASS=s3cret" "$SECRETS"
assert_contains "has API_KEY" "API_KEY=abc123" "$SECRETS"

echo ""
echo "=== Test: Parse exec mode from header ==="
cat > "${PROJECT_PATH}/scripts/vault-secrets.sh" << 'SCRIPT'
#!/bin/bash
# KDE_HOOK_EXEC_MODE=container
# KDE_HOOK_IMAGE=hashicorp/vault
echo "VAULT_TOKEN=xyz"
SCRIPT
chmod +x "${PROJECT_PATH}/scripts/vault-secrets.sh"

MODE=$(parse_hook_exec_mode "${PROJECT_PATH}/scripts/vault-secrets.sh")
assert_eq "reads container mode" "container" "$MODE"
IMAGE=$(parse_hook_image "${PROJECT_PATH}/scripts/vault-secrets.sh")
assert_eq "reads image" "hashicorp/vault" "$IMAGE"

echo ""
echo "=== Test: Convert secrets to Docker --env flags ==="
SECRETS="DB_HOST=localhost
DB_PASS=s3cret"
ENV_FLAGS=$(secrets_to_docker_env_flags "$SECRETS")
assert_contains "has --env DB_HOST" "--env DB_HOST=localhost" "$ENV_FLAGS"
assert_contains "has --env DB_PASS" "--env DB_PASS=s3cret" "$ENV_FLAGS"

echo ""
echo "=== Test: Empty provider path returns empty ==="
RESULT=$(run_secret_provider "" "${PROJECT_PATH}")
assert_eq "empty path returns empty" "" "$RESULT"

echo ""
echo "=== Test: Missing provider file returns error ==="
EXIT_CODE=0
run_secret_provider "/nonexistent/script.sh" "${PROJECT_PATH}" 2>/dev/null || EXIT_CODE=$?
assert_eq "missing file returns 1" "1" "$EXIT_CODE"

# Cleanup
rm -rf "${KDE_PATH}"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]] || exit 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash test/test-secret-provider.sh`
Expected: FAIL — `secret-provider.sh` does not exist

- [ ] **Step 3: Write the secret provider engine**

```bash
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

    # Empty path = no provider configured
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
        # Skip empty lines and comments
        [[ -z "$line" || "$line" == \#* ]] && continue
        # Validate key=value format
        if [[ "$line" == *=* ]]; then
            flags="${flags} --env ${line}"
        fi
    done <<< "$secrets"

    echo "$flags"
}

# Get the secret provider path for a given pipeline stage.
# Checks stage-specific provider first, then global provider.
# Args: $1=stage_name
# Returns: provider script path (or empty string if none configured)
get_stage_secret_provider() {
    local stage_name="$1"
    local stage_var
    stage_var=$(echo "$stage_name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

    # Stage-specific provider (KDE_PIPELINE_STAGE_<NAME>_SECRET_PROVIDER)
    local stage_provider_var="KDE_PIPELINE_STAGE_${stage_var}_SECRET_PROVIDER"
    local stage_provider="${!stage_provider_var:-}"

    if [[ -n "$stage_provider" ]]; then
        echo "$stage_provider"
        return
    fi

    # Global provider (KDE_PIPELINE_SECRET_PROVIDER)
    echo "${KDE_PIPELINE_SECRET_PROVIDER:-}"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash test/test-secret-provider.sh`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/utils/secret-provider.sh test/test-secret-provider.sh
git commit -m "feat(pipeline): add secret provider engine with direct/container modes"
```

---

## Task 2: Pipeline Integration

**Files:**
- Modify: `scripts/utils/pipeline.sh`
- Test: `test/test-pipeline-secrets.sh`

- [ ] **Step 1: Write the test file for pipeline secret integration**

```bash
#!/bin/bash
set -eo pipefail

PASS=0
FAIL=0

assert_contains() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == *"$expected"* ]]; then
        echo "  PASS: $desc"
        ((PASS++))
    else
        echo "  FAIL: $desc (expected to contain '$expected', got='$actual')"
        ((FAIL++))
    fi
}

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

# Setup
export KDE_SCRIPTS_PATH="$(cd "$(dirname "$0")/../scripts" && pwd)"
export KDE_PATH="/tmp/test-pipeline-secrets-$$"
export PROJECT_PATH="${KDE_PATH}/project"
mkdir -p "${PROJECT_PATH}/scripts"

source "${KDE_SCRIPTS_PATH}/utils/secret-provider.sh"

echo "=== Test: get_stage_secret_provider with global provider ==="
export KDE_PIPELINE_SECRET_PROVIDER="scripts/secrets.sh"
unset KDE_PIPELINE_STAGE_BUILD_SECRET_PROVIDER
RESULT=$(get_stage_secret_provider "build")
assert_eq "global provider used" "scripts/secrets.sh" "$RESULT"

echo ""
echo "=== Test: get_stage_secret_provider with stage override ==="
export KDE_PIPELINE_STAGE_DEPLOY_SECRET_PROVIDER="scripts/deploy-secrets.sh"
RESULT=$(get_stage_secret_provider "deploy")
assert_eq "stage provider overrides global" "scripts/deploy-secrets.sh" "$RESULT"

echo ""
echo "=== Test: get_stage_secret_provider with no provider ==="
unset KDE_PIPELINE_SECRET_PROVIDER
unset KDE_PIPELINE_STAGE_TEST_SECRET_PROVIDER
RESULT=$(get_stage_secret_provider "test")
assert_eq "no provider returns empty" "" "$RESULT"

echo ""
echo "=== Test: Full flow — provider output to docker env flags ==="
cat > "${PROJECT_PATH}/scripts/secrets.sh" << 'EOF'
#!/bin/bash
echo "SECRET_A=value1"
echo "SECRET_B=value2"
EOF
chmod +x "${PROJECT_PATH}/scripts/secrets.sh"

SECRETS=$(run_secret_provider "${PROJECT_PATH}/scripts/secrets.sh" "${PROJECT_PATH}")
FLAGS=$(secrets_to_docker_env_flags "$SECRETS")
assert_contains "flags contain SECRET_A" "--env SECRET_A=value1" "$FLAGS"
assert_contains "flags contain SECRET_B" "--env SECRET_B=value2" "$FLAGS"

# Cleanup
rm -rf "${KDE_PATH}"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]] || exit 1
```

- [ ] **Step 2: Run test to verify it passes**

Run: `bash test/test-pipeline-secrets.sh`
Expected: All PASS (uses secret-provider.sh from Task 1)

- [ ] **Step 3: Read current `execute_stage` function in pipeline.sh**

Read: `scripts/utils/pipeline.sh` — find the `execute_stage` function and the line where `exec_script_in_container_with_project` is called.

- [ ] **Step 4: Add secret injection to pipeline.sh**

At the top of `scripts/utils/pipeline.sh`, add the source:

```bash
source ${KDE_SCRIPTS_PATH}/utils/secret-provider.sh
```

In the `execute_stage` function (or `execute_custom_pipeline`), before the container execution call, add:

```bash
# --- Secret injection ---
local secret_provider
secret_provider=$(get_stage_secret_provider "${STAGE_NAME}")
local secret_env_flags=""
if [[ -n "$secret_provider" ]]; then
    local secrets
    secrets=$(run_secret_provider "$secret_provider" "${PROJECT_PATH}")
    if [[ -n "$secrets" ]]; then
        secret_env_flags=$(secrets_to_docker_env_flags "$secrets")
    fi
fi
```

Then pass `$secret_env_flags` to the container execution. In `exec_script_in_container_with_project`, add the flags to the `docker run` command:

```bash
# In the docker run command, add ${SECRET_ENV_FLAGS} before the image name:
docker run --rm -it \
    --user $UID:$(id -g) \
    --env-file ${PROJECT_ENV_FILE} \
    ${DOCKER_VOLUMES} \
    ${secret_env_flags} \
    ${DOCKER_IMAGE} \
    bash -c "${SCRIPT}"
```

**IMPORTANT:** Secrets are injected as `--env` flags, not written to any file. They exist only in the container process's environment.

- [ ] **Step 5: Verify syntax**

Run: `bash -n scripts/utils/pipeline.sh`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add scripts/utils/pipeline.sh test/test-pipeline-secrets.sh
git commit -m "feat(pipeline): inject secrets from external providers into stage containers"
```

---

## Task 3: AI Runtime Provisioning Template

**Files:**
- Create: `templates/hooks/ai-runtime-init.sh`

- [ ] **Step 1: Create the AI runtime init hook template**

```bash
#!/bin/bash
# KDE_HOOK_EXEC_MODE=direct

# AI Runtime 安裝腳本
# 用於 workspace 初始化時自動安裝 AI coding agent 所需的工具。
# 將此檔案複製到 <workspace>/hooks/workspace-init.sh 來啟用。

set -eux

echo "===  安裝 AI Runtime 工具 ==="

# Node.js (Claude Code 依賴)
if ! command -v node &>/dev/null; then
    echo "安裝 Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Claude Code
if ! command -v claude &>/dev/null; then
    echo "安裝 Claude Code..."
    sudo npm install -g @anthropic-ai/claude-code
fi

# Python (Codex 依賴)
if ! command -v python3 &>/dev/null; then
    echo "安裝 Python3..."
    sudo apt-get update -qq
    sudo apt-get install -y python3 python3-pip python3-venv
fi

# 可選：Codex CLI
# if ! command -v codex &>/dev/null; then
#     echo "安裝 Codex CLI..."
#     pip3 install openai-codex
# fi

echo "=== AI Runtime 安裝完成 ==="
```

- [ ] **Step 2: Commit**

```bash
git add templates/hooks/ai-runtime-init.sh
git commit -m "feat(workspace): add AI runtime provisioning hook template"
```

---

## Task 4: Documentation Update

**Files:**
- Modify: `docs/sandbox/overview.md` (if exists, add note about workspace migration)

- [ ] **Step 1: Add a note at the top of sandbox docs pointing to workspace**

```markdown
> **注意：** `kde sandbox` 指令將在未來版本中被 `kde workspace` 取代。
> 新的 workspace 層提供了更多 backend 支援和 provisioning hook 機制。
> 詳見設計文件：`docs/superpowers/specs/2026-03-17-workspace-environment-abstraction-design.md`
```

- [ ] **Step 2: Commit**

```bash
git add docs/sandbox/overview.md
git commit -m "docs: add workspace migration note to sandbox documentation"
```

---

## Summary

| Task | Description | Files | Depends On |
|------|-------------|-------|------------|
| 1 | Secret provider engine | secret-provider.sh + test | Phase 1 (hooks.sh) |
| 2 | Pipeline integration | pipeline.sh + test | Task 1 |
| 3 | AI runtime hook template | templates/hooks/ | Phase 1 (hooks engine) |
| 4 | Documentation update | docs/ | — |

**Total: 4 tasks, ~16 steps**

**Parallel opportunities:**
- Tasks 1 and 3 can run in parallel (independent)
- Task 4 is independent of everything
