#!/bin/bash

# 測試 kde openclaw 的參數解析（parse_openclaw_args）與容器命名
# 比照 test/test-code-server-agent-args.sh 的模式

echo "===== kde openclaw 參數解析測試 ====="
echo ""

source "$(dirname "${BASH_SOURCE[0]}")/../scripts/utils/openclaw.sh"

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

echo "測試 1：十個 action 都能解析"
echo "--------------------"
for a in run onboard stop restart tui exec log token dashboard reset; do
    rc=0; parse_openclaw_args "${a}" >/dev/null 2>&1 || rc=$?
    assert_rc "action ${a} 退出碼為 0" 0 "${rc}"
    assert_eq "action ${a} 正確回填" "${a}" "${OPENCLAW_ACTION}"
done
echo ""

echo "測試 2：預設值"
echo "--------------------"
unset OPENCLAW_PORT
rc=0; parse_openclaw_args run || rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "PORT 預設為 18789" "18789" "${OPENCLAW_PORT}"
assert_eq "PORT_GIVEN 預設為 false" "false" "${OPENCLAW_PORT_GIVEN}"
assert_eq "FORCE 預設為 false" "false" "${OPENCLAW_FORCE}"
assert_eq "COMMAND 預設為空" "" "${OPENCLAW_COMMAND}"
assert_eq "FOLLOW 預設為 false" "false" "${OPENCLAW_FOLLOW}"
assert_eq "TAIL 預設為 100" "100" "${OPENCLAW_TAIL}"
assert_eq "JSON 預設為 false" "false" "${OPENCLAW_JSON}"
echo ""

echo "測試 3：-p 覆寫 port"
echo "--------------------"
unset OPENCLAW_PORT
rc=0; parse_openclaw_args run -p 19000 || rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "PORT 為 19000" "19000" "${OPENCLAW_PORT}"

unset OPENCLAW_PORT
rc=0; parse_openclaw_args run --port 19001 || rc=$?
assert_eq "--port 長旗標同樣有效" "19001" "${OPENCLAW_PORT}"
echo ""

echo "測試 4：環境變數 OPENCLAW_PORT 生效，且 -p 優先"
echo "--------------------"
export OPENCLAW_PORT=20000
rc=0; parse_openclaw_args run || rc=$?
assert_eq "環境變數被採用" "20000" "${OPENCLAW_PORT}"

export OPENCLAW_PORT=20000
rc=0; parse_openclaw_args run -p 21000 || rc=$?
assert_eq "-p 優先於環境變數" "21000" "${OPENCLAW_PORT}"
unset OPENCLAW_PORT
echo ""

echo "測試 5：-p 非數字報錯"
echo "--------------------"
rc=0; parse_openclaw_args run -p abc >/dev/null 2>&1 || rc=$?
assert_rc "非數字 port 退出碼為 1" 1 "${rc}"

rc=0; parse_openclaw_args run -p >/dev/null 2>&1 || rc=$?
assert_rc "缺少 port 值退出碼為 1" 1 "${rc}"
echo ""

echo "測試 6：-f 依 action 分流（force / follow）"
echo "--------------------"
# -f 對 onboard/reset 是「略過確認」、對 log 是「跟隨」。兩者不可能同時適用於
# 同一個 action，所以共用 -f 不歧義；長旗標 --force / --follow 仍各自明確。
rc=0; parse_openclaw_args reset -f || rc=$?
assert_eq "reset -f 設定 FORCE" "true" "${OPENCLAW_FORCE}"
assert_eq "reset -f 不設定 FOLLOW" "false" "${OPENCLAW_FOLLOW}"

rc=0; parse_openclaw_args onboard -f || rc=$?
assert_eq "onboard -f 設定 FORCE" "true" "${OPENCLAW_FORCE}"

rc=0; parse_openclaw_args reset --force || rc=$?
assert_eq "--force 設定 FORCE" "true" "${OPENCLAW_FORCE}"

rc=0; parse_openclaw_args log -f || rc=$?
assert_eq "log -f 設定 FOLLOW" "true" "${OPENCLAW_FOLLOW}"
assert_eq "log -f 不設定 FORCE" "false" "${OPENCLAW_FORCE}"

rc=0; parse_openclaw_args log --follow || rc=$?
assert_eq "--follow 設定 FOLLOW" "true" "${OPENCLAW_FOLLOW}"
echo ""

echo "測試 7：--tail"
echo "--------------------"
rc=0; parse_openclaw_args log --tail 500 || rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "TAIL 為 500" "500" "${OPENCLAW_TAIL}"

rc=0; parse_openclaw_args log --tail abc >/dev/null 2>&1 || rc=$?
assert_rc "非數字 tail 退出碼為 1" 1 "${rc}"

rc=0; parse_openclaw_args log --tail >/dev/null 2>&1 || rc=$?
assert_rc "缺少 tail 值退出碼為 1" 1 "${rc}"
echo ""

echo "測試 7a：--json"
echo "--------------------"
rc=0; parse_openclaw_args dashboard --json || rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "--json 設定 JSON" "true" "${OPENCLAW_JSON}"
echo ""

echo "測試 7b：exec 的指令（--command 與位置參數）"
echo "--------------------"
rc=0; parse_openclaw_args exec --command "echo hi" || rc=$?
assert_eq "--command 正確回填" "echo hi" "${OPENCLAW_COMMAND}"

# exec 就是 bash，指令原封不動交給 bash -c，不會幫你補 openclaw ——
# 所以位置參數寫法跟容器裡實際跑的指令一模一樣
rc=0; parse_openclaw_args exec "openclaw dashboard" || rc=$?
assert_rc "位置參數退出碼為 0" 0 "${rc}"
assert_eq "位置參數當成指令" "openclaw dashboard" "${OPENCLAW_COMMAND}"

rc=0; parse_openclaw_args exec --command "a" "b" >/dev/null 2>&1 || rc=$?
assert_rc "指令給兩次退出碼為 1" 1 "${rc}"

rc=0; parse_openclaw_args exec ls -la >/dev/null 2>&1 || rc=$?
assert_rc "多字指令未加引號時報錯而非靜默截斷" 1 "${rc}"

# 位置參數只在 exec 有意義：其他 action 的錯字不該被靜默吃掉
rc=0; parse_openclaw_args run bogus >/dev/null 2>&1 || rc=$?
assert_rc "run 的位置參數退出碼為 1" 1 "${rc}"

# -s/--shell 已移除：exec 不帶指令就是互動 bash，互動 openclaw 改用 tui
rc=0; parse_openclaw_args exec -s >/dev/null 2>&1 || rc=$?
assert_rc "-s 已移除，退出碼為 1" 1 "${rc}"
echo ""

echo "測試 8：說明與未知輸入"
echo "--------------------"
rc=0; parse_openclaw_args -h >/dev/null 2>&1 || rc=$?
assert_rc "-h 退出碼為 2" 2 "${rc}"

rc=0; parse_openclaw_args >/dev/null 2>&1 || rc=$?
assert_rc "無參數退出碼為 2" 2 "${rc}"

rc=0; parse_openclaw_args bogus >/dev/null 2>&1 || rc=$?
assert_rc "未知 action 退出碼為 1" 1 "${rc}"

rc=0; parse_openclaw_args run --bogus >/dev/null 2>&1 || rc=$?
assert_rc "未知旗標退出碼為 1" 1 "${rc}"
echo ""

echo "測試 9：容器名稱由 KDE_PATH 推導並清洗"
echo "--------------------"
KDE_PATH="/tmp/my-workspace" assert_eq "一般名稱" "openclaw-my-workspace" "$(KDE_PATH=/tmp/my-workspace get_openclaw_container_name)"
assert_eq "含空白的目錄名被清洗" "openclaw-my-ws" "$(KDE_PATH='/tmp/my ws' get_openclaw_container_name)"
assert_eq "含特殊字元的目錄名被清洗" "openclaw-a-b-c" "$(KDE_PATH='/tmp/a@b#c' get_openclaw_container_name)"
assert_eq "底線與點保留" "openclaw-a_b.c" "$(KDE_PATH='/tmp/a_b.c' get_openclaw_container_name)"
echo ""

echo "測試 10：OPENCLAW_PORT_GIVEN 記錄「使用者是否明確表態 port」"
echo "--------------------"
# 這個旗標存在的唯一理由是 restart：它要在使用者沒表態時沿用現有容器的 port。
# 套上內建預設之後，OPENCLAW_PORT=18789 有三個可能來源（-p 18789、環境變數
# 18789、什麼都沒給），單看值分不出來，所以必須在套預設「之前」記下來。
unset OPENCLAW_PORT
rc=0; parse_openclaw_args restart || rc=$?
assert_eq "什麼都沒給時為 false" "false" "${OPENCLAW_PORT_GIVEN}"

unset OPENCLAW_PORT
rc=0; parse_openclaw_args restart -p 19000 || rc=$?
assert_eq "-p 時為 true" "true" "${OPENCLAW_PORT_GIVEN}"

unset OPENCLAW_PORT
rc=0; parse_openclaw_args restart --port 19000 || rc=$?
assert_eq "--port 時為 true" "true" "${OPENCLAW_PORT_GIVEN}"

export OPENCLAW_PORT=20000
rc=0; parse_openclaw_args restart || rc=$?
assert_eq "環境變數有值時為 true" "true" "${OPENCLAW_PORT_GIVEN}"
unset OPENCLAW_PORT

# 關鍵案例：明確指定的值恰好等於內建預設。用「值是否等於 18789」去猜來源
# 的做法會在這裡猜錯，把明確的旗標當成沒給，restart 便會靜默沿用舊 port。
unset OPENCLAW_PORT
rc=0; parse_openclaw_args restart -p 18789 || rc=$?
assert_eq "-p 18789（等於預設）仍為 true" "true" "${OPENCLAW_PORT_GIVEN}"
assert_eq "-p 18789 的值正確回填" "18789" "${OPENCLAW_PORT}"

export OPENCLAW_PORT=18789
rc=0; parse_openclaw_args restart || rc=$?
assert_eq "環境變數為 18789（等於預設）仍為 true" "true" "${OPENCLAW_PORT_GIVEN}"
unset OPENCLAW_PORT
echo ""

echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
