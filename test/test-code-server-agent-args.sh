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

echo "測試 11：不合法的 port（非數字，回歸）"
echo "--------------------------------------"
rc=0; parse_code_server_args -p abc 2>/dev/null || rc=$?
assert_rc "退出碼為 1" 1 "${rc}"
echo ""

echo "測試 12：不合法的名稱（含空白，回歸）"
echo "------------------------------------"
rc=0; parse_code_server_args -n "bad name" 2>/dev/null || rc=$?
assert_rc "退出碼為 1" 1 "${rc}"
echo ""

echo "測試 13：-v 空值應報錯（回歸）"
echo "------------------------------"
rc=0; parse_code_server_args -v "" 2>/dev/null || rc=$?
assert_rc "退出碼為 1" 1 "${rc}"
echo ""

echo "測試 14：-w 空值應報錯（回歸）"
echo "------------------------------"
rc=0; parse_code_server_args -w "" 2>/dev/null || rc=$?
assert_rc "退出碼為 1" 1 "${rc}"
echo ""

echo "測試 15：呼叫後 IFS 應還原"
echo "--------------------------"
# 呼叫前先固定 IFS 為預設值（空白、tab、換行），避免受先前測試殘留狀態影響，
# 確保這裡驗證的是 parse_code_server_args 本身有無還原 IFS
IFS=$' \t\n'
old_ifs_before="${IFS}"
rc=0; parse_code_server_args --agent claude -a codex || rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "IFS 呼叫前後不變" "${old_ifs_before}" "${IFS}"
echo ""

echo "===== docker 參數組裝層 ====="
echo ""

# 組裝層需要 start_code_server 能跑到 docker run，因此準備假環境並 stub docker
export KDE_PATH="/tmp/kde-test-cs-agents"
export KDE_CLI_PATH="/tmp/kde-test-cs-agents/cli"
export CODE_SERVER_IMAGE="code-server:test"
export PASSWORD="testpass"

rm -rf "${KDE_PATH}"
mkdir -p "${KDE_PATH}/cli" "${KDE_PATH}/dir-a"

docker() {
    case "$1" in
        ps)  return 0 ;;
        run) echo "DOCKER_RUN: $*" ;;
    esac
}
stat() { echo "0"; }

assert_contains() { # $1=描述 $2=字串 $3=樣式
    TOTAL=$((TOTAL+1))
    if echo "$2" | grep -q -- "$3"; then
        echo "  ✅ $1"; PASS=$((PASS+1))
    else
        echo "  ❌ $1：輸出中找不到 '$3'"; FAIL=$((FAIL+1))
    fi
}

assert_not_contains() { # $1=描述 $2=字串 $3=樣式
    TOTAL=$((TOTAL+1))
    if echo "$2" | grep -q -- "$3"; then
        echo "  ❌ $1：輸出中不應出現 '$3'"; FAIL=$((FAIL+1))
    else
        echo "  ✅ $1"; PASS=$((PASS+1))
    fi
}

echo "測試 16：空的 agents CSV 不產生環境變數"
echo "---------------------------------------"
unset KDE_CODE_SERVER_AI_AGENTS_REINSTALL
out=$(start_code_server 8080 false cs-a1 "" "" "${KDE_PATH}/dir-a" 2>&1)
assert_not_contains "不含 KDE_CODE_SERVER_AI_AGENTS" "${out}" "KDE_CODE_SERVER_AI_AGENTS"
echo ""

echo "測試 17：非空 agents CSV 產生環境變數"
echo "-------------------------------------"
out=$(start_code_server 8080 false cs-a2 "" "claude,codex" "${KDE_PATH}/dir-a" 2>&1)
assert_contains "含 KDE_CODE_SERVER_AI_AGENTS=claude,codex" "${out}" "KDE_CODE_SERVER_AI_AGENTS=claude,codex"
echo ""

echo "測試 18：REINSTALL 未設定時不透傳"
echo "---------------------------------"
unset KDE_CODE_SERVER_AI_AGENTS_REINSTALL
out=$(start_code_server 8080 false cs-a3 "" "claude" "${KDE_PATH}/dir-a" 2>&1)
assert_not_contains "不含 REINSTALL" "${out}" "KDE_CODE_SERVER_AI_AGENTS_REINSTALL"
echo ""

echo "測試 19：REINSTALL 設定時透傳"
echo "-----------------------------"
export KDE_CODE_SERVER_AI_AGENTS_REINSTALL=true
out=$(start_code_server 8080 false cs-a4 "" "claude" "${KDE_PATH}/dir-a" 2>&1)
assert_contains "含 REINSTALL=true" "${out}" "KDE_CODE_SERVER_AI_AGENTS_REINSTALL=true"
unset KDE_CODE_SERVER_AI_AGENTS_REINSTALL
echo ""

echo "測試 20：daemon 模式也帶上環境變數"
echo "----------------------------------"
out=$(start_code_server 8080 true cs-a5 "" "codex" "${KDE_PATH}/dir-a" 2>&1)
assert_contains "daemon 分支含 KDE_CODE_SERVER_AI_AGENTS=codex" "${out}" "KDE_CODE_SERVER_AI_AGENTS=codex"
assert_contains "daemon 成功訊息列出 agent" "${out}" "AI Agents: codex"
echo ""

echo "測試 21：掛載仍正常（回歸）"
echo "---------------------------"
out=$(start_code_server 8080 false cs-a6 "" "" "${KDE_PATH}/dir-a" 2>&1)
assert_contains "掛載參數正確" "${out}" "-v ${KDE_PATH}/dir-a:${KDE_PATH}/dir-a"
echo ""

rm -rf "${KDE_PATH}"

echo "===== 測試完成 ====="
echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
