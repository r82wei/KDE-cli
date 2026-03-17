#!/bin/bash
set -eo pipefail

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected='$expected', actual='$actual')"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_exists() {
    local desc="$1" filepath="$2"
    if [[ -f "$filepath" ]]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (file not found: $filepath)"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_not_exists() {
    local desc="$1" filepath="$2"
    if [[ ! -f "$filepath" ]]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (file should not exist: $filepath)"
        FAIL=$((FAIL + 1))
    fi
}

# Setup
export KDE_SCRIPTS_PATH="$(cd "$(dirname "$0")/../scripts" && pwd)"
export KDE_PATH="/tmp/test-workspace-hooks-$$"
export KDE_WORKSPACE_BACKEND="local"
mkdir -p "${KDE_PATH}"

source "${KDE_SCRIPTS_PATH}/utils/workspace/workspace.sh"
source "${KDE_SCRIPTS_PATH}/utils/workspace/hooks.sh"

TMPDIR_TEST="/tmp/test-workspace-hooks-workdir-$$"
mkdir -p "${TMPDIR_TEST}/hooks"

# ---------------------------------------------------------------------------
echo "=== Test: parse_hook_exec_mode defaults to direct when no header ==="
cat > "${TMPDIR_TEST}/hooks/no-header.sh" <<'SCRIPT'
#!/bin/bash
echo "hello"
SCRIPT
MODE=$(parse_hook_exec_mode "${TMPDIR_TEST}/hooks/no-header.sh")
assert_eq "default mode is direct" "direct" "$MODE"

# ---------------------------------------------------------------------------
echo ""
echo "=== Test: parse_hook_exec_mode reads container mode from header ==="
cat > "${TMPDIR_TEST}/hooks/container-hook.sh" <<'SCRIPT'
#!/bin/bash
# KDE_HOOK_EXEC_MODE=container
# KDE_HOOK_IMAGE=alpine:latest
echo "container hook"
SCRIPT
MODE=$(parse_hook_exec_mode "${TMPDIR_TEST}/hooks/container-hook.sh")
assert_eq "mode is container" "container" "$MODE"

# ---------------------------------------------------------------------------
echo ""
echo "=== Test: parse_hook_image reads image from header ==="
IMAGE=$(parse_hook_image "${TMPDIR_TEST}/hooks/container-hook.sh")
assert_eq "image is alpine:latest" "alpine:latest" "$IMAGE"

# ---------------------------------------------------------------------------
echo ""
echo "=== Test: run_workspace_hooks init creates marker file ==="
cat > "${TMPDIR_TEST}/hooks/workspace-init.sh" <<SCRIPT
#!/bin/bash
touch /tmp/test-workspace-hooks-init-ran-$$
SCRIPT
run_workspace_hooks "init" "$TMPDIR_TEST"
assert_file_exists "init hook ran" "/tmp/test-workspace-hooks-init-ran-$$"
assert_file_exists "marker created" "${TMPDIR_TEST}/.workspace-initialized"

# ---------------------------------------------------------------------------
echo ""
echo "=== Test: run_workspace_hooks init skips re-run if marker exists ==="
# Overwrite the hook script — if it runs, it would create the rerun file
cat > "${TMPDIR_TEST}/hooks/workspace-init.sh" <<SCRIPT
#!/bin/bash
touch /tmp/test-workspace-hooks-rerun-$$
SCRIPT
OUTPUT=$(run_workspace_hooks "init" "$TMPDIR_TEST")
assert_file_not_exists "init hook did not re-run" "/tmp/test-workspace-hooks-rerun-$$"
assert_eq "skip message printed" "Workspace 已初始化，跳過 init hook" "$OUTPUT"

# ---------------------------------------------------------------------------
echo ""
echo "=== Test: no hooks dir = no error (silent return) ==="
EMPTY_DIR="/tmp/test-workspace-hooks-empty-$$"
mkdir -p "$EMPTY_DIR"
run_workspace_hooks "init" "$EMPTY_DIR"
assert_eq "silent return success" "0" "$?"

# Cleanup
rm -rf "${KDE_PATH}" "${TMPDIR_TEST}" "${EMPTY_DIR}"
rm -f "/tmp/test-workspace-hooks-init-ran-$$"
rm -f "/tmp/test-workspace-hooks-rerun-$$"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]] || exit 1
