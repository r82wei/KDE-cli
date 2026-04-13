#!/bin/bash

# 測試 Pipeline 參數解析
# 用於驗證 --only、--from、--to 等參數是否正確從命令行傳遞

echo "===== Pipeline 參數解析測試 ====="
echo ""

# 載入必要的腳本
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/utils/pipeline.sh"

# 測試統計
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 測試函數
test_parse() {
    local test_name=$1
    shift
    echo "測試：${test_name}"
    echo "參數：$@"
    
    # 調用解析函數
    parse_pipeline_args "$@"
    local exit_code=$?
    
    # 顯示結果
    echo "  退出碼：${exit_code}"
    echo "  PIPELINE_ONLY_STAGE：'${PIPELINE_ONLY_STAGE}'"
    echo "  PIPELINE_FROM_STAGE：'${PIPELINE_FROM_STAGE}'"
    echo "  PIPELINE_TO_STAGE：'${PIPELINE_TO_STAGE}'"
    echo "  PIPELINE_MANUAL_MODE：${PIPELINE_MANUAL_MODE}"
    echo "  PIPELINE_SHELL_MODE：${PIPELINE_SHELL_MODE}"
    echo "  REMAINING_ARGS：${REMAINING_ARGS[@]}"
    echo ""
    
    return ${exit_code}
}

# 測試 1：--only test
test_parse "只執行 test 階段（空格語法）" myapp --only test

# 測試 2：--only=test
test_parse "只執行 test 階段（等號語法）" myapp --only=test

# 測試 3：--from test --to deploy
test_parse "從 test 到 deploy" myapp --from test --to deploy

# 測試 4：--from=test --to=deploy
test_parse "從 test 到 deploy（等號語法）" myapp --from=test --to=deploy

# 測試 5：--manual
test_parse "手動模式" myapp --manual

# 測試 6：--only build --manual
test_parse "只執行 build + 手動模式" myapp --only build --manual

# 測試 7：--shell
test_parse "Shell 模式" myapp --shell

# 測試 8：-s（--shell 短寫）
test_parse "Shell 模式（短寫）" myapp -s

# 測試 9：--only build --shell
test_parse "只執行 build + shell 模式" myapp --only build --shell

# 測試 10：驗證 --shell 同時設定 PIPELINE_SHELL_MODE 和 PIPELINE_MANUAL_MODE
echo "測試：--shell 同時設定 SHELL_MODE 和 MANUAL_MODE"
parse_pipeline_args myapp --shell
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [[ "${PIPELINE_SHELL_MODE}" == "true" && "${PIPELINE_MANUAL_MODE}" == "true" ]]; then
    echo "  ✅ --shell 正確設定 SHELL_MODE=true 和 MANUAL_MODE=true"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "  ❌ SHELL_MODE=${PIPELINE_SHELL_MODE}, MANUAL_MODE=${PIPELINE_MANUAL_MODE}（應該都是 true）"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 測試 11：驗證 --manual 不設定 PIPELINE_SHELL_MODE
echo "測試：--manual 不設定 SHELL_MODE"
parse_pipeline_args myapp --manual
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [[ "${PIPELINE_SHELL_MODE}" == "false" && "${PIPELINE_MANUAL_MODE}" == "true" ]]; then
    echo "  ✅ --manual 正確設定 MANUAL_MODE=true，SHELL_MODE=false"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "  ❌ SHELL_MODE=${PIPELINE_SHELL_MODE}, MANUAL_MODE=${PIPELINE_MANUAL_MODE}（應該 SHELL=false, MANUAL=true）"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 測試 12：錯誤測試 - --only 與 --from 同時使用
echo "測試：錯誤情況 - --only 與 --from 同時使用"
echo "參數：myapp --only test --from build"
parse_pipeline_args myapp --only test --from build
exit_code=$?
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [[ ${exit_code} -eq 1 ]]; then
    echo "  ✅ 正確檢測到錯誤"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "  ❌ 應該要報錯"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 測試 8：驗證環境變數不會影響
echo "測試：環境變數不會影響參數"
export PIPELINE_ONLY_STAGE="should-be-ignored"
test_parse "指定 --only test（環境變數應被忽略）" myapp --only test
result="${PIPELINE_ONLY_STAGE}"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [[ "${result}" == "test" ]]; then
    echo "  ✅ 環境變數被正確重置，使用命令行參數"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "  ❌ 環境變數影響了命令行參數"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 測試：--no-tty 基本解析
echo "測試：--no-tty 設定 KDE_PIPELINE_NO_TTY=true"
parse_pipeline_args myapp --no-tty
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [[ "${KDE_PIPELINE_NO_TTY}" == "true" ]]; then
    echo "  ✅ --no-tty 正確設定 KDE_PIPELINE_NO_TTY=true"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "  ❌ KDE_PIPELINE_NO_TTY=${KDE_PIPELINE_NO_TTY}（應該是 true）"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 測試：--no-tty 與 --only 組合
echo "測試：--no-tty 與 --only build 組合"
parse_pipeline_args myapp --only build --no-tty
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [[ "${KDE_PIPELINE_NO_TTY}" == "true" && "${PIPELINE_ONLY_STAGE}" == "build" ]]; then
    echo "  ✅ --no-tty + --only build 正確設定"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "  ❌ KDE_PIPELINE_NO_TTY=${KDE_PIPELINE_NO_TTY}, PIPELINE_ONLY_STAGE=${PIPELINE_ONLY_STAGE}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 測試：--no-tty 與 --shell 互斥
echo "測試：錯誤情況 - --no-tty 與 --shell 同時使用"
echo "參數：myapp --no-tty --shell"
parse_pipeline_args myapp --no-tty --shell 2>/dev/null
exit_code=$?
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [[ ${exit_code} -eq 1 ]]; then
    echo "  ✅ 正確檢測到 --no-tty 與 --shell 互斥錯誤"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "  ❌ 應該要報錯（exit_code=${exit_code}）"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 測試：KDE_PIPELINE_NO_TTY 在 parse_pipeline_args 間正確重置
echo "測試：KDE_PIPELINE_NO_TTY 在呼叫間正確重置"
parse_pipeline_args myapp --no-tty
parse_pipeline_args myapp
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [[ "${KDE_PIPELINE_NO_TTY}" == "false" ]]; then
    echo "  ✅ KDE_PIPELINE_NO_TTY 在第二次呼叫後正確重置為 false"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "  ❌ KDE_PIPELINE_NO_TTY=${KDE_PIPELINE_NO_TTY}（應該是 false）"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# 測試 9：filter_pipeline_stages 功能測試
echo "===== filter_pipeline_stages 測試 ====="
echo ""

test_filter() {
    local test_name=$1
    local all_stages=$2
    local expected=$3
    shift 3
    
    echo "測試：${test_name}"
    echo "所有階段：${all_stages}"
    echo "設定參數：$@"
    
    # 設置參數
    parse_pipeline_args myapp "$@" > /dev/null
    
    # 調用過濾函數
    local result=$(filter_pipeline_stages "${all_stages}")
    
    echo "  結果：'${result}'"
    echo "  預期：'${expected}'"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [[ "${result}" == "${expected}" ]]; then
        echo "  ✅ 通過"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "  ❌ 失敗"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""
}

test_filter "只執行 test" "build test release deploy" "test" --only test
test_filter "從 test 開始" "build test release deploy" "test release deploy" --from test
test_filter "執行到 release" "build test release deploy" "build test release" --to release
test_filter "從 test 到 release" "build test release deploy" "test release" --from test --to release
test_filter "執行全部（無參數）" "build test release deploy" "build test release deploy"

echo "===== 測試完成 ====="
echo ""
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
