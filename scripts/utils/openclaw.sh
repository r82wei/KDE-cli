#!/bin/bash

# kde openclaw 子命令的實作邏輯。
#
# 注意：本檔會被 scripts/openclaw/command.sh source，而該檔又被 kde.sh source，
# kde.sh 開了 set -eo pipefail，因此所有可能回傳非零的呼叫都必須用 `|| rc=$?`
# 或包在 if 條件中承接，不可裸呼叫。

# gateway 對外發布 port 的內建預設值。
# 刻意不寫進 kde.env：kde.env 是版控檔案，會隨 workspace 同步到每個人的機器上，
# 而 port 是每台開發機各自的環境條件，同步只會互相干擾。
OPENCLAW_PORT_DEFAULT=18789

# log 預設顯示的行數。與 run 健康檢查用的 50 行刻意分開：
# 那是失敗時的自動摘要，這是使用者主動查閱，看得多一點比較有用。
OPENCLAW_TAIL_DEFAULT=100

# 容器內 OpenClaw 使用者的 home。官方映像的使用者是 node（uid 1000），
# 只有 uid/gid 會隨 PUID/PGID 變動，路徑本身固定。
OPENCLAW_CONTAINER_HOME=/home/node

# 顯示 kde openclaw 的使用說明
show_openclaw_help() {
    echo "usage: kde openclaw <action> [option]"
    echo ""
    echo "action:"
    echo "  run     [-p port]               背景常駐啟動 OpenClaw gateway"
    echo "  onboard [-f]                    執行初始化精靈 (一次性互動容器，不需 gateway 已啟動)"
    echo "  stop                            停止並移除 gateway 容器"
    echo "  tui                             互動進入 openclaw TUI"
    echo "  exec    [<cmd>]                 進入容器的 bash；帶指令則非互動執行 (指令含空白請用引號包起來)"
    echo "  log     [-f] [--tail <n>]       查看 gateway 容器日誌 (預設最後 ${OPENCLAW_TAIL_DEFAULT} 行，不跟隨)"
    echo "  token                           印出 gateway 的 auth token (僅 token 本身，可被管線接走)"
    echo "  reset   [-f]                    刪除 workspace 的 .openclaw (容器運行中則拒絕)"
    echo ""
    echo "option:"
    echo "  -p, --port      gateway 對外發布的 port (預設 ${OPENCLAW_PORT_DEFAULT}，亦可用環境變數 OPENCLAW_PORT)"
    echo "  -f, --force     略過確認提示 (onboard、reset)"
    echo "  -f, --follow    跟隨日誌輸出 (log)"
    echo "      --tail <n>  log 顯示的行數 (預設 ${OPENCLAW_TAIL_DEFAULT})"
    echo "      --command   exec 時執行指定指令 (不配置 TTY，等同直接寫成位置參數)"
    echo "  -h, --help      顯示此幫助訊息"
}

# 解析 kde openclaw 的參數，結果回填到 OPENCLAW_* 全域變數
# 回傳 0=成功、1=參數錯誤、2=已顯示說明應結束
parse_openclaw_args() {
    OPENCLAW_ACTION=""
    # 環境變數有值就沿用，否則套用內建預設；-p 會在下面覆寫
    OPENCLAW_PORT="${OPENCLAW_PORT:-${OPENCLAW_PORT_DEFAULT}}"
    OPENCLAW_FORCE=false
    OPENCLAW_COMMAND=""
    OPENCLAW_FOLLOW=false
    OPENCLAW_TAIL="${OPENCLAW_TAIL_DEFAULT}"

    if [[ $# -eq 0 ]]; then
        show_openclaw_help
        return 2
    fi

    case "$1" in
        -h|--help)
            show_openclaw_help
            return 2
            ;;
        run|onboard|stop|tui|exec|log|token|reset)
            OPENCLAW_ACTION="$1"
            shift
            ;;
        *)
            echo "未知的 action：$1" >&2
            show_openclaw_help >&2
            return 1
            ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --port|-p)
                OPENCLAW_PORT="$2"
                if [[ -z "${OPENCLAW_PORT}" || ! ${OPENCLAW_PORT} =~ ^[0-9]+$ ]]; then
                    echo "無效的 port：$2" >&2
                    return 1
                fi
                shift 2
                ;;
            # -f 依 action 分流：對 onboard/reset 是「略過確認」，對 log 是「跟隨」。
            # 這兩件事不可能同時適用於同一個 action（log 沒有確認提示可略過，
            # onboard/reset 也沒有日誌可跟隨），所以共用 -f 不會產生歧義；
            # 要明確表達時仍有 --force / --follow 兩個長旗標。
            --force)
                OPENCLAW_FORCE=true
                shift
                ;;
            --follow)
                OPENCLAW_FOLLOW=true
                shift
                ;;
            -f)
                if [[ "${OPENCLAW_ACTION}" == "log" ]]; then
                    OPENCLAW_FOLLOW=true
                else
                    OPENCLAW_FORCE=true
                fi
                shift
                ;;
            --tail)
                OPENCLAW_TAIL="$2"
                if [[ -z "${OPENCLAW_TAIL}" || ! ${OPENCLAW_TAIL} =~ ^[0-9]+$ ]]; then
                    echo "無效的 tail 行數：$2" >&2
                    return 1
                fi
                shift 2
                ;;
            --command)
                if [[ -z "$2" ]]; then
                    echo "錯誤：--command 需要一個指令參數" >&2
                    return 1
                fi
                if [[ -n "${OPENCLAW_COMMAND}" ]]; then
                    echo "❌ 錯誤：指令只能指定一次 (--command 與位置參數擇一)" >&2
                    return 1
                fi
                OPENCLAW_COMMAND="$2"
                shift 2
                ;;
            --help|-h)
                show_openclaw_help
                return 2
                ;;
            *)
                # 位置參數只有 exec 收：exec 就是 bash，指令原封不動交給 bash -c，
                # 所以 `kde openclaw exec "openclaw dashboard"` 打的字跟容器裡實際
                # 跑的一致，不必為了跑 openclaw 的子指令把 openclaw 這個字拿掉。
                # 其他 action 一律報錯，錯字不會被靜默吃掉。
                # 開頭是 - 的一律當未知旗標，否則 `exec -x` 會被誤收成指令。
                if [[ "${OPENCLAW_ACTION}" == "exec" && "$1" != -* ]]; then
                    if [[ -n "${OPENCLAW_COMMAND}" ]]; then
                        echo "❌ 錯誤：指令只能指定一次 (--command 與位置參數擇一)" >&2
                        echo "   含空白的指令請用引號包成一個參數，例如：kde openclaw exec \"ls -la\"" >&2
                        return 1
                    fi
                    OPENCLAW_COMMAND="$1"
                    shift
                else
                    echo "未知參數：$1" >&2
                    show_openclaw_help >&2
                    return 1
                fi
                ;;
        esac
    done

    return 0
}

# 由 KDE_PATH 的 basename 推導容器名稱
# 非 [a-zA-Z0-9_.-] 的字元一律換成 -，避免目錄名含空白時 docker run --name 失敗
get_openclaw_container_name() {
    local ws
    ws=$(basename "${KDE_PATH}")
    ws=$(echo "${ws}" | sed 's/[^a-zA-Z0-9_.-]/-/g')
    echo "openclaw-${ws}"
}

# 容器 home 用的 named volume 名稱，與容器同樣由 workspace 推導
get_openclaw_home_volume_name() {
    echo "$(get_openclaw_container_name)-home"
}

# 確保容器 home 的 named volume 存在。
#
# 用 local driver + o=bind 指向 ${KDE_PATH}/.openclaw-home，而不是直接 bind mount
# 該目錄：兩者的內容都落在同一個主機路徑，差別在於 named volume 在首次掛載
# （目錄為空）時，Docker 會把映像裡 /home/node 的內容預先複製進去。直接 bind
# mount 一個空目錄則會把映像原有內容整個遮蔽掉——包括 .bashrc/.profile，以及
# 未來版本可能烤進 home 的東西（映像已設 PLAYWRIGHT_BROWSERS_PATH 指向
# ~/.cache/ms-playwright），那會變成安靜失效而不是明確錯誤。
#
# 但書：預先複製只在目錄為空時發生一次。既有 workspace 升級 base image 時，
# 新版映像新增在 home 的內容不會被補進來（這是 Docker named volume 的既定行為，
# 官方的 OPENCLAW_HOME_VOLUME 做法亦同）。
# docker volume create 本身是冪等的（同名已存在時直接回傳成功），
# 所以不需要先 inspect 再決定要不要建。
ensure_openclaw_home_volume() {
    mkdir -p "${KDE_PATH}/.openclaw-home"
    docker volume create --driver local \
        --opt type=none \
        --opt "device=${KDE_PATH}/.openclaw-home" \
        --opt o=bind \
        "$(get_openclaw_home_volume_name)" >/dev/null
}

# 組出三種容器（狀態檢查、onboard、gateway）共用的 docker run 參數。
# bash 陣列無法用回傳值傳遞，結果放在全域陣列 OPENCLAW_DOCKER_ARGS。
#
# 只放三者都需要的東西：掛載、身分、工作目錄。
# port、-d/-it、--name、--restart 由各 action 自行附加。
build_openclaw_docker_args() {
    ensure_openclaw_home_volume

    # docker.sock 的 gid，用來 --group-add 讓容器內能操作 Docker。
    # 取法與 scripts/utils/code-server.sh 一致：Linux 用 stat -c，macOS 退回 stat -f。
    local sock_gid
    sock_gid=$( (stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock 2>/dev/null) ) || true

    local puid="${PUID:-$(id -u)}"
    local pgid="${PGID:-$(id -g)}"

    OPENCLAW_DOCKER_ARGS=(
        --workdir "${KDE_PATH}"
        -e "PUID=${puid}"
        -e "PGID=${pgid}"
        # workspace 以相同絕對路徑掛入，容器內外路徑一致
        -v "${KDE_PATH}:${KDE_PATH}"
        # 掛「整個容器 home」而非只掛 ~/.openclaw。
        #
        # OpenClaw 的狀態並不只在 ~/.openclaw：codex 憑證在 ~/.codex、hermes 在
        # ~/.hermes、Claude CLI 整合要 ~/.claude、~/.claude.json 與
        # ~/.local/share/claude、legacy OAuth 的加密金鑰在 ~/.config/openclaw、
        # 個人 skills 在 ~/.agents，另有 ~/.npm 與 ~/.cache。逐個用環境變數覆寫
        # (CODEX_HOME、HERMES_HOME、CLAUDE_CONFIG_DIR、GEMINI_CLI_HOME…) 是追不完的:
        # 每新增一個 provider plugin 就要再補一行，且硬寫路徑、未提供覆寫的 plugin
        # 根本救不了。
        #
        # 官方 docker 指引本身就是這個做法 (OPENCLAW_HOME_VOLUME 持久化整個
        # /home/node，其 compose 範例即 ./openclaw-home -> /home/node)，理由相同。
        # 這樣 ~/.openclaw 自然位於 ${KDE_PATH}/.openclaw-home/.openclaw。
        -v "$(get_openclaw_home_volume_name):${OPENCLAW_CONTAINER_HOME}"
        -v "${KDE_CLI_PATH}:/usr/local/lib/kde:ro"
        -v /var/run/docker.sock:/var/run/docker.sock:ro
    )

    if [[ -n "${sock_gid}" ]]; then
        OPENCLAW_DOCKER_ARGS+=(--group-add "${sock_gid}")
    fi
}

# 容器是否存在（含已停止者）
is_openclaw_container_exist() {
    if docker ps -a --format '{{.Names}}' | grep -qx "$(get_openclaw_container_name)"; then
        echo "true"
    else
        echo "false"
    fi
}

# 容器是否正在運行
is_openclaw_container_running() {
    if docker ps --format '{{.Names}}' | grep -qx "$(get_openclaw_container_name)"; then
        echo "true"
    else
        echo "false"
    fi
}

# OpenClaw 是否已完成初始化。
#
# 判斷方式是在一次性容器內問 OpenClaw 自己「gateway.mode 是什麼」，
# 而不是看 .openclaw 目錄存不存在或是否為空。理由：
#   1. bind mount 會讓 Docker 自動建立不存在的 host 目錄，跑過任何一次 action
#      之後目錄必然存在，「存在與否」完全沒有鑑別力。
#   2. 目錄非空也不代表可用——onboarding 中途 Ctrl-C 會留下半成品 config，
#      gateway run 依然會拒絕啟動。
# gateway.mode=local 正是 openclaw gateway run 唯一在意的條件。
is_openclaw_onboarded() {
    if [[ "$(get_openclaw_config gateway.mode)" == "local" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# 在一次性無 TTY 容器內讀取單一設定值，讀不到時回傳空字串。
# 這是唯一一處直接問 OpenClaw 設定的地方，其他函式都經由它取值。
get_openclaw_config() {
    build_openclaw_docker_args
    docker run --rm "${OPENCLAW_DOCKER_ARGS[@]}" "${OPENCLAW_IMAGE}" \
        openclaw config get "$1" 2>/dev/null | tr -d '[:space:]' || true
}

# 執行初始化精靈。走一次性互動容器，不依賴 gateway 已在運行——
# 未初始化時 gateway run 會拒絕啟動，若要求使用者先 run 就會變成死結。
onboard_openclaw() {
    local name onboard_name
    name=$(get_openclaw_container_name)
    onboard_name="${name}-onboard"

    if docker ps -a --format '{{.Names}}' | grep -qx "${onboard_name}"; then
        echo "❌ 容器 ${onboard_name} 已存在，請先移除：docker rm -f ${onboard_name}"
        return 1
    fi

    if [[ "$(is_openclaw_onboarded)" == "true" && "${OPENCLAW_FORCE}" != "true" ]]; then
        echo "⚠️  OpenClaw 已初始化，重跑精靈會覆寫現有設定"
        read -p "確定要繼續嗎？(y/n) " answer
        if [[ "${answer}" != "y" ]]; then
            echo "已取消"
            return 0
        fi
    fi

    build_openclaw_docker_args
    # --agent-name main 是刻意釘住的，不是預設值的複述：帶了它，精靈就不會問
    # 「What should we call your first agent?」，而那一題填非 main 的名字會壞掉。
    #
    # 實測（OpenClaw 2026.8.2，互動精靈）：填 MaximeDev 時精靈確實建立了 agent
    # maximedev，並把 provider 的 OAuth 憑證寫進該 agent 自己的
    # agents/maximedev/agent/openclaw-agent.sqlite 的 auth_profile_store，
    # 但最後一次寫 config 時把 agents.entries 整段蓋掉了（三份備份都沒有它）。
    # roster 於是退回隱含的預設 agent main，而 main 的 auth store 是空的 ——
    # gateway 跑的是 main，聊天時就打出不帶 Authorization header 的請求，得到
    # 「401 Missing bearer or basic authentication in header」。
    # openclaw doctor 會把它報成「agent directory on disk without a matching
    # agents.list entry」。名字保留 main 時，即使 entries 同樣被蓋掉也無害：
    # 共用 auth store 的正規位置本來就是 agents/main（其他 agent 靠
    # agents.defaults.authInheritance 繼承它），而隱含的預設 agent 剛好是 main。
    #
    # 代價是不能在精靈裡命名第一個 agent，事後仍可用
    # openclaw agents set-identity / openclaw agents add 處理。
    #
    # 精靈被 Ctrl-C 中斷會回傳非零，不當成錯誤：下面統一以 gateway.mode 驗證結果
    docker run -it --rm --name "${onboard_name}" \
        "${OPENCLAW_DOCKER_ARGS[@]}" \
        "${OPENCLAW_IMAGE}" \
        openclaw onboard --mode local --agent-name main || true

    if [[ "$(is_openclaw_onboarded)" != "true" ]]; then
        echo "❌ 初始化未完成 (gateway.mode 仍不是 local)"
        return 1
    fi

    echo "✓ OpenClaw 初始化完成，可執行：kde openclaw run"
}

# 背景常駐啟動 gateway
run_openclaw_gateway() {
    local name
    name=$(get_openclaw_container_name)

    if [[ "$(is_openclaw_container_exist)" == "true" ]]; then
        echo "❌ 容器 ${name} 已存在，請先停止：kde openclaw stop"
        return 1
    fi

    if [[ "$(is_openclaw_onboarded)" != "true" ]]; then
        echo "❌ OpenClaw 尚未初始化 (gateway.mode 不是 local)"
        echo "   請先執行：kde openclaw onboard"
        return 1
    fi

    # gateway 綁在哪個位址，決定 dashboard 能不能從主機連進來。
    # OpenClaw 偵測到容器環境時預設 bind=auto(0.0.0.0)，但 onboarding 精靈常把
    # gateway.bind 明確寫成 loopback，而明確的 config 值會蓋過那個預設 —— 這時
    # gateway 只聽容器內的 127.0.0.1，-p 永遠轉不進去，dashboard 形同不存在。
    # 實測確認 CLI 的 --bind 旗標優先於 config，故在此覆蓋回來。
    #
    # 但 auth 關閉時不能加：OpenClaw 會以「Refusing to bind gateway to auto
    # without auth」拒絕啟動，硬加旗標等於把「能跑但連不到」變成「根本起不來」。
    # 那種情況改為據實告知，而不是印一個連不上的網址。
    local auth_mode
    auth_mode=$(get_openclaw_config gateway.auth.mode)
    local -a BIND_ARGS=()
    if [[ -n "${auth_mode}" && "${auth_mode}" != "none" ]]; then
        BIND_ARGS=(--bind auto)
    fi

    build_openclaw_docker_args
    if ! docker run -d --name "${name}" \
        --restart unless-stopped \
        -p "${OPENCLAW_PORT}:18789" \
        "${OPENCLAW_DOCKER_ARGS[@]}" \
        "${OPENCLAW_IMAGE}" \
        openclaw gateway run --port 18789 "${BIND_ARGS[@]}"; then
        echo "❌ gateway 容器啟動失敗"
        return 1
    fi

    # 健康檢查：gateway 設定不完整時容器會立刻退出，背景模式下使用者看不到，
    # 因此這裡主動確認並把日誌吐出來，而不是回報成功。
    # 等待秒數開放覆寫，是為了讓測試不必空等。
    #
    # 只看 State.Running 不夠：套用了 --restart unless-stopped 的容器若設定
    # 有誤會不斷 crash-loop，Docker 的重啟退避從 100ms 起跳，抽查當下極可能
    # 正好落在「剛被重啟、暫時 Running=true」的瞬間，導致健康檢查誤判成功。
    # 因此一併讀 RestartCount：只要曾經重啟過（>0），就代表容器並非穩定運行，
    # 一律視為失敗並吐出日誌，即使抽查當下 Running 剛好是 true。
    sleep "${OPENCLAW_HEALTH_WAIT:-3}"
    local state restarts
    read -r state restarts < <(docker inspect -f '{{.State.Running}} {{.RestartCount}}' "${name}" 2>/dev/null) || true
    if [[ "${state}" != "true" || -z "${restarts}" || "${restarts}" -ne 0 ]]; then
        echo "❌ gateway 啟動失敗，以下為容器日誌："
        docker logs --tail 50 "${name}" || true
        return 1
    fi

    echo "✓ openclaw gateway 已在背景啟動 (${name})"
    if [[ ${#BIND_ARGS[@]} -gt 0 ]]; then
        echo "存取網址: http://localhost:${OPENCLAW_PORT}"
    else
        echo "⚠️  gateway 的 auth 為 none，OpenClaw 只允許綁 loopback，"
        echo "   因此 dashboard 僅容器內可達，http://localhost:${OPENCLAW_PORT} 連不到。"
        echo "   要從主機使用 dashboard，請先啟用 auth：kde openclaw exec 後執行 openclaw configure"
    fi
    echo "查看日誌: kde openclaw log -f"
    echo "取得 token: kde openclaw token"
    echo "停止服務: kde openclaw stop"
}

# tui / exec 共用的前置檢查。兩者的條件與錯誤訊息完全相同，
# 抽成一個函式以免同一段話出現三份。
# 回傳 0=容器正在運行、1=否（並已印出錯誤訊息）
require_openclaw_container_running() {
    local name
    name=$(get_openclaw_container_name)

    if [[ "$(is_openclaw_container_running)" != "true" ]]; then
        echo "❌ 容器 ${name} 未在運行，請先執行：kde openclaw run"
        return 1
    fi
    return 0
}

# -u node 的理由（tui / exec 共通）：容器的 image USER 是 root（entrypoint 需要以
# root 身分做 usermod/groupmod/chown），而 docker exec 是直接照 image 設定建立行程、
# 完全繞過 entrypoint，不帶 -u 會以 root、HOME=/root 執行，讀不到 entrypoint 寫進
# /home/node 的設定，workspace 裡新建的檔案也會變成 host 上的 root 擁有。
# -u node 讓 Docker 查 /etc/passwd 解析 uid/gid/HOME，因此仍會正確追隨 entrypoint
# 對 node 做的 usermod -u ${PUID} 重映射。

# 互動進入 OpenClaw TUI
tui_openclaw() {
    local name
    name=$(get_openclaw_container_name)

    require_openclaw_container_running || return 1

    docker exec -u node -it "${name}" openclaw
}

# 進入容器執行 bash。刻意「不」代入 openclaw：
# 指令原封不動交給 bash -c，所以 `kde openclaw exec "openclaw dashboard"` 打的字
# 跟容器裡實際跑的一致。若這裡自動補上 openclaw，就得反過來把 openclaw 這個字
# 拿掉（`kde openclaw exec dashboard`），既反直覺、也跑不了容器內的其他指令
# （kde、git…）。互動的 OpenClaw TUI 改由 tui action 提供。
exec_openclaw() {
    local name
    name=$(get_openclaw_container_name)

    require_openclaw_container_running || return 1

    if [[ -n "${OPENCLAW_COMMAND}" ]]; then
        docker exec -u node "${name}" bash -c "${OPENCLAW_COMMAND}"
    else
        docker exec -u node -it "${name}" bash
    fi
}

# 查看 gateway 容器日誌。
#
# 前置條件刻意用「容器存在」而不是「容器正在運行」：容器因設定有誤而 crash 掉
# 之後，正是最需要看日誌的時候，而 docker logs 對已退出的容器仍讀得到。
log_openclaw() {
    local name
    name=$(get_openclaw_container_name)

    if [[ "$(is_openclaw_container_exist)" != "true" ]]; then
        echo "❌ 容器 ${name} 不存在，請先執行：kde openclaw run"
        return 1
    fi

    # 用陣列組旗標而不是字串內插：跟隨與否是一個旗標的有無，
    # 字串寫法在不跟隨時會多出一個空參數。
    # 這裡不能寫 `[[ ... ]] && args+=(...)`——條件為假時整行回傳非零，
    # 本檔在 set -eo pipefail 下會直接中止。
    local -a args=(logs)
    if [[ "${OPENCLAW_FOLLOW}" == "true" ]]; then
        args+=(-f)
    fi
    args+=(--tail "${OPENCLAW_TAIL}" "${name}")

    local rc=0
    docker "${args[@]}" || rc=$?
    # 跟隨模式下用 Ctrl-C 離開會讓 docker 回 130，那是正常結束而不是失敗
    if [[ "${OPENCLAW_FOLLOW}" == "true" && ${rc} -eq 130 ]]; then
        return 0
    fi
    return ${rc}
}

# 印出 gateway 的 auth token（stdout 只有 token 本身，可被管線接走）。
#
# 為什麼直接讀 openclaw.json，而不是用官方的 openclaw gateway auth-token：
#   1. 那個指令需要 --show，且實測（2026.8.2）會以「Refusing to print the Gateway
#      token outside an interactive terminal」拒絕印到非互動終端機，無法被腳本取用。
#   2. openclaw config get gateway.auth.token 回傳的是 __OPENCLAW_REDACTED__。
# 走一次性容器（與 get_openclaw_config 同一組掛載）而不是 docker exec，
# 因此 gateway 沒在運行也能取。
#
# 本函式是全檔唯一把錯誤訊息送到 stderr 的地方：stdout 是資料通道，
# 混進提示文字會讓 `kde openclaw token | xclip` 夾帶垃圾。
get_openclaw_token() {
    build_openclaw_docker_args

    local token=""
    token=$(docker run --rm "${OPENCLAW_DOCKER_ARGS[@]}" "${OPENCLAW_IMAGE}" \
        node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync('${OPENCLAW_CONTAINER_HOME}/.openclaw/openclaw.json','utf8'));process.stdout.write(c?.gateway?.auth?.token ?? '')" \
        2>/dev/null | tr -d '[:space:]') || true

    if [[ -z "${token}" ]]; then
        # 讀不到的兩種成因差很多，值得多花一次容器問清楚——反正只發生在失敗路徑
        local auth_mode
        auth_mode=$(get_openclaw_config gateway.auth.mode)
        if [[ "${auth_mode}" == "none" ]]; then
            echo "❌ gateway.auth.mode 為 none，本來就沒有 token" >&2
            echo "   要啟用 auth：kde openclaw exec 後執行 openclaw configure" >&2
        else
            echo "❌ 讀不到 gateway token (openclaw.json 的 gateway.auth.token 為空或檔案不存在)" >&2
            echo "   若尚未初始化，請先執行：kde openclaw onboard" >&2
        fi
        return 1
    fi

    echo "${token}"
}

# 停止並移除容器。容器本身是可拋棄的，狀態全在 workspace 的 .openclaw 裡。
# 回傳 0/1
stop_openclaw() {
    local name
    name=$(get_openclaw_container_name)

    if [[ "$(is_openclaw_container_exist)" != "true" ]]; then
        echo "容器 ${name} 不存在，無需停止"
        return 0
    fi

    # docker stop/rm 失敗時要給出本專案的錯誤訊息，而不是讓 set -e 直接中止：
    # 中止會跳過 docker rm 與收尾訊息，留下一個停一半、名稱還佔著的容器。
    if ! docker stop "${name}" >/dev/null; then
        echo "❌ 停止容器 ${name} 失敗，請手動處理：docker rm -f ${name}"
        return 1
    fi
    if ! docker rm "${name}" >/dev/null; then
        echo "❌ 移除容器 ${name} 失敗，請手動處理：docker rm -f ${name}"
        return 1
    fi
    echo "✓ 已停止並移除容器 ${name}"
    return 0
}

# 刪除 workspace 的 .openclaw（含 auth 密鑰）
reset_openclaw() {
    local name openclaw_dir
    name=$(get_openclaw_container_name)
    openclaw_dir="${KDE_PATH}/.openclaw-home"

    # 不在容器運行中抽掉設定，避免產生難以診斷的半死狀態
    if [[ "$(is_openclaw_container_running)" == "true" ]]; then
        echo "❌ 容器 ${name} 仍在運行，請先執行：kde openclaw stop"
        return 1
    fi

    if [[ ! -d "${openclaw_dir}" ]]; then
        echo "${openclaw_dir} 不存在，無需重設"
        return 0
    fi

    if [[ "${OPENCLAW_FORCE}" != "true" ]]; then
        echo "⚠️  將刪除 ${openclaw_dir} (含 OpenClaw 設定與 auth 密鑰)"
        read -p "確定要繼續嗎？(y/n) " answer
        if [[ "${answer}" != "y" ]]; then
            echo "已取消"
            return 0
        fi
    fi

    rm -rf "${openclaw_dir}"
    # 目錄刪了還要移除 volume 定義，否則會留下一個指向已不存在路徑的 volume，
    # 下次 run 會沿用它而不是重新建立、也就拿不到映像 home 的預先複製內容。
    docker volume rm "$(get_openclaw_home_volume_name)" >/dev/null 2>&1 || true
    echo "✓ 已刪除 ${openclaw_dir}"
}
