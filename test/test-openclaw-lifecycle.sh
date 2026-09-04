#!/bin/bash
set -eo pipefail

# 測試 kde openclaw 各 action 的前置檢查與組出的 docker 指令
# 以 shell 函式 stub 掉 docker，不會真的啟動容器

echo "===== kde openclaw 生命週期測試 ====="
echo ""

export KDE_PATH="/tmp/kde-test-openclaw-lc"
export KDE_CLI_PATH="/tmp/kde-test-openclaw-lc/cli"
export OPENCLAW_IMAGE="kde-openclaw:test"

rm -rf "${KDE_PATH}"
mkdir -p "${KDE_PATH}/cli"

source "$(dirname "${BASH_SOURCE[0]}")/../scripts/utils/openclaw.sh"

stat() { echo "999"; }

# 健康檢查的等待秒數在測試中歸零，避免每個 run 測試都空等
export OPENCLAW_HEALTH_WAIT=0

# 可調整的 stub 狀態
STUB_EXISTING=""      # docker ps -a 回傳的容器名
STUB_RUNNING=""       # docker ps 回傳的容器名
STUB_MODE=""          # openclaw config get gateway.mode 的輸出
STUB_AUTH_MODE="token"  # openclaw config get gateway.auth.mode 的輸出
STUB_MODE_AFTER=""    # onboard 跑完之後 config get 改為回傳這個值（空字串代表不變）
STUB_INSPECT="true"   # docker inspect -f '{{.State.Running}} {{.RestartCount}}' 的 Running 欄位
STUB_RESTARTS="0"     # 同上，RestartCount 欄位；非 0 代表曾經 crash-loop 重啟過
STUB_TOKEN=""         # 一次性容器讀 openclaw.json 時印出的 gateway token
# docker exec 跑 openclaw dashboard --no-open --json 的輸出。前面刻意墊一行雜訊，
# 因為實際的容器會先吐 [state-migrations] 之類的警告，取值必須挑出 JSON 那行。
STUB_DASHBOARD_JSON='{"ok":true,"url":"http://127.0.0.1:18789/#token=tok123","httpUrl":"http://127.0.0.1:18789/","wsUrl":"ws://127.0.0.1:18789","port":18789,"browserUrl":"http://127.0.0.1:18789/#bootstrapToken=boot456&bootstrapProfile=owner"}'
STUB_PORT_MAP="0.0.0.0:19000"  # docker port <name> 18789/tcp 的輸出
STUB_STOP_FAIL=""     # 當 "true" 時，docker stop 回傳 1
STUB_RM_FAIL=""       # 當 "true" 時，docker rm 回傳 1

# docker 呼叫記錄一定要寫進「檔案」而不是變數：
# is_openclaw_onboarded 是用 mode=$(docker run ...) 取值的，stub 對變數的
# 累加發生在該命令替換的子 shell 裡，回到父 shell 就消失了。
DOCKER_LOG_FILE="${KDE_PATH}/docker.log"
: > "${DOCKER_LOG_FILE}"

docker() {
    echo "docker $*" >> "${DOCKER_LOG_FILE}"
    case "$1" in
        ps)
            if [[ "$*" == *"-a"* ]]; then
                [[ -n "${STUB_EXISTING}" ]] && echo "${STUB_EXISTING}"
            else
                [[ -n "${STUB_RUNNING}" ]] && echo "${STUB_RUNNING}"
            fi
            return 0
            ;;
        run)
            # 狀態檢查容器：印出 gateway.mode
            if [[ "$*" == *"config get gateway.mode"* ]]; then
                echo "${STUB_MODE}"
            fi
            # 另一個狀態檢查容器：印出 gateway.auth.mode（決定能否綁非 loopback）
            if [[ "$*" == *"config get gateway.auth.mode"* ]]; then
                echo "${STUB_AUTH_MODE}"
            fi
            # 讀 token 的一次性容器：印出 openclaw.json 裡的 gateway.auth.token
            if [[ "$*" == *"node -e"* ]]; then
                echo "${STUB_TOKEN}"
            fi
            # onboard 容器跑完後切換 mode，模擬精靈寫入設定
            if [[ "$*" == *"onboard --mode local"* && -n "${STUB_MODE_AFTER}" ]]; then
                STUB_MODE="${STUB_MODE_AFTER}"
            fi
            return 0
            ;;
        exec)
            if [[ "$*" == *"dashboard --no-open --json"* ]]; then
                [[ -n "${STUB_DASHBOARD_JSON}" ]] && printf '[state-migrations] noise line\n%s\n' "${STUB_DASHBOARD_JSON}"
            fi
            return 0
            ;;
        port) echo "${STUB_PORT_MAP}"; return 0 ;;
        inspect) echo "${STUB_INSPECT} ${STUB_RESTARTS}"; return 0 ;;
        stop) [[ "${STUB_STOP_FAIL}" == "true" ]] && return 1; return 0 ;;
        rm) [[ "${STUB_RM_FAIL}" == "true" ]] && return 1; return 0 ;;
        *) return 0 ;;
    esac
}

TOTAL=0; PASS=0; FAIL=0
check() { # $1=描述 $2=條件結果(0/1)
    TOTAL=$((TOTAL+1))
    if [[ "$2" -eq 0 ]]; then echo "✅ $1"; PASS=$((PASS+1));
    else echo "❌ $1"; FAIL=$((FAIL+1)); fi
}

# 本檔開了 set -e，裸露的失敗指令（grep、[[ ]]）會直接中止腳本，
# 讓失敗變成「後面測試沒跑」而不是「回報失敗」。所有斷言一律走這兩個
# helper，它們把待測條件放進 if 裡，永遠回傳 0。
assert_true()  { local d="$1"; shift; if "$@" >/dev/null 2>&1; then check "$d" 0; else check "$d" 1; fi; }
assert_false() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then check "$d" 1; else check "$d" 0; fi; }

logged()  { grep -q -- "$1" "${DOCKER_LOG_FILE}"; }   # docker 呼叫記錄中有某段字串
out_has() { echo "${OUT}" | grep -q -- "$1"; }        # 上一次擷取的輸出中有某段字串
onboarded_is() { [[ "$(is_openclaw_onboarded)" == "$1" ]]; }

reset_stub() {
    STUB_EXISTING=""; STUB_RUNNING=""; STUB_MODE=""; STUB_MODE_AFTER=""
    STUB_INSPECT="true"; STUB_RESTARTS="0"; STUB_AUTH_MODE="token"; : > "${DOCKER_LOG_FILE}"; OUT=""
    OPENCLAW_FORCE=false; OPENCLAW_COMMAND=""
    OPENCLAW_FOLLOW=false; OPENCLAW_TAIL=100
    OPENCLAW_PORT=18789; STUB_TOKEN=""; OPENCLAW_JSON=false
    STUB_PORT_MAP="0.0.0.0:19000"
    STUB_DASHBOARD_JSON='{"ok":true,"url":"http://127.0.0.1:18789/#token=tok123","httpUrl":"http://127.0.0.1:18789/","wsUrl":"ws://127.0.0.1:18789","port":18789,"browserUrl":"http://127.0.0.1:18789/#bootstrapToken=boot456&bootstrapProfile=owner"}'
    STUB_STOP_FAIL=""; STUB_RM_FAIL=""
}

NAME="openclaw-kde-test-openclaw-lc"

echo "--- is_openclaw_onboarded ---"
reset_stub; STUB_MODE="local"
assert_true "gateway.mode 為 local 時回傳 true" onboarded_is true

reset_stub; STUB_MODE="remote"
assert_true "gateway.mode 非 local 時回傳 false" onboarded_is false

reset_stub; STUB_MODE=""
assert_true "gateway.mode 為空時回傳 false" onboarded_is false

reset_stub; STUB_MODE="  local  "
assert_true "輸出含空白時仍能判斷" onboarded_is true

reset_stub; STUB_MODE="local"
is_openclaw_onboarded >/dev/null
assert_true  "狀態檢查以一次性容器執行" logged "--rm"
assert_true  "狀態檢查查詢 gateway.mode" logged "config get gateway.mode"
assert_false "狀態檢查容器不具名" logged "--name"
echo ""

echo "--- run ---"
reset_stub; STUB_EXISTING="${NAME}"; STUB_MODE="local"
assert_false "同名容器已存在時 run 報錯" run_openclaw_gateway

reset_stub; STUB_MODE="remote"
assert_false "未初始化時 run 報錯" run_openclaw_gateway

reset_stub; STUB_MODE="remote"
OUT=$(run_openclaw_gateway 2>&1 || true)
assert_true  "未初始化的錯誤訊息指向 onboard" out_has "kde openclaw onboard"
assert_false "run 不自動代跑 onboarding" logged "onboard --mode local"

reset_stub; STUB_MODE="local"
run_openclaw_gateway >/dev/null 2>&1
assert_true "已初始化時以背景模式啟動" logged "-d --name ${NAME}"
assert_true "帶 restart policy" logged "--restart unless-stopped"
assert_true "發布預設 port" logged "-p 18789:18789"
assert_true "容器內 port 固定為 18789" logged "openclaw gateway run --port 18789"

reset_stub; STUB_MODE="local"; OPENCLAW_PORT=19000
run_openclaw_gateway >/dev/null 2>&1
assert_true "-p 只改主機側 port" logged "-p 19000:18789"
assert_true "-p 不影響容器內 port" logged "openclaw gateway run --port 18789"

reset_stub; STUB_MODE="local"; STUB_INSPECT="false"
assert_false "健康檢查失敗時 run 回報失敗" run_openclaw_gateway
assert_true  "健康檢查失敗時印出容器日誌" logged "logs --tail 50"

# gateway.bind：onboarding 精靈常把 gateway.bind 寫成 loopback，而明確的 config 值會
# 蓋過 OpenClaw 在容器內的 auto 預設，導致 -p 永遠轉不進去、dashboard 從主機連不到。
# 已實測 --bind auto 這個 CLI 旗標蓋得過 config，但 auth 關閉時 OpenClaw 會拒絕啟動。
reset_stub; STUB_MODE="local"; STUB_AUTH_MODE="token"
run_openclaw_gateway >/dev/null 2>&1
assert_true "auth 啟用時強制 --bind auto" logged "gateway run --port 18789 --bind auto"

reset_stub; STUB_MODE="local"; STUB_AUTH_MODE="none"
run_openclaw_gateway >/dev/null 2>&1
assert_false "auth=none 時不加 --bind（否則 gateway 拒絕啟動）" logged "--bind"

reset_stub; STUB_MODE="local"; STUB_AUTH_MODE="none"
OUT=$(run_openclaw_gateway 2>&1 || true)
assert_false "auth=none 時不謊報存取網址" out_has "存取網址"
assert_true  "auth=none 時說明 dashboard 連不到的原因" out_has "loopback"

reset_stub; STUB_MODE="local"; STUB_INSPECT="true"; STUB_RESTARTS="3"
assert_false "Running=true 但 RestartCount>0（crash-loop）時 run 仍回報失敗" run_openclaw_gateway
assert_true  "crash-loop 時同樣印出容器日誌" logged "logs --tail 50"
echo ""

echo "--- onboard ---"
reset_stub; STUB_EXISTING="${NAME}-onboard"
assert_false "同名 onboard 容器已存在時報錯" onboard_openclaw

reset_stub; STUB_MODE=""; STUB_MODE_AFTER="local"
onboard_openclaw >/dev/null 2>&1
assert_true  "onboard 以互動一次性容器執行" logged "-it --rm --name ${NAME}-onboard"
assert_true  "onboard 指令帶 --mode local" logged "openclaw onboard --mode local"
# 釘住第一個 agent 的名稱，精靈就不會問名字。填非 main 的名字會讓憑證寫進一個
# 沒被寫進 config roster 的 agent，gateway 跑的 main 讀不到，聊天時得到
# 「401 Missing bearer or basic authentication in header」（OpenClaw 2026.8.2 實測）。
assert_true  "onboard 釘住 --agent-name main" logged "onboard --mode local --agent-name main"
assert_false "onboard 容器不發布 port" logged "-p "

reset_stub; STUB_MODE=""; STUB_MODE_AFTER=""
assert_false "精靈結束後 mode 仍非 local 時報錯" onboard_openclaw

reset_stub; STUB_MODE="local"; STUB_MODE_AFTER="local"; OPENCLAW_FORCE=true
onboard_openclaw >/dev/null 2>&1
assert_true "已初始化時 -f 直接重跑不詢問" logged "onboard --mode local"
echo ""

echo "--- tui ---"
reset_stub; STUB_RUNNING=""
assert_false "容器未運行時 tui 報錯" tui_openclaw

reset_stub; STUB_RUNNING=""
OUT=$(tui_openclaw 2>&1 || true)
assert_true "tui 的錯誤訊息指向 run" out_has "kde openclaw run"

# 互動 openclaw 從 exec 的預設行為改成獨立的 tui action：exec 就純粹是 bash，
# 指令原封不動交給 bash -c，不必為了跑 openclaw 的子指令把 openclaw 這個字拿掉。
reset_stub; STUB_RUNNING="${NAME}"
tui_openclaw >/dev/null 2>&1
assert_true "tui 互動執行 openclaw，且以 node 身分（docker exec 繞過 entrypoint，需自帶 -u）" logged "exec -u node -it ${NAME} openclaw"
echo ""

echo "--- exec ---"
reset_stub; STUB_RUNNING=""
assert_false "容器未運行時 exec 報錯" exec_openclaw

reset_stub; STUB_RUNNING=""
OUT=$(exec_openclaw 2>&1 || true)
assert_true "exec 的錯誤訊息指向 run" out_has "kde openclaw run"

reset_stub; STUB_RUNNING="${NAME}"
exec_openclaw >/dev/null 2>&1
assert_true  "不帶指令時進入互動 bash，且以 node 身分" logged "exec -u node -it ${NAME} bash"
assert_false "不帶指令時不執行 openclaw" logged "-it ${NAME} openclaw"

reset_stub; STUB_RUNNING="${NAME}"; OPENCLAW_COMMAND="openclaw dashboard"
exec_openclaw >/dev/null 2>&1
assert_true  "有指令時交給 bash -c，且以 node 身分" logged "exec -u node ${NAME} bash -c openclaw dashboard"
assert_false "有指令時不配置 TTY" logged "exec -it"
echo ""

echo "--- log ---"
# 前置條件用「容器存在」而不是「容器在運行」：容器 crash 掉之後正是最需要看
# log 的時候，docker logs 對已退出的容器仍讀得到。
reset_stub; STUB_EXISTING=""
assert_false "容器不存在時 log 報錯" log_openclaw

reset_stub; STUB_EXISTING=""
OUT=$(log_openclaw 2>&1 || true)
assert_true "log 的錯誤訊息指向 run" out_has "kde openclaw run"

reset_stub; STUB_EXISTING="${NAME}"; STUB_RUNNING=""
log_openclaw >/dev/null 2>&1
assert_true  "容器存在但已退出時仍看得到 log" logged "logs --tail 100 ${NAME}"
assert_false "預設不跟隨" logged "logs -f"

reset_stub; STUB_EXISTING="${NAME}"; OPENCLAW_FOLLOW=true
log_openclaw >/dev/null 2>&1
assert_true "--follow 才加 -f" logged "logs -f --tail 100 ${NAME}"

reset_stub; STUB_EXISTING="${NAME}"; OPENCLAW_TAIL=500
log_openclaw >/dev/null 2>&1
assert_true "--tail 覆寫行數" logged "logs --tail 500 ${NAME}"
echo ""

echo "--- token ---"
# token 走一次性容器讀 openclaw.json，不要求 gateway 在運行：
# openclaw gateway auth-token --show 在 2026.8.2 拒絕印到非互動終端機，
# 而 openclaw config get gateway.auth.token 回傳的是 __OPENCLAW_REDACTED__。
reset_stub; STUB_RUNNING=""; STUB_TOKEN="tok123"
OUT=$(get_openclaw_token 2>/dev/null || true)
assert_true  "容器未運行時仍取得 token" test "${OUT}" = "tok123"
assert_true  "token 以一次性容器讀取" logged "--rm"
assert_false "讀 token 的容器不具名" logged "--name"

reset_stub; STUB_RUNNING="${NAME}"; STUB_TOKEN="tok123"
OUT=$(get_openclaw_token 2>/dev/null || true)
assert_true "stdout 只有 token 本身（可被管線接走）" test "${OUT}" = "tok123"

reset_stub; STUB_TOKEN=""; STUB_AUTH_MODE="token"
assert_false "讀不到 token 時回報失敗" get_openclaw_token

reset_stub; STUB_TOKEN=""; STUB_AUTH_MODE="none"
OUT=$(get_openclaw_token 2>&1 || true)
assert_true "auth.mode=none 時說明本來就沒有 token" out_has "none"
echo ""

echo "--- dashboard ---"
reset_stub; STUB_RUNNING=""
assert_false "容器未運行時 dashboard 報錯" dashboard_openclaw

reset_stub; STUB_RUNNING=""
OUT=$(dashboard_openclaw 2>&1 || true)
assert_true "dashboard 的錯誤訊息指向 run" out_has "kde openclaw run"

reset_stub; STUB_RUNNING="${NAME}"
dashboard_openclaw >/dev/null 2>&1
assert_true "以 docker exec 執行官方 dashboard 指令，且以 node 身分" logged "exec -u node ${NAME} openclaw dashboard --no-open --json"
assert_true "查詢容器實際發布的 port" logged "port ${NAME} 18789/tcp"

# openclaw dashboard 印的是容器自己的視角（恆為 127.0.0.1:18789），主機側的 port
# 由 -p 決定。以 docker port 取實際發布的 port 改寫，否則 -p 19000 的人直接貼會連錯。
reset_stub; STUB_RUNNING="${NAME}"
OUT=$(dashboard_openclaw 2>&1 || true)
assert_true  "預設印出 owner 配對連結" out_has "#bootstrapToken=boot456&bootstrapProfile=owner"
assert_true  "URL 的 port 改寫成主機實際發布的 port" out_has "localhost:19000"
assert_false "URL 不留下容器內的 port" out_has ":18789"
assert_false "URL 不留下容器視角的 127.0.0.1" out_has "127.0.0.1"
assert_true  "提醒連結是一次性且會過期" out_has "一次"

reset_stub; STUB_RUNNING="${NAME}"; OPENCLAW_JSON=true
OUT=$(dashboard_openclaw 2>&1 || true)
assert_true  "--json 印出 JSON 本體" out_has '"ok":true'
assert_true  "--json 的 port 同樣改寫" out_has "localhost:19000"
assert_false "--json 不夾帶容器吐的雜訊行" out_has "state-migrations"

reset_stub; STUB_RUNNING="${NAME}"; STUB_DASHBOARD_JSON=""
assert_false "取不到 JSON 時回報失敗" dashboard_openclaw

# docker port 拿不到時退回 OPENCLAW_PORT，不要印出容器內的 18789
reset_stub; STUB_RUNNING="${NAME}"; STUB_PORT_MAP=""; OPENCLAW_PORT=20000
OUT=$(dashboard_openclaw 2>&1 || true)
assert_true "docker port 無輸出時退回 OPENCLAW_PORT" out_has "localhost:20000"
echo ""

echo "--- stop ---"
reset_stub; STUB_EXISTING=""
assert_true "容器不存在時 stop 仍回傳 0（冪等）" stop_openclaw

reset_stub; STUB_EXISTING="${NAME}"
stop_openclaw >/dev/null 2>&1
assert_true "stop 會停止容器" logged "stop ${NAME}"
assert_true "stop 會移除容器" logged "rm ${NAME}"

reset_stub; STUB_EXISTING="${NAME}"; STUB_STOP_FAIL=true
assert_false "docker stop 失敗時 stop 回報失敗" stop_openclaw

reset_stub; STUB_EXISTING="${NAME}"; STUB_RM_FAIL=true
assert_false "docker rm 失敗時 stop 回報失敗" stop_openclaw
echo ""

echo "--- reset ---"
reset_stub; STUB_RUNNING="${NAME}"; mkdir -p "${KDE_PATH}/.openclaw-home"
assert_false "容器運行中時 reset 拒絕" reset_openclaw
assert_true  "拒絕時未刪除任何東西" test -d "${KDE_PATH}/.openclaw-home"

reset_stub; STUB_RUNNING=""; OPENCLAW_FORCE=false
mkdir -p "${KDE_PATH}/.openclaw-home/.openclaw"
reset_openclaw <<< "n" >/dev/null 2>&1
assert_true "未帶 -f 時輸入 n 會取消，不刪除 .openclaw-home" test -d "${KDE_PATH}/.openclaw-home"
rm -rf "${KDE_PATH}/.openclaw-home"

reset_stub; STUB_RUNNING=""; OPENCLAW_FORCE=true
mkdir -p "${KDE_PATH}/.openclaw-home/.openclaw"
reset_openclaw >/dev/null 2>&1
assert_false "-f 時直接刪除 .openclaw-home" test -d "${KDE_PATH}/.openclaw-home"

reset_stub; STUB_RUNNING=""; OPENCLAW_FORCE=true
reset_stub; STUB_RUNNING=""; OPENCLAW_FORCE=true
mkdir -p "${KDE_PATH}/.openclaw-home/.openclaw"
reset_openclaw >/dev/null 2>&1
assert_true "reset 一併移除 home volume 定義" logged "volume rm ${NAME}-home"

assert_true ".openclaw-home 不存在時 reset 回傳 0" reset_openclaw
echo ""

rm -rf "${KDE_PATH}"

echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
