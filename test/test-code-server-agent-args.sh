#!/bin/bash

# 測試 kde code-server 的參數解析（parse_code_server_args）
# 比照 test/test-pod-exec-args.sh 的模式

echo "===== code-server 參數解析測試 ====="
echo ""

source "$(dirname "${BASH_SOURCE[0]}")/../scripts/utils/code-server.sh"

TOTAL=0; PASS=0; FAIL=0

assert_eq() { # $1=描述 $2=預期 $3=實際
    TOTAL=$((TOTAL+1))
    if [[ "$3" == "$2" ]]; then
        echo "  ✅ $1：'$3'"; PASS=$((PASS+1))
    else
        echo "  ❌ $1：預期 '$2'，實際 '$3'"; FAIL=$((FAIL+1))
    fi
}

assert_rc() { # $1=描述 $2=預期退出碼 $3=實際退出碼
    TOTAL=$((TOTAL+1))
    if [[ "$3" == "$2" ]]; then
        echo "  ✅ $1：退出碼 $3"; PASS=$((PASS+1))
    else
        echo "  ❌ $1：預期退出碼 $2，實際 $3"; FAIL=$((FAIL+1))
    fi
}

echo "測試 1：未給 --agent"
echo "--------------------"
rc=0; parse_code_server_args -p 9090 || rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "AGENTS 數量為 0" "0" "${#CODE_SERVER_AGENTS[@]}"
assert_eq "AGENTS_CSV 為空" "" "${CODE_SERVER_AGENTS_CSV}"
assert_eq "PORT 正確解析" "9090" "${CODE_SERVER_PORT}"
echo ""

echo "測試 2：單一 --agent"
echo "--------------------"
rc=0; parse_code_server_args --agent claude || rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "AGENTS_CSV" "claude" "${CODE_SERVER_AGENTS_CSV}"
echo ""

echo "測試 3：多次指定 --agent，順序保留"
echo "----------------------------------"
rc=0; parse_code_server_args --agent claude -a codex || rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "AGENTS 數量為 2" "2" "${#CODE_SERVER_AGENTS[@]}"
assert_eq "AGENTS_CSV 順序保留" "claude,codex" "${CODE_SERVER_AGENTS_CSV}"
echo ""

echo "測試 4：與其他旗標混用"
echo "----------------------"
rc=0; parse_code_server_args -d -p 8081 -n cs-x -a claude || rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "DAEMON" "true" "${CODE_SERVER_DAEMON}"
assert_eq "PORT" "8081" "${CODE_SERVER_PORT}"
assert_eq "NAME" "cs-x" "${CODE_SERVER_NAME}"
assert_eq "AGENTS_CSV" "claude" "${CODE_SERVER_AGENTS_CSV}"
echo ""

echo "測試 5：不合法的 agent 名稱"
echo "---------------------------"
rc=0; parse_code_server_args --agent "bad/name" 2>/dev/null || rc=$?
assert_rc "退出碼為 1" 1 "${rc}"
echo ""

echo "測試 6：--agent 缺少值"
echo "----------------------"
rc=0; parse_code_server_args --agent 2>/dev/null || rc=$?
assert_rc "退出碼為 1" 1 "${rc}"
echo ""

echo "測試 7：--help 回傳 2"
echo "---------------------"
rc=0; parse_code_server_args --help >/dev/null 2>&1 || rc=$?
assert_rc "退出碼為 2" 2 "${rc}"
echo ""

echo "測試 8：說明文字含 --agent"
echo "--------------------------"
help_out=$(show_code_server_help 2>&1)
TOTAL=$((TOTAL+1))
if echo "${help_out}" | grep -q -- "--agent"; then
    echo "  ✅ 說明文字含 --agent"; PASS=$((PASS+1))
else
    echo "  ❌ 說明文字未提到 --agent"; FAIL=$((FAIL+1))
fi
echo ""

echo "測試 9：-v 掛載仍正常解析（回歸）"
echo "--------------------------------"
rc=0; parse_code_server_args -v /tmp/a -v /tmp/b || rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "MOUNTS 數量為 2" "2" "${#CODE_SERVER_MOUNTS[@]}"
assert_eq "第一個 MOUNT" "/tmp/a" "${CODE_SERVER_MOUNTS[0]}"
echo ""

echo "測試 10：未知參數回傳 1"
echo "-----------------------"
rc=0; parse_code_server_args --nosuchflag 2>/dev/null >/dev/null || rc=$?
assert_rc "退出碼為 1" 1 "${rc}"
echo ""

echo "===== 測試完成 ====="
echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
