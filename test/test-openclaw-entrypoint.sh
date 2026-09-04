#!/bin/bash

# 測試 dockerfiles/kde-openclaw/entrypoint.sh 的 PUID/PGID 行為
# 以假的 PATH 攔截 groupmod/usermod/chown/setpriv，不會真的改動任何使用者

echo "===== kde-openclaw entrypoint 測試 ====="
echo ""

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/dockerfiles/kde-openclaw/entrypoint.sh"
TMP_ROOT="/tmp/kde-test-openclaw-entrypoint"

TOTAL=0; PASS=0; FAIL=0
check() { # $1=描述 $2=條件結果(0/1)
    TOTAL=$((TOTAL+1))
    if [[ "$2" -eq 0 ]]; then echo "✅ $1"; PASS=$((PASS+1));
    else echo "❌ $1"; FAIL=$((FAIL+1)); fi
}

# 建立假的 PATH：groupmod / usermod / chown / setpriv 只記錄呼叫參數
# setpriv 額外記錄當下的 $HOME，用來驗證 entrypoint 有沒有在降權前改寫 HOME
#
# stat：回傳 STUB_SOCK_GID（測試各自設定，預設空字串＝docker.sock 不存在）
# getent：永遠找不到該 group（回傳 1），逼 entrypoint 一定要走 groupadd 分支，
#         這樣才能同時驗證「查過」與「查不到就建立」兩件事
# groupadd：只記錄呼叫參數，不真的建立群組
setup() {
    rm -rf "${TMP_ROOT}"
    mkdir -p "${TMP_ROOT}/bin" "${TMP_ROOT}/home"
    local b
    for b in groupmod usermod chown groupadd; do
        cat > "${TMP_ROOT}/bin/${b}" <<EOS
#!/bin/bash
echo "${b} \$*" >> "${TMP_ROOT}/calls.log"
EOS
        chmod +x "${TMP_ROOT}/bin/${b}"
    done
    cat > "${TMP_ROOT}/bin/setpriv" <<EOS
#!/bin/bash
echo "HOME=\${HOME} setpriv \$*" >> "${TMP_ROOT}/calls.log"
EOS
    chmod +x "${TMP_ROOT}/bin/setpriv"
    cat > "${TMP_ROOT}/bin/stat" <<EOS
#!/bin/bash
echo "stat \$*" >> "${TMP_ROOT}/calls.log"
echo "${STUB_SOCK_GID:-}"
EOS
    chmod +x "${TMP_ROOT}/bin/stat"
    cat > "${TMP_ROOT}/bin/getent" <<EOS
#!/bin/bash
echo "getent \$*" >> "${TMP_ROOT}/calls.log"
exit 1
EOS
    chmod +x "${TMP_ROOT}/bin/getent"
}

run_entrypoint() { # $@ = 環境變數指定方式由呼叫端 export
    PATH="${TMP_ROOT}/bin:${PATH}" OPENCLAW_HOME_DIR="${TMP_ROOT}/home" \
        bash "${SCRIPT}" openclaw gateway run >/dev/null 2>&1
}

echo "測試 1：PUID/PGID 皆為 1000 時不重映射"
setup
PUID=1000 PGID=1000 run_entrypoint
grep -q "usermod" "${TMP_ROOT}/calls.log" && r=1 || r=0
check "未呼叫 usermod" $r
grep -q "groupmod" "${TMP_ROOT}/calls.log" && r=1 || r=0
check "未呼叫 groupmod" $r
echo ""

echo "測試 2：未設 PUID/PGID 時視為 1000"
setup
run_entrypoint
grep -q "usermod" "${TMP_ROOT}/calls.log" && r=1 || r=0
check "未呼叫 usermod" $r
echo ""

echo "測試 3：PUID 非 1000 時重映射"
setup
PUID=1234 PGID=1000 run_entrypoint
grep -q "usermod -u 1234 node" "${TMP_ROOT}/calls.log"
check "以正確參數呼叫 usermod" $?
grep -q "groupmod" "${TMP_ROOT}/calls.log" && r=1 || r=0
check "PGID 仍為 1000 時不呼叫 groupmod" $r
echo ""

echo "測試 4：PGID 非 1000 時重映射"
setup
PUID=1000 PGID=5678 run_entrypoint
grep -q "groupmod -g 5678 node" "${TMP_ROOT}/calls.log"
check "以正確參數呼叫 groupmod" $?
echo ""

echo "測試 5：chown 只碰 home 與 .openclaw 狀態目錄，不遞迴 workspace"
setup
PUID=1234 PGID=5678 run_entrypoint
grep -q "chown 1234:5678 ${TMP_ROOT}/home ${TMP_ROOT}/home/.openclaw" "${TMP_ROOT}/calls.log"
check "chown 目標為 home 與 .openclaw" $?
grep -qE "chown.* -R" "${TMP_ROOT}/calls.log" && r=1 || r=0
check "未使用遞迴 chown" $r
echo ""

echo "測試 6：以 setpriv 降權並把原指令接下去"
setup
PUID=1234 PGID=5678 run_entrypoint
grep -q "setpriv --reuid 1234 --regid 5678 --init-groups --inh-caps=-all openclaw gateway run" "${TMP_ROOT}/calls.log"
check "setpriv 參數與轉交的指令皆正確" $?
echo ""

echo "測試 7：狀態目錄會被建立，且不再建立 .config/openclaw（實測確認 auth 密鑰其實落在 .openclaw 底下）"
setup
PUID=1000 PGID=1000 run_entrypoint
[[ -d "${TMP_ROOT}/home/.openclaw" ]]
check "建立 .openclaw" $?
[[ ! -d "${TMP_ROOT}/home/.config/openclaw" ]]
check "不再建立 .config/openclaw" $?
echo ""

echo "測試 8：setpriv 執行前 HOME 已改寫為目標 home（setpriv 本身不會更新 HOME）"
setup
PUID=1234 PGID=5678 run_entrypoint
grep -q "HOME=${TMP_ROOT}/home setpriv" "${TMP_ROOT}/calls.log"
check "setpriv 執行時 HOME 已指向目標 home" $?
echo ""

echo "測試 9：docker.sock 存在時，把其 gid materialize 成群組並掛到 node（setpriv --init-groups 修正）"
STUB_SOCK_GID=999
setup
PUID=1000 PGID=1000 run_entrypoint
grep -q "getent group 999" "${TMP_ROOT}/calls.log"
check "查詢過 gid 999 是否已有群組" $?
grep -q "groupadd -g 999 hostdocker" "${TMP_ROOT}/calls.log"
check "查無群組時以 groupadd 建立" $?
grep -q "usermod -aG 999 node" "${TMP_ROOT}/calls.log"
check "以 usermod -aG 把 node 加進該群組" $?
echo ""

echo "測試 10：docker.sock 不存在（stat 回傳空字串）時不呼叫 groupadd/usermod -aG"
STUB_SOCK_GID=""
setup
PUID=1000 PGID=1000 run_entrypoint
grep -q "groupadd" "${TMP_ROOT}/calls.log" && r=1 || r=0
check "未呼叫 groupadd" $r
grep -q "usermod -aG" "${TMP_ROOT}/calls.log" && r=1 || r=0
check "未呼叫 usermod -aG" $r
echo ""

rm -rf "${TMP_ROOT}"

echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
