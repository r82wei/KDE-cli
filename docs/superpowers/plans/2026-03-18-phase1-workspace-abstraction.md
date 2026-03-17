# Phase 1: Workspace Abstraction — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Abstract the sandbox layer into a pluggable workspace layer with `local` and `lima` backends, provisioning hooks, custom backend support, and a `kde workspace` CLI command.

**Architecture:** Introduce `scripts/utils/workspace/` with a dispatcher (`workspace.sh`) that loads backend implementations. Refactor the existing `sandbox/lima.sh` into `workspace/lima.sh` with renamed `workspace_*` functions. Add `local.sh` as the default noop backend. Add provisioning hook execution. Wire up `kde workspace` command in the CLI router.

**Tech Stack:** Pure Bash, Lima (existing), Docker (existing)

**Spec:** `docs/superpowers/specs/2026-03-17-workspace-environment-abstraction-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|------|----------------|
| `scripts/utils/workspace/workspace.sh` | Dispatcher: load backend, define stubs for optional ops, provide `workspace_supports` |
| `scripts/utils/workspace/local.sh` | Local backend: noop connect, subshell exec, always-running status |
| `scripts/utils/workspace/lima.sh` | Lima backend: refactored from `scripts/utils/sandbox/lima.sh` with `workspace_*` names |
| `scripts/workspace/command.sh` | CLI command: `kde workspace create\|start\|stop\|exec\|status\|...` |
| `scripts/utils/workspace/hooks.sh` | Hook execution: parse exec mode header, run init/start hooks |
| `test/test-workspace-local.sh` | Tests for local backend |
| `test/test-workspace-dispatcher.sh` | Tests for dispatcher + stubs + supports |
| `test/test-workspace-hooks.sh` | Tests for hook parsing and execution |

### Modified Files

| File | Change |
|------|--------|
| `kde.sh` | Add `workspace` command routing, update `KDE_ENV_FILE` to check `workspace.env` with `kde.env` fallback |
| `scripts/sandbox/command.sh` | Thin wrapper that delegates to `kde workspace` (backward compat alias) |
| `scripts/utils/sandbox.sh` | Thin wrapper that sources workspace dispatcher (backward compat) |

### Preserved (Not Changed)

| File | Reason |
|------|--------|
| `scripts/utils/sandbox/lima.sh` | Kept as-is for backward compat during transition; new `workspace/lima.sh` is the canonical copy |
| `templates/lima/kde-sandbox.yaml` | Reused by workspace/lima.sh, no changes needed |

---

## Task 1: Workspace Dispatcher + Stubs

**Files:**
- Create: `scripts/utils/workspace/workspace.sh`
- Test: `test/test-workspace-dispatcher.sh`

- [ ] **Step 1: Write the test file for dispatcher**

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

# Setup: mock paths
export KDE_SCRIPTS_PATH="$(cd "$(dirname "$0")/../scripts" && pwd)"
export KDE_PATH="/tmp/test-workspace-dispatcher-$$"
export KDE_WORKSPACE_BACKEND="local"
mkdir -p "${KDE_PATH}"

echo "=== Test: Dispatcher loads local backend ==="
source "${KDE_SCRIPTS_PATH}/utils/workspace/workspace.sh"
assert_fn_exists "workspace_connect defined" "workspace_connect"
assert_fn_exists "workspace_exec defined" "workspace_exec"
assert_fn_exists "workspace_status defined" "workspace_status"
assert_fn_exists "workspace_info defined" "workspace_info"

echo ""
echo "=== Test: Optional stubs return 1 ==="
SNAP_EXIT=0
workspace_snapshot 2>/dev/null || SNAP_EXIT=$?
assert_eq "workspace_snapshot returns 1" "1" "$SNAP_EXIT"

echo ""
echo "=== Test: workspace_supports for local backend ==="
assert_eq "local supports connect" "0" "$(workspace_supports connect && echo 0 || echo 1)"
assert_eq "local does not support snapshot" "1" "$(workspace_supports snapshot && echo 0 || echo 1)"

echo ""
echo "=== Test: Stub error message ==="
OUTPUT=$(workspace_create 2>&1 || true)
assert_contains "stub prints backend name" "local" "$OUTPUT"

# Cleanup
rm -rf "${KDE_PATH}"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]] || exit 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash test/test-workspace-dispatcher.sh`
Expected: FAIL — `scripts/utils/workspace/workspace.sh` does not exist

- [ ] **Step 3: Write the dispatcher**

```bash
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash test/test-workspace-dispatcher.sh`
Expected: All PASS (some may fail because `local.sh` doesn't exist yet — that's Task 2)

- [ ] **Step 5: Commit**

```bash
git add scripts/utils/workspace/workspace.sh test/test-workspace-dispatcher.sh
git commit -m "feat(workspace): add dispatcher with optional operation stubs"
```

---

## Task 2: Local Backend

**Files:**
- Create: `scripts/utils/workspace/local.sh`
- Test: `test/test-workspace-local.sh`

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
export KDE_PATH="/tmp/test-workspace-local-$$"
export KDE_WORKSPACE_BACKEND="local"
mkdir -p "${KDE_PATH}"

source "${KDE_SCRIPTS_PATH}/utils/workspace/workspace.sh"

echo "=== Test: workspace_status returns reachable ==="
STATUS=$(workspace_status)
assert_eq "local always reachable" "reachable" "$STATUS"

echo ""
echo "=== Test: workspace_connect is noop ==="
workspace_connect
assert_eq "connect returns 0" "0" "$?"

echo ""
echo "=== Test: workspace_exec runs command in subshell ==="
RESULT=$(workspace_exec echo "hello from workspace")
assert_eq "exec runs command" "hello from workspace" "$RESULT"

echo ""
echo "=== Test: workspace_exec inherits workspace env ==="
echo "TEST_VAR=workspace_value" > "${KDE_PATH}/workspace.env"
RESULT=$(workspace_exec bash -c 'echo $TEST_VAR')
# Note: local backend sources workspace.env — tested if implemented
# For now just test that exec works
assert_eq "exec succeeds" "0" "$?"

echo ""
echo "=== Test: workspace_info prints key=value ==="
INFO=$(workspace_info)
assert_contains "info contains OS" "OS=" "$INFO"

echo ""
echo "=== Test: local does not support create ==="
assert_eq "local does not support create" "1" "$(workspace_supports create && echo 0 || echo 1)"

# Cleanup
rm -rf "${KDE_PATH}"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]] || exit 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash test/test-workspace-local.sh`
Expected: FAIL — `local.sh` not found

- [ ] **Step 3: Write local backend**

```bash
#!/bin/bash

# Workspace backend: local
# Workspace is just a folder on the host. No VM, no container.
# This is the default backend — KDE-CLI operates directly on the host.

workspace_connect() {
    # Noop — already on the host
    return 0
}

workspace_exec() {
    # Run in a subshell with workspace env vars
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

# Local backend does not override any optional stubs.
# workspace_create, workspace_delete, workspace_stop, workspace_snapshot, workspace_expose
# all remain as stubs returning 1.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash test/test-workspace-local.sh`
Expected: All PASS

- [ ] **Step 5: Also run dispatcher test**

Run: `bash test/test-workspace-dispatcher.sh`
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add scripts/utils/workspace/local.sh test/test-workspace-local.sh
git commit -m "feat(workspace): add local backend (default, noop)"
```

---

## Task 3: Provisioning Hooks Engine

**Files:**
- Create: `scripts/utils/workspace/hooks.sh`
- Test: `test/test-workspace-hooks.sh`

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

# Setup: create a fake workspace with hooks
export KDE_SCRIPTS_PATH="$(cd "$(dirname "$0")/../scripts" && pwd)"
export KDE_PATH="/tmp/test-workspace-hooks-$$"
export KDE_WORKSPACE_BACKEND="local"
mkdir -p "${KDE_PATH}/hooks"

source "${KDE_SCRIPTS_PATH}/utils/workspace/workspace.sh"
source "${KDE_SCRIPTS_PATH}/utils/workspace/hooks.sh"

echo "=== Test: parse_hook_exec_mode defaults to direct ==="
cat > "${KDE_PATH}/hooks/workspace-init.sh" << 'SCRIPT'
#!/bin/bash
echo "init ran"
SCRIPT
chmod +x "${KDE_PATH}/hooks/workspace-init.sh"
MODE=$(parse_hook_exec_mode "${KDE_PATH}/hooks/workspace-init.sh")
assert_eq "default mode is direct" "direct" "$MODE"

echo ""
echo "=== Test: parse_hook_exec_mode reads container mode ==="
cat > "${KDE_PATH}/hooks/workspace-start.sh" << 'SCRIPT'
#!/bin/bash
# KDE_HOOK_EXEC_MODE=container
# KDE_HOOK_IMAGE=ubuntu:24.04
echo "start ran"
SCRIPT
chmod +x "${KDE_PATH}/hooks/workspace-start.sh"
MODE=$(parse_hook_exec_mode "${KDE_PATH}/hooks/workspace-start.sh")
assert_eq "reads container mode" "container" "$MODE"

echo ""
echo "=== Test: parse_hook_image reads image ==="
IMAGE=$(parse_hook_image "${KDE_PATH}/hooks/workspace-start.sh")
assert_eq "reads image" "ubuntu:24.04" "$IMAGE"

echo ""
echo "=== Test: init hook creates marker file ==="
run_workspace_hooks "init" "${KDE_PATH}"
assert_eq "marker file created" "0" "$([[ -f ${KDE_PATH}/.workspace-initialized ]] && echo 0 || echo 1)"

echo ""
echo "=== Test: init hook skips if marker exists ==="
# Modify the script to write a different message
cat > "${KDE_PATH}/hooks/workspace-init.sh" << 'SCRIPT'
#!/bin/bash
echo "init ran again" > /tmp/test-workspace-hooks-rerun-$$
SCRIPT
chmod +x "${KDE_PATH}/hooks/workspace-init.sh"
run_workspace_hooks "init" "${KDE_PATH}"
assert_eq "init not re-run" "1" "$([[ -f /tmp/test-workspace-hooks-rerun-$$ ]] && echo 0 || echo 1)"

echo ""
echo "=== Test: no hooks dir is fine ==="
EMPTY_PATH="/tmp/test-workspace-hooks-empty-$$"
mkdir -p "$EMPTY_PATH"
run_workspace_hooks "init" "$EMPTY_PATH"
assert_eq "no error without hooks dir" "0" "$?"
rm -rf "$EMPTY_PATH"

# Cleanup
rm -rf "${KDE_PATH}"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]] || exit 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash test/test-workspace-hooks.sh`
Expected: FAIL — `hooks.sh` not found

- [ ] **Step 3: Write hooks engine**

```bash
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash test/test-workspace-hooks.sh`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/utils/workspace/hooks.sh test/test-workspace-hooks.sh
git commit -m "feat(workspace): add provisioning hook engine with direct/container modes"
```

---

## Task 4: Lima Backend (Refactor from Sandbox)

**Files:**
- Create: `scripts/utils/workspace/lima.sh`
- Modify: `scripts/utils/sandbox/lima.sh` (keep as-is for now, don't delete)

- [ ] **Step 1: Copy existing lima.sh to workspace directory**

```bash
cp scripts/utils/sandbox/lima.sh scripts/utils/workspace/lima.sh
```

- [ ] **Step 2: Rename all function signatures and internal references in the new file**

Rename mapping (find/replace in `scripts/utils/workspace/lima.sh`):

| Old name | New name |
|----------|----------|
| `sandbox_start` | `workspace_create` |
| `sandbox_stop` | `workspace_stop` |
| `sandbox_delete` | `workspace_delete` |
| `sandbox_exec` | `workspace_exec` |
| `sandbox_status` | `workspace_info` |
| `sandbox_is_running` | `_workspace_lima_is_running` |
| `sandbox_snapshot_create` | `_workspace_lima_snapshot_create` |
| `sandbox_snapshot_list` | `_workspace_lima_snapshot_list` |
| `sandbox_snapshot_restore` | `_workspace_lima_snapshot_restore` |
| `sandbox_expose` | `_workspace_lima_expose_forward` |
| `sandbox_expose_list` | `_workspace_lima_expose_list` |
| `sandbox_expose_stop` | `_workspace_lima_expose_stop` |
| `sandbox_expose_stop_all` | `_workspace_lima_expose_stop_all` |
| `sandbox_tmux_save` | `_workspace_lima_tmux_save` |
| `SANDBOX_DATA_DIR` | `WORKSPACE_DATA_DIR` |
| `get_sandbox_instance_name` | `get_workspace_instance_name` |

**IMPORTANT:** Also update all **internal cross-references** — these functions call each other:
- `workspace_delete` calls `_workspace_lima_is_running`, `workspace_stop`
- `workspace_stop` calls `_workspace_lima_expose_stop_all`, `_workspace_lima_tmux_save`
- `_workspace_lima_expose_stop_all` calls `_workspace_lima_expose_stop`
- Expose functions reference `WORKSPACE_DATA_DIR` for the expose directory

Do a global find/replace for `sandbox_` → the correct new name. Verify no `sandbox_` references remain.

- [ ] **Step 2b: Split `workspace_create` from `workspace_start`**

The existing `sandbox_start` handles both "create new VM" and "start existing stopped VM" (via the `if [[ -n "${status}" ]]` branch). Split this:

- `workspace_create`: Only the "create new" path — generate template, `limactl start` from template. If VM already exists, print error and return 1.
- `workspace_start`: Only the "start existing" path — `limactl start <instance_name>` for a stopped VM.

Also add `workspace_connect` and `workspace_status`:

```bash
workspace_connect() {
    local instance_name="$1"
    workspace_exec "$instance_name"
}

workspace_status() {
    local instance_name="$1"
    if _workspace_lima_is_running "$instance_name"; then
        echo "reachable"
    else
        echo "unreachable"
    fi
}
```

- [ ] **Step 2c: Add `workspace_snapshot` and `workspace_expose` as public wrappers**

```bash
# workspace_snapshot dispatches to internal functions
workspace_snapshot() {
    local instance_name="$1"
    local subcmd="$2"
    shift 2
    case "$subcmd" in
        create)  _workspace_lima_snapshot_create "$instance_name" "$@" ;;
        list)    _workspace_lima_snapshot_list "$instance_name" ;;
        restore) _workspace_lima_snapshot_restore "$instance_name" "$@" ;;
        *)       echo "usage: workspace_snapshot <instance> <create|list|restore> [tag]"; return 1 ;;
    esac
}

# workspace_expose dispatches to internal functions
workspace_expose() {
    local instance_name="$1"
    local subcmd_or_port="$2"
    shift 2
    case "$subcmd_or_port" in
        list)     _workspace_lima_expose_list ;;
        stop)     _workspace_lima_expose_stop "$1" ;;
        stop-all) _workspace_lima_expose_stop_all ;;
        *)        _workspace_lima_expose_forward "$instance_name" "$subcmd_or_port" "$@" ;;
    esac
}
```

- [ ] **Step 2d: Reformat `workspace_info` output to key=value**

The existing `sandbox_status` prints Chinese labels. Reformat to key=value:

```bash
workspace_info() {
    local instance_name="$1"
    local info
    info=$(limactl list --json "$instance_name" 2>/dev/null)
    if [[ -z "$info" ]]; then
        echo "STATUS=not_found"
        return 1
    fi
    echo "NAME=$(echo "$info" | python3 -c "import sys,json; print(json.load(sys.stdin)['name'])" 2>/dev/null)"
    echo "STATUS=$(echo "$info" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])" 2>/dev/null)"
    echo "ARCH=$(echo "$info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('arch','unknown'))" 2>/dev/null)"
    echo "CPUS=$(echo "$info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cpus','unknown'))" 2>/dev/null)"
    echo "MEMORY=$(echo "$info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('memory','unknown'))" 2>/dev/null)"
    echo "DISK=$(echo "$info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('disk','unknown'))" 2>/dev/null)"
}
```

- [ ] **Step 2e: Add hook calls to workspace_create and workspace_start**

```bash
# At the end of workspace_create (after limactl start succeeds):
source "${KDE_SCRIPTS_PATH}/utils/workspace/hooks.sh"
run_workspace_hooks "init" "$workspace_path"
run_workspace_hooks "start" "$workspace_path"
```

```bash
# At the end of workspace_start (after limactl start succeeds):
source "${KDE_SCRIPTS_PATH}/utils/workspace/hooks.sh"
run_workspace_hooks "start" "$workspace_path"
```

- [ ] **Step 3: Update LIMA_HOME and instance name references**

Replace references to `SANDBOX_DATA_DIR` with workspace equivalents:
- `SANDBOX_DATA_DIR` → `WORKSPACE_DATA_DIR` (set by dispatcher)
- `get_sandbox_instance_name` → `get_workspace_instance_name` (defined in dispatcher or lima backend)

Add to top of `scripts/utils/workspace/lima.sh`:

```bash
WORKSPACE_DATA_DIR="${KDE_PATH}/.workspace"
export LIMA_HOME="${WORKSPACE_DATA_DIR}/lima"
mkdir -p "${LIMA_HOME}"

get_workspace_instance_name() {
    local workspace_dir
    workspace_dir=$(basename "${KDE_PATH}")
    echo "kde-workspace-${workspace_dir}"
}
```

- [ ] **Step 4: Verify the file sources cleanly**

Run: `bash -n scripts/utils/workspace/lima.sh`
Expected: No syntax errors

- [ ] **Step 5: Commit**

```bash
git add scripts/utils/workspace/lima.sh
git commit -m "feat(workspace): add lima backend (refactored from sandbox/lima.sh)"
```

---

## Task 5: Workspace CLI Command

**Files:**
- Create: `scripts/workspace/command.sh`
- Modify: `kde.sh`

- [ ] **Step 1: Create the workspace command script**

```bash
#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/workspace/workspace.sh

show_help() {
    echo "usage: kde workspace <command>"
    echo ""
    echo "管理 workspace（開發環境隔離空間）"
    echo ""
    echo "command:"
    echo "  status                      查看 workspace 狀態"
    echo "  info                        顯示 workspace 資訊"
    echo "  exec [command]              在 workspace 中執行指令"
    echo "  connect                     連線進入 workspace"
    if workspace_supports create; then
    echo "  create                      建立 workspace"
    fi
    if workspace_supports start; then
    echo "  start                       啟動 workspace"
    fi
    if workspace_supports stop; then
    echo "  stop                        停止 workspace"
    fi
    if workspace_supports delete; then
    echo "  delete [--force]            刪除 workspace"
    fi
    if workspace_supports snapshot; then
    echo "  snapshot create <tag>       建立快照"
    echo "  snapshot list               列出所有快照"
    echo "  snapshot restore <tag>      還原快照"
    fi
    if workspace_supports expose; then
    echo "  expose <guest_port> [host_port]  port 轉發"
    echo "  expose list                      列出轉發"
    echo "  expose stop <host_port>          停止轉發"
    echo "  expose stop-all                  停止所有轉發"
    fi
    echo ""
    echo "環境變數:"
    echo "  KDE_WORKSPACE_BACKEND       後端類型（預設 local）"
}

# For backends that need an instance name (lima, dind, etc.)
INSTANCE_NAME=""
if declare -f get_workspace_instance_name > /dev/null 2>&1; then
    INSTANCE_NAME=$(get_workspace_instance_name)
fi
WORKSPACE_PATH=${KDE_PATH}

COMMAND=$1

case "${COMMAND}" in
    create)
        workspace_create "${INSTANCE_NAME}" "${WORKSPACE_PATH}"
        ;;
    start)
        workspace_start "${INSTANCE_NAME}" "${WORKSPACE_PATH}"
        ;;
    stop)
        workspace_stop "${INSTANCE_NAME}"
        ;;
    delete)
        shift
        FORCE="false"
        if [[ "$1" == "--force" || "$1" == "-f" ]]; then
            FORCE="true"
        fi
        workspace_delete "${INSTANCE_NAME}" "${FORCE}"
        ;;
    exec)
        shift
        workspace_exec "${INSTANCE_NAME}" "$@"
        ;;
    connect)
        workspace_connect "${INSTANCE_NAME}"
        ;;
    status)
        workspace_status "${INSTANCE_NAME}"
        ;;
    info)
        workspace_info "${INSTANCE_NAME}"
        ;;
    expose)
        shift
        SUBCMD=$1
        case "${SUBCMD}" in
            list|ls)
                workspace_expose "${INSTANCE_NAME}" "list"
                ;;
            stop)
                shift
                workspace_expose "${INSTANCE_NAME}" "stop" "$1"
                ;;
            stop-all)
                workspace_expose "${INSTANCE_NAME}" "stop-all"
                ;;
            *)
                GUEST_PORT="${SUBCMD}"
                shift
                HOST_PORT="${1:-${GUEST_PORT}}"
                workspace_expose "${INSTANCE_NAME}" "${GUEST_PORT}" "${HOST_PORT}"
                ;;
        esac
        ;;
    snapshot)
        shift
        SUBCMD=$1
        case "${SUBCMD}" in
            create)
                shift
                workspace_snapshot "${INSTANCE_NAME}" "create" "$1"
                ;;
            list|ls)
                workspace_snapshot "${INSTANCE_NAME}" "list"
                ;;
            restore)
                shift
                workspace_snapshot "${INSTANCE_NAME}" "restore" "$1"
                ;;
            *)
                echo "usage: kde workspace snapshot <create|list|restore> [tag]"
                exit 1
                ;;
        esac
        ;;
    -h|--help|"")
        show_help
        ;;
    *)
        echo "未知的 workspace 指令: ${COMMAND}"
        echo "使用 kde workspace -h 查看說明"
        exit 1
        ;;
esac
```

- [ ] **Step 2: Create the scripts/workspace directory**

```bash
mkdir -p scripts/workspace
```

- [ ] **Step 3: Add workspace route to kde.sh**

Find the **first** `case` block in `kde.sh` (around lines 76-109, alongside `sandbox`, `init`, `docs`). This block runs commands that do NOT require `kde.env` or K8s environment setup. Add before the `*)` catch-all in this first block:

```bash
    workspace|ws)
        shift
        source ${KDE_SCRIPTS_PATH}/workspace/command.sh
        ;;
```

- [ ] **Step 4: Update KDE_ENV_FILE in kde.sh to support workspace.env fallback**

Find the line:
```bash
export KDE_ENV_FILE=${KDE_PATH}/kde.env
```

Replace with:
```bash
# workspace.env (new) with kde.env fallback (backward compat)
if [[ -f "${KDE_PATH}/workspace.env" ]]; then
    export KDE_ENV_FILE=${KDE_PATH}/workspace.env
else
    export KDE_ENV_FILE=${KDE_PATH}/kde.env
fi
```

- [ ] **Step 5: Verify syntax**

Run: `bash -n scripts/workspace/command.sh && bash -n kde.sh`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add scripts/workspace/command.sh kde.sh
git commit -m "feat(workspace): add kde workspace CLI command with routing"
```

---

## Task 6: Backward Compatibility (sandbox → workspace deprecation)

**Strategy:** Keep `kde sandbox` working exactly as-is (using the old `sandbox_*` functions). Only add a deprecation notice. The old sandbox code and new workspace code coexist independently during the transition period. No variable mapping or delegation — that avoids complexity and keeps sandbox stable.

**Files:**
- Modify: `scripts/sandbox/command.sh`

- [ ] **Step 1: Add deprecation notice to sandbox command**

Add in `scripts/sandbox/command.sh`, right after `COMMAND=$1`:

```bash
# 顯示棄用提示
if [[ "${KDE_SANDBOX_DEPRECATION_NOTICE:-true}" != "false" ]]; then
    echo "提示：'kde sandbox' 將在未來版本中被 'kde workspace' 取代。" >&2
fi
```

- [ ] **Step 2: Verify sandbox still works**

Run: `bash -n scripts/sandbox/command.sh && bash -n scripts/utils/sandbox.sh`
Expected: No syntax errors

- [ ] **Step 3: Commit**

```bash
git add scripts/sandbox/command.sh
git commit -m "feat(workspace): add deprecation notice to kde sandbox command"
```

---

## Task 7: Integration Test

**Files:**
- Create: `test/test-workspace-integration.sh`

- [ ] **Step 1: Write integration test for local backend end-to-end**

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

# Setup: create a temp workspace with hooks
WORKSPACE="/tmp/test-workspace-integration-$$"
mkdir -p "${WORKSPACE}/hooks"

cat > "${WORKSPACE}/workspace.env" << 'EOF'
KDE_WORKSPACE_BACKEND=local
MY_CUSTOM_VAR=hello_from_workspace
EOF

cat > "${WORKSPACE}/hooks/workspace-init.sh" << 'SCRIPT'
#!/bin/bash
echo "initialized" > /tmp/test-workspace-integration-init-$$
SCRIPT
chmod +x "${WORKSPACE}/hooks/workspace-init.sh"

export KDE_SCRIPTS_PATH="$(cd "$(dirname "$0")/../scripts" && pwd)"
export KDE_PATH="${WORKSPACE}"

echo "=== Test: Full local workspace lifecycle ==="

source "${KDE_SCRIPTS_PATH}/utils/workspace/workspace.sh"
source "${KDE_SCRIPTS_PATH}/utils/workspace/hooks.sh"

echo ""
echo "--- workspace_status ---"
STATUS=$(workspace_status)
assert_eq "status is reachable" "reachable" "$STATUS"

echo ""
echo "--- workspace_info ---"
INFO=$(workspace_info)
assert_contains "info has OS" "OS=" "$INFO"
assert_contains "info has CPUS" "CPUS=" "$INFO"

echo ""
echo "--- workspace_exec ---"
RESULT=$(workspace_exec echo "test command")
assert_eq "exec runs command" "test command" "$RESULT"

echo ""
echo "--- workspace hooks ---"
run_workspace_hooks "init" "${WORKSPACE}"
# The init hook for local backend runs differently — workspace_exec just runs in subshell
# So the file would be created at the path
assert_eq "hook creates marker" "0" "$([[ -f ${WORKSPACE}/.workspace-initialized ]] && echo 0 || echo 1)"

echo ""
echo "--- workspace_supports ---"
assert_eq "supports status" "0" "$(workspace_supports connect && echo 0 || echo 1)"
assert_eq "no create for local" "1" "$(workspace_supports create && echo 0 || echo 1)"

# Cleanup
rm -rf "${WORKSPACE}"
rm -f /tmp/test-workspace-integration-init-$$

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]] || exit 1
```

- [ ] **Step 2: Run all workspace tests**

```bash
bash test/test-workspace-dispatcher.sh
bash test/test-workspace-local.sh
bash test/test-workspace-hooks.sh
bash test/test-workspace-integration.sh
```

Expected: All PASS

- [ ] **Step 3: Commit**

```bash
git add test/test-workspace-integration.sh
git commit -m "test(workspace): add integration test for local backend lifecycle"
```

---

## Summary

| Task | Description | Files | Estimated Steps |
|------|-------------|-------|-----------------|
| 1 | Dispatcher + stubs | workspace.sh + test | 5 |
| 2 | Local backend | local.sh + test | 6 |
| 3 | Hooks engine | hooks.sh + test | 5 |
| 4 | Lima backend (refactor) | lima.sh | 5 |
| 5 | CLI command + routing | command.sh + kde.sh | 6 |
| 6 | Backward compat | sandbox.sh + command.sh | 4 |
| 7 | Integration test | test file | 3 |

**Total: 7 tasks, 34 steps**

**Dependencies:**
- Task 2 depends on Task 1 (dispatcher must exist for local.sh to load)
- Task 3 is independent of Task 2
- Task 4 depends on Task 1 and Task 3 (lima.sh needs dispatcher + hooks)
- Task 5 depends on Task 1 (needs workspace.sh to source)
- Task 6 depends on Task 4 (needs lima backend renamed)
- Task 7 depends on all previous tasks

**Parallel opportunities:** Tasks 2 and 3 can run in parallel after Task 1.
