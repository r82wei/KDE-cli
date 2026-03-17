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

# Setup: create a temp workspace with hooks
WORKSPACE="/tmp/test-workspace-integration-$$"
mkdir -p "${WORKSPACE}/hooks"

cat > "${WORKSPACE}/workspace.env" << 'EOF'
KDE_WORKSPACE_BACKEND=local
MY_CUSTOM_VAR=hello_from_workspace
EOF

cat > "${WORKSPACE}/hooks/workspace-init.sh" << SCRIPT
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
assert_eq "hook creates marker" "0" "$([[ -f ${WORKSPACE}/.workspace-initialized ]] && echo 0 || echo 1)"

echo ""
echo "--- workspace_supports ---"
assert_eq "supports connect" "0" "$(workspace_supports connect && echo 0 || echo 1)"
assert_eq "no create for local" "1" "$(workspace_supports create && echo 0 || echo 1)"

# Cleanup
rm -rf "${WORKSPACE}"
rm -f /tmp/test-workspace-integration-init-$$

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]] || exit 1
