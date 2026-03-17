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

# Setup
export KDE_SCRIPTS_PATH="$(cd "$(dirname "$0")/../scripts" && pwd)"
export KDE_PATH="/tmp/test-env-dispatcher-$$"
export ENV_PATH="/tmp/test-env-dispatcher-$$/environments/test-env"
mkdir -p "${ENV_PATH}"

echo "=== Test: Dispatcher fails without type ==="
unset KDE_ENVIRONMENT_TYPE
unset KDE_ENVIRONMENT_BACKEND
EXIT_CODE=0
bash -c "source ${KDE_SCRIPTS_PATH}/utils/environment/environment.sh" 2>/dev/null || EXIT_CODE=$?
assert_eq "fails without type" "1" "$EXIT_CODE"

echo ""
echo "=== Test: Custom backend loads from env directory ==="
export KDE_ENVIRONMENT_TYPE="custom"
export KDE_ENVIRONMENT_BACKEND="custom"
mkdir -p "${ENV_PATH}/backend"
cat > "${ENV_PATH}/backend/environment.sh" << 'EOF'
_backend_env_create() { echo "custom create"; }
_backend_env_start() { echo "custom start"; }
_backend_env_stop() { echo "custom stop"; }
_backend_env_delete() { echo "custom delete"; }
_backend_env_status() { echo "running"; }
env_custom_exec() { echo "custom exec"; }
EOF
source "${KDE_SCRIPTS_PATH}/utils/environment/environment.sh"
RESULT=$(_backend_env_create)
assert_eq "custom backend loaded" "custom create" "$RESULT"

echo ""
echo "=== Test: load_environment_config backward compat ==="
# Create a legacy k8s.env
mkdir -p "/tmp/test-env-dispatcher-$$-legacy"
cat > "/tmp/test-env-dispatcher-$$-legacy/k8s.env" << 'EOF'
ENV_NAME=test
ENV_TYPE=kind
EOF
unset KDE_ENVIRONMENT_TYPE
unset KDE_ENVIRONMENT_BACKEND
load_environment_config "/tmp/test-env-dispatcher-$$-legacy"
assert_eq "type inferred from legacy" "k8s" "$KDE_ENVIRONMENT_TYPE"
assert_eq "backend inferred from ENV_TYPE" "kind" "$KDE_ENVIRONMENT_BACKEND"
rm -rf "/tmp/test-env-dispatcher-$$-legacy"

# Cleanup
rm -rf "${KDE_PATH}"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]] || exit 1
