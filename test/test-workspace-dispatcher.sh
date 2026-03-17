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

assert_contains() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == *"$expected"* ]]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected to contain '$expected', got='$actual')"
        FAIL=$((FAIL + 1))
    fi
}

assert_fn_exists() {
    local desc="$1" fn_name="$2"
    if declare -f "$fn_name" > /dev/null 2>&1; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (function '$fn_name' not defined)"
        FAIL=$((FAIL + 1))
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
