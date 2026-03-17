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
