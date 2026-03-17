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
export KDE_PATH="/tmp/test-secret-provider-$$"
export PROJECT_PATH="${KDE_PATH}/project"
mkdir -p "${PROJECT_PATH}/scripts"

source "${KDE_SCRIPTS_PATH}/utils/secret-provider.sh"

echo "=== Test: Run direct-mode secret provider ==="
cat > "${PROJECT_PATH}/scripts/secrets.sh" << 'EOF'
#!/bin/bash
echo "DB_HOST=localhost"
echo "DB_PASS=s3cret"
echo "API_KEY=abc123"
EOF
chmod +x "${PROJECT_PATH}/scripts/secrets.sh"
SECRETS=$(run_secret_provider "${PROJECT_PATH}/scripts/secrets.sh" "${PROJECT_PATH}")
assert_contains "has DB_HOST" "DB_HOST=localhost" "$SECRETS"
assert_contains "has DB_PASS" "DB_PASS=s3cret" "$SECRETS"
assert_contains "has API_KEY" "API_KEY=abc123" "$SECRETS"

echo ""
echo "=== Test: Convert secrets to Docker --env flags ==="
SECRETS="DB_HOST=localhost
DB_PASS=s3cret"
FLAGS=$(secrets_to_docker_env_flags "$SECRETS")
assert_contains "has --env DB_HOST" "--env DB_HOST=localhost" "$FLAGS"
assert_contains "has --env DB_PASS" "--env DB_PASS=s3cret" "$FLAGS"

echo ""
echo "=== Test: Empty provider path returns empty ==="
RESULT=$(run_secret_provider "" "${PROJECT_PATH}")
assert_eq "empty path returns empty" "" "$RESULT"

echo ""
echo "=== Test: Missing provider file returns error ==="
EXIT_CODE=0
run_secret_provider "/nonexistent/script.sh" "${PROJECT_PATH}" 2>/dev/null || EXIT_CODE=$?
assert_eq "missing file returns 1" "1" "$EXIT_CODE"

echo ""
echo "=== Test: get_stage_secret_provider global ==="
export KDE_PIPELINE_SECRET_PROVIDER="scripts/secrets.sh"
unset KDE_PIPELINE_STAGE_BUILD_SECRET_PROVIDER
RESULT=$(get_stage_secret_provider "build")
assert_eq "global provider" "scripts/secrets.sh" "$RESULT"

echo ""
echo "=== Test: get_stage_secret_provider stage override ==="
export KDE_PIPELINE_STAGE_DEPLOY_SECRET_PROVIDER="scripts/deploy-secrets.sh"
RESULT=$(get_stage_secret_provider "deploy")
assert_eq "stage override" "scripts/deploy-secrets.sh" "$RESULT"

echo ""
echo "=== Test: get_stage_secret_provider no provider ==="
unset KDE_PIPELINE_SECRET_PROVIDER
unset KDE_PIPELINE_STAGE_TEST_SECRET_PROVIDER
RESULT=$(get_stage_secret_provider "test")
assert_eq "no provider" "" "$RESULT"

# Cleanup
rm -rf "${KDE_PATH}"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]] || exit 1
