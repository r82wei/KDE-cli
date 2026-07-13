#!/bin/bash

# 測試 pod-exec 參數解析（parse_pod_exec_args）
# 驗證 pod 名稱與 --command 旗標是否正確解析

echo "===== pod-exec 參數解析測試 ====="
echo ""

# 載入必要的腳本
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/utils/project.sh"

# 測試統計
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 斷言輔助：檢查全域變數值
assert_eq() {
    local label=$1
    local expected=$2
    local actual=$3
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [[ "${actual}" == "${expected}" ]]; then
        echo "  ✅ ${label}：'${actual}'"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "  ❌ ${label}：預期 '${expected}'，實際 '${actual}'"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

assert_rc() {
    local label=$1
    local expected=$2
    local actual=$3
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [[ "${actual}" == "${expected}" ]]; then
        echo "  ✅ ${label}：退出碼 ${actual}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "  ❌ ${label}：預期退出碼 ${expected}，實際 ${actual}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# 測試 1：只給 pod 名稱
echo "測試 1：只給 pod 名稱"
echo "--------------------"
parse_pod_exec_args "mypod"; rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "TARGET_POD" "mypod" "${POD_EXEC_TARGET_POD}"
assert_eq "COMMAND 為空" "" "${POD_EXEC_COMMAND}"
echo ""

# 測試 2：pod + --command（含空格的指令）
echo "測試 2：pod + --command（含空格）"
echo "--------------------------------"
parse_pod_exec_args "mypod" "--command" "ls -la /app"; rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "TARGET_POD" "mypod" "${POD_EXEC_TARGET_POD}"
assert_eq "COMMAND" "ls -la /app" "${POD_EXEC_COMMAND}"
echo ""

# 測試 3：--command 但未給 pod（TARGET_POD 應為空，交由呼叫方報錯）
echo "測試 3：--command 未給 pod"
echo "-------------------------"
parse_pod_exec_args "--command" "ls"; rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "TARGET_POD 為空" "" "${POD_EXEC_TARGET_POD}"
assert_eq "COMMAND" "ls" "${POD_EXEC_COMMAND}"
echo ""

# 測試 4：--command 缺少指令參數，應回傳非零
echo "測試 4：--command 缺少指令參數"
echo "------------------------------"
parse_pod_exec_args "mypod" "--command" 2>/dev/null; rc=$?
assert_rc "退出碼非零" 1 "${rc}"
echo ""

# 測試 5：完全沒有參數
echo "測試 5：沒有任何參數"
echo "--------------------"
parse_pod_exec_args; rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "TARGET_POD 為空" "" "${POD_EXEC_TARGET_POD}"
assert_eq "COMMAND 為空" "" "${POD_EXEC_COMMAND}"
echo ""

# 測試 6：pod 名稱出現在 --command 之後
echo "測試 6：--command 在前、pod 在後"
echo "--------------------------------"
parse_pod_exec_args "--command" "echo hi" "mypod"; rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "TARGET_POD" "mypod" "${POD_EXEC_TARGET_POD}"
assert_eq "COMMAND" "echo hi" "${POD_EXEC_COMMAND}"
echo ""

echo "===== 測試完成 ====="
echo "總測試數：${TOTAL_TESTS}"
echo "通過：${PASSED_TESTS}"
echo "失敗：${FAILED_TESTS}"
echo ""

if [[ ${FAILED_TESTS} -eq 0 ]]; then
    echo "🎉 所有測試都通過了！"
    exit 0
else
    echo "❌ 有 ${FAILED_TESTS} 個測試失敗"
    exit 1
fi
