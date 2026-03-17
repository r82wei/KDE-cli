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

# Setup: mock a minimal backend
export KDE_SCRIPTS_PATH="$(cd "$(dirname "$0")/../scripts" && pwd)"

_backend_env_create() { echo "mock create"; }
_backend_env_start() { echo "mock start"; }
_backend_env_stop() { echo "mock stop"; }
_backend_env_delete() { echo "mock delete"; }
_backend_env_status() { echo "running"; }

echo "=== Test: K8s type sources successfully with valid backend ==="
source "${KDE_SCRIPTS_PATH}/utils/environment/types/k8s.sh"
assert_eq "sourced ok" "0" "$?"

echo ""
echo "=== Test: K8s type wraps backend create ==="
RESULT=$(env_create)
assert_eq "env_create calls backend" "mock create" "$RESULT"

echo ""
echo "=== Test: K8s type wraps backend status ==="
RESULT=$(env_status)
assert_eq "env_status calls backend" "running" "$RESULT"

echo ""
echo "=== Test: K8s type defines type-specific functions ==="
assert_fn_exists "env_k8s_exec exists" "env_k8s_exec"
assert_fn_exists "env_k8s_create_namespace exists" "env_k8s_create_namespace"
assert_fn_exists "env_k8s_delete_namespace exists" "env_k8s_delete_namespace"
assert_fn_exists "env_k8s_load_kubeconfig exists" "env_k8s_load_kubeconfig"
assert_fn_exists "env_k8s_load_image exists" "env_k8s_load_image"

echo ""
echo "=== Test: Backend validation catches missing function ==="
EXIT_CODE=0
bash -c "
_backend_env_start() { :; }
_backend_env_stop() { :; }
_backend_env_delete() { :; }
_backend_env_status() { :; }
source ${KDE_SCRIPTS_PATH}/utils/environment/types/k8s.sh
" 2>/dev/null || EXIT_CODE=$?
assert_eq "validation catches missing _backend_env_create" "1" "$EXIT_CODE"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]] || exit 1
