#!/bin/bash

# 測試 /entrypoint.d/10-ai-agents.sh 的行為
# 以假的 AGENT_DIR 與假的 HOME 執行，不會真的安裝任何東西

echo "===== code-server AI agent entrypoint 測試 ====="
echo ""

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/dockerfiles/code-server/entrypoint.d/10-ai-agents.sh"
TMP_ROOT="/tmp/kde-test-agent-entrypoint"

TOTAL=0; PASS=0; FAIL=0
check() { # $1=描述 $2=條件結果(0/1)
    TOTAL=$((TOTAL+1))
    if [[ "$2" -eq 0 ]]; then echo "✅ $1"; PASS=$((PASS+1));
    else echo "❌ $1"; FAIL=$((FAIL+1)); fi
}

# 建立乾淨的假 HOME 與假 AGENT_DIR
setup() {
    rm -rf "${TMP_ROOT}"
    mkdir -p "${TMP_ROOT}/home" "${TMP_ROOT}/agents"

    # 假的「安裝成功」腳本：在 AGENT_BIN_DIR 造出同名可執行檔，
    # 並在 $HOME/run-log 記一次，供「是否真的執行過」的斷言使用
    cat > "${TMP_ROOT}/agents/install-goodagent.sh" <<'EOS'
#!/bin/bash
set -eo pipefail
echo "goodagent:${AGENT_REINSTALL:-}:${AGENT_NAME:-}" >> "${HOME}/run-log"
printf '#!/bin/bash\necho goodagent\n' > "${AGENT_BIN_DIR}/goodagent"
chmod +x "${AGENT_BIN_DIR}/goodagent"
EOS

    # 假的「安裝失敗」腳本
    cat > "${TMP_ROOT}/agents/install-badagent.sh" <<'EOS'
#!/bin/bash
set -eo pipefail
echo "badagent" >> "${HOME}/run-log"
echo "模擬下載失敗" >&2
exit 1
EOS

    chmod +x "${TMP_ROOT}/agents"/*.sh
}

# 以受控環境執行 entrypoint 腳本
# $1=KDE_CODE_SERVER_AI_AGENTS  $2=KDE_CODE_SERVER_AI_AGENTS_REINSTALL(可省略)
run_entrypoint() {
    env -i \
        PATH="/usr/local/bin:/usr/bin:/bin" \
        HOME="${TMP_ROOT}/home" \
        KDE_CODE_SERVER_AGENT_DIR="${TMP_ROOT}/agents" \
        KDE_CODE_SERVER_AI_AGENTS="$1" \
        KDE_CODE_SERVER_AI_AGENTS_REINSTALL="${2:-}" \
        bash "${SCRIPT}" 2>&1
}

# 測試 1：未指定 agent 時完全靜默且 exit 0
setup
out=$(run_entrypoint ""); rc=$?
[[ ${rc} -eq 0 && -z "${out}" ]]
check "未指定 agent 時無輸出且 exit 0" $?

# 測試 2：正常安裝，binary 落在 \$HOME/.local/bin
setup
out=$(run_entrypoint "goodagent"); rc=$?
[[ ${rc} -eq 0 ]] && [[ -x "${TMP_ROOT}/home/.local/bin/goodagent" ]]
check "安裝成功且 binary 位於 \$HOME/.local/bin" $?

# 測試 3：不認識的名稱只警告，仍 exit 0，且列出可用清單
setup
out=$(run_entrypoint "nosuchagent"); rc=$?
[[ ${rc} -eq 0 ]] \
  && echo "${out}" | grep -q "不認識" \
  && echo "${out}" | grep -q "goodagent"
check "不認識的 agent 只警告、列出可用清單、exit 0" $?

# 測試 4：安裝失敗只警告，仍 exit 0
# 注意：不可只比對「失敗」二字 —— 假腳本 install-badagent.sh 自己也會往 stderr
# 印出「模擬下載失敗」，而測試以 2>&1 一併擷取，就算刪掉 entrypoint 本身的 ❌
# 訊息，這個斷言仍會通過。改比對只有 entrypoint 才會印出的 ❌ 標記。
setup
out=$(run_entrypoint "badagent"); rc=$?
[[ ${rc} -eq 0 ]] && echo "${out}" | grep -q "❌"
check "安裝失敗只警告且 exit 0" $?

# 測試 5：前面的 agent 失敗不影響後面的 agent
setup
out=$(run_entrypoint "badagent,goodagent"); rc=$?
[[ ${rc} -eq 0 ]] && [[ -x "${TMP_ROOT}/home/.local/bin/goodagent" ]]
check "單一 agent 失敗不中斷後續安裝" $?

# 測試 6：第二次執行時跳過（安裝腳本不再被呼叫）
setup
run_entrypoint "goodagent" >/dev/null
out=$(run_entrypoint "goodagent"); rc=$?
cnt=$(grep -c '^goodagent:' "${TMP_ROOT}/home/run-log")
[[ ${rc} -eq 0 ]] && [[ "${cnt}" -eq 1 ]] && echo "${out}" | grep -q "跳過"
check "已安裝時跳過，安裝腳本只被執行一次" $?

# 測試 7：REINSTALL=true 時即使已安裝也重跑安裝腳本
setup
run_entrypoint "goodagent" >/dev/null
run_entrypoint "goodagent" "true" >/dev/null
cnt=$(grep -c '^goodagent:' "${TMP_ROOT}/home/run-log")
[[ "${cnt}" -eq 2 ]]
check "REINSTALL=true 時強制重裝" $?

# 測試 8：AGENT_REINSTALL 契約變數有正確轉譯給安裝腳本
setup
run_entrypoint "goodagent" "true" >/dev/null
grep -q '^goodagent:true:goodagent$' "${TMP_ROOT}/home/run-log"
check "KDE_CODE_SERVER_AI_AGENTS_REINSTALL 轉譯為 AGENT_REINSTALL" $?

# 測試 8b：AGENT_NAME 契約變數有正確傳給安裝腳本
# entrypoint 依檔名慣例把要安裝的 agent 名稱以 AGENT_NAME 傳給 install-<name>.sh；
# 若刪掉這個傳遞，其餘 10 個 entrypoint 測試都不會變紅，因此需要獨立斷言。
setup
run_entrypoint "goodagent" >/dev/null
grep -q '^goodagent::goodagent$' "${TMP_ROOT}/home/run-log"
check "AGENT_NAME 契約變數正確傳給安裝腳本" $?

# 測試 9：逗號分隔的空白與空欄位要被忽略
setup
out=$(run_entrypoint " goodagent , ,"); rc=$?
[[ ${rc} -eq 0 ]] && [[ -x "${TMP_ROOT}/home/.local/bin/goodagent" ]] \
  && ! echo "${out}" | grep -q "不認識"
check "去除空白並忽略空欄位" $?

# 測試 10：.bashrc / .profile 的 PATH 區塊冪等（跑兩次只出現一次）
setup
run_entrypoint "goodagent" >/dev/null
run_entrypoint "goodagent" >/dev/null
# 注意：要比對開頭的 guard 標記，不能只比對 'kde-cli agents PATH'
# —— 區塊的開頭與結尾兩行都含那段字，會數成 2
bashrc_cnt=$(grep -c '>>> kde-cli agents PATH >>>' "${TMP_ROOT}/home/.bashrc")
profile_cnt=$(grep -c '>>> kde-cli agents PATH >>>' "${TMP_ROOT}/home/.profile")
[[ "${bashrc_cnt}" -eq 1 && "${profile_cnt}" -eq 1 ]]
check ".bashrc/.profile 的 PATH 區塊冪等" $?

rm -rf "${TMP_ROOT}"

echo ""
echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
