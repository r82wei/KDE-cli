#!/bin/bash

# 測試 MANUAL_ONLY 功能
# 驗證 KDE_PIPELINE_STAGE_<stage>_MANUAL_ONLY=true 的行為

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 測試結果
PASSED=0
FAILED=0

# 測試函數
test_case() {
    local test_name=$1
    echo ""
    echo "=========================================="
    echo "測試: ${test_name}"
    echo "=========================================="
}

pass() {
    PASSED=$((PASSED + 1))
    echo -e "${GREEN}✓ 測試通過${NC}"
}

fail() {
    FAILED=$((FAILED + 1))
    echo -e "${RED}✗ 測試失敗: $1${NC}"
}

# 載入 pipeline.sh
source ${KDE_SCRIPTS_PATH}/utils/pipeline.sh

# 測試 1: is_stage_manual_only 函數 - 預設值
test_case "is_stage_manual_only 函數 - 預設值（false）"
unset KDE_PIPELINE_STAGE_test_MANUAL_ONLY
result=$(is_stage_manual_only "test")
if [[ "${result}" == "false" ]]; then
    pass
else
    fail "預期 'false'，實際得到 '${result}'"
fi

# 測試 2: is_stage_manual_only 函數 - 設定為 true
test_case "is_stage_manual_only 函數 - 設定為 true"
export KDE_PIPELINE_STAGE_test_MANUAL_ONLY=true
result=$(is_stage_manual_only "test")
if [[ "${result}" == "true" ]]; then
    pass
else
    fail "預期 'true'，實際得到 '${result}'"
fi

# 測試 3: is_stage_manual_only 函數 - 設定為 false
test_case "is_stage_manual_only 函數 - 明確設定為 false"
export KDE_PIPELINE_STAGE_test_MANUAL_ONLY=false
result=$(is_stage_manual_only "test")
if [[ "${result}" == "false" ]]; then
    pass
else
    fail "預期 'false'，實際得到 '${result}'"
fi

# 測試 4: 連字號轉底線
test_case "is_stage_manual_only 函數 - 階段名稱包含連字號"
export KDE_PIPELINE_STAGE_security_scan_MANUAL_ONLY=true
result=$(is_stage_manual_only "security-scan")
if [[ "${result}" == "true" ]]; then
    pass
else
    fail "預期 'true'，實際得到 '${result}'"
fi

# 顯示測試結果
echo ""
echo "=========================================="
echo "測試完成"
echo "=========================================="
echo -e "通過: ${GREEN}${PASSED}${NC}"
echo -e "失敗: ${RED}${FAILED}${NC}"
echo ""

if [[ ${FAILED} -eq 0 ]]; then
    echo -e "${GREEN}✓ 所有測試通過！${NC}"
    exit 0
else
    echo -e "${RED}✗ 有測試失敗${NC}"
    exit 1
fi
