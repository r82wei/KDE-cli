#!/bin/bash
set -eo pipefail

# 測試 start_k9s 傳給 k9s 容器的 USER 環境變數
#
# 背景：k9s 是停用 CGO 的 Go binary，其 InitLogLoc() 在 K9S_CONFIG_DIR 有值時
# 會呼叫 UserTmpDir() -> os/user.Current()（internal/config/helpers.go:42），
# 而該函式在沒有 CGO 時只剩兩條路：查 /etc/passwd，或讀 $USER。
# k9s 映像（alpine base）的 /etc/passwd 沒有 uid 1000 的條目，而 start_k9s 又以
# -u $(id -u):$(id -g) 執行容器，因此 $USER 是唯一還通的那條路。
#
# 問題在於呼叫端不保證有 USER：docker exec 只從 /etc/passwd 帶入 HOME，不會設
# USER/LOGNAME。於是在 kde openclaw exec 的容器內跑 kde k9s 會傳進一個空值，
# k9s 便以「user: Current requires cgo or $USER set in environment」開場，
# 接著因 AppLogFile 從未被賦值而噴 log file "" init failed。
# 主機上不會發生，只是因為主機 bash 剛好有 USER。

echo "===== kde k9s USER 環境變數測試 ====="
echo ""

export KDE_PATH="/tmp/kde-test-k9s"
export ENV_PATH="${KDE_PATH}/environments/test-env"
export K9S_IMAGE="k9s:test"
export KUBECONFIG="${ENV_PATH}/kubeconfig/config"
export DOCKER_NETWORK="kind"

rm -rf "${KDE_PATH}"
mkdir -p "${ENV_PATH}/kubeconfig"
touch "${KUBECONFIG}"

source "$(dirname "${BASH_SOURCE[0]}")/../scripts/utils/k9s.sh"

# stub docker：只把 docker run 的參數印出來供斷言
docker() { echo "docker $*"; }

# stub command：讓 `command -v k9s` 失敗，強制走 docker run 分支。
# 主機上剛好裝了 k9s 的人不該因此得到不同的測試結果。
command() {
    if [[ "$1" == "-v" && "$2" == "k9s" ]]; then
        return 1
    fi
    builtin command "$@"
}

# stub id：固定 uid/gid/名稱，讓斷言可預測。
# ID_NAME_FAILS=true 時模擬「uid 不在 /etc/passwd」——即 id -un 查不到名字。
ID_NAME_FAILS=false
id() {
    case "$1" in
        -u)  echo 1000 ;;
        -g)  echo 1000 ;;
        -un)
            if [[ "${ID_NAME_FAILS}" == "true" ]]; then
                echo "id: cannot find name for user ID 1000" >&2
                return 1
            fi
            echo testuser
            ;;
    esac
}

TOTAL=0; PASS=0; FAIL=0
check() { # $1=描述 $2=條件結果(0/1)
    TOTAL=$((TOTAL+1))
    if [[ "$2" -eq 0 ]]; then echo "✅ $1"; PASS=$((PASS+1));
    else echo "❌ $1"; FAIL=$((FAIL+1)); fi
}

# 本檔開了 set -e，裸露的失敗 grep 會直接中止腳本，讓失敗變成「後面沒跑」
# 而不是「回報失敗」。所有斷言一律走這兩個 helper。
OUT=""
has() { echo "${OUT}" | grep -q -- "$1"; }
assert_has()   { if has "$2"; then check "$1" 0; else check "$1" 1; fi; }
assert_lacks() { if has "$2"; then check "$1" 1; else check "$1" 0; fi; }

# start_k9s 會 export K9S_CONFIG_DIR，不清掉會殘留到下一個案例
run_k9s() { unset K9S_CONFIG_DIR; OUT=$(start_k9s "" "" 2>&1); }

# ---------------------------------------------------------------------------
# 有自訂設定檔目錄時才會加上 -u 與 -e USER，先把它備好
mkdir -p "${KDE_PATH}/k9s"

# 案例 1：呼叫端有 USER（主機情境）——原樣沿用，不被 id -un 蓋掉
export USER=maxime
run_k9s
assert_has "呼叫端有 USER 時原樣沿用" "-e USER=maxime"

# 案例 2：呼叫端的 USER 是空字串（kde openclaw exec 情境）
# docker exec 不設 USER，故此處為空。不可傳空值進 k9s 容器。
export USER=""
run_k9s
assert_has   "USER 為空時退回 id -un" "-e USER=testuser"
assert_lacks "USER 為空時不傳空值" "-e USER= "

# 案例 3：呼叫端完全沒有 USER 這個變數
unset USER
run_k9s
assert_has "USER 未定義時退回 id -un" "-e USER=testuser"

# 案例 4：連 id -un 都查不到名字（uid 不在 /etc/passwd）時退回 uid 數字。
# 名字查不到的 stderr 不該混進 docker 參數，也不該讓 USER 變成空值。
ID_NAME_FAILS=true
unset USER
run_k9s
assert_has "id -un 失敗時退回 uid 數字" "-e USER=1000"
ID_NAME_FAILS=false

# 案例 5：沒有自訂設定檔目錄時，本來就不加 -u，容器以 root 執行、
# root 在 /etc/passwd 裡查得到，因此也不該多出 -e USER。
# 這條守住修法的範圍，避免順手擴大到不需要的分支。
rm -rf "${KDE_PATH}/k9s"
export USER=maxime
run_k9s
assert_lacks "無自訂設定檔目錄時不加 -u" "-u 1000:1000"
assert_lacks "無自訂設定檔目錄時不加 -e USER" "-e USER="

# ---------------------------------------------------------------------------
echo ""
echo "===== 測試結果 ====="
echo "總計: ${TOTAL}, 通過: ${PASS}, 失敗: ${FAIL}"

rm -rf "${KDE_PATH}"

if [[ ${FAIL} -gt 0 ]]; then
    exit 1
fi
echo "✓ 全部通過"
