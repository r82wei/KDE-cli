#!/bin/bash

# 顯示 kde code-server 的使用說明
show_code_server_help() {
    echo "usage: kde code-server [option]"
    echo ""
    echo "example:"
    echo "  -d, --daemon        在背景執行"
    echo "  -p, --port          指定 code-server 的 port (預設為 8080)"
    echo "  -n, --name          指定 code-server 的容器名稱 (預設為 code-server，可用來同時啟動多個實例)"
    echo "  -v, --volume        指定掛載到 container 的目錄或檔案 (可重複指定多次，預設為當前路徑)"
    echo "                      格式 src[:dst[:ro|rw]]，例如 ./aio 或 .claude:/home/coder/.claude:ro"
    echo "  -w, --workdir       指定 code-server 開啟的資料夾 (container 路徑，預設為第一個目錄型掛載，須位於某個掛載底下)"
    echo "  -a, --agent         啟動時安裝指定的 AI agent (可重複指定多次，例如 claude、codex)"
    echo "                      已安裝者會跳過；設 KDE_CODE_SERVER_AI_AGENTS_REINSTALL=true 可強制重裝"
    echo "  -h, --help          顯示此幫助訊息"
}

# 解析 kde code-server 的參數，結果回填到 CODE_SERVER_* 全域變數
# 回傳 0=成功、1=參數錯誤、2=已顯示說明應結束
parse_code_server_args() {
    CODE_SERVER_DAEMON=false
    CODE_SERVER_PORT=8080
    CODE_SERVER_NAME=code-server
    CODE_SERVER_OPEN_PATH=""
    CODE_SERVER_MOUNTS=()
    CODE_SERVER_AGENTS=()
    CODE_SERVER_AGENTS_CSV=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --daemon|-d)
                CODE_SERVER_DAEMON=true
                shift
                ;;
            --port|-p)
                CODE_SERVER_PORT="$2"
                if [[ -z "${CODE_SERVER_PORT}" || ! ${CODE_SERVER_PORT} =~ ^[0-9]+$ ]]; then
                    echo "無效的 port：${CODE_SERVER_PORT}" >&2
                    return 1
                fi
                shift 2
                ;;
            --name|-n)
                CODE_SERVER_NAME="$2"
                if [[ -z "${CODE_SERVER_NAME}" || ! ${CODE_SERVER_NAME} =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
                    echo "無效的名稱：${CODE_SERVER_NAME}" >&2
                    return 1
                fi
                shift 2
                ;;
            --volume|-v)
                if [[ -z "$2" ]]; then
                    echo "無效的掛載路徑" >&2
                    return 1
                fi
                CODE_SERVER_MOUNTS+=("$2")
                shift 2
                ;;
            --workdir|-w)
                CODE_SERVER_OPEN_PATH="$2"
                if [[ -z "${CODE_SERVER_OPEN_PATH}" ]]; then
                    echo "無效的開啟資料夾路徑" >&2
                    return 1
                fi
                shift 2
                ;;
            --agent|-a)
                if [[ -z "$2" || ! "$2" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
                    echo "無效的 agent 名稱：$2" >&2
                    return 1
                fi
                CODE_SERVER_AGENTS+=("$2")
                shift 2
                ;;
            --help|-h)
                show_code_server_help
                return 2
                ;;
            *)
                echo "未知參數：$1" >&2
                show_code_server_help >&2
                return 1
                ;;
        esac
    done

    # 合併為 docker 環境變數用的逗號分隔字串
    local old_ifs="${IFS}"
    IFS=','
    CODE_SERVER_AGENTS_CSV="${CODE_SERVER_AGENTS[*]}"
    IFS="${old_ifs}"

    return 0
}

start_code_server() {
    local PORT=$1
    local DAEMON=$2
    local NAME=${3:-code-server}
    local OPEN_PATH_ARG=$4
    local AGENTS_CSV=$5
    shift 5
    local -a RAW_MOUNTS=("$@")

    # 無掛載目標時預設當前路徑
    if [[ ${#RAW_MOUNTS[@]} -eq 0 ]]; then
        RAW_MOUNTS=("$PWD")
    fi

    # 解析每個掛載值：支援 src、src:dst、src:dst:ro|rw
    local -a DSTS=()         # 每個掛載的 container 路徑（dst），作為去重與 workdir 依據
    local -a DIR_DSTS=()     # 其中 host src 為目錄者的 dst
    local -a MOUNT_ARGS=()   # 傳給 docker 的 -v 參數
    local -a MOUNT_SPECS=()  # 顯示用的 src:dst[:opt] 字串
    local raw src dst opt abs_src nfields
    for raw in "${RAW_MOUNTS[@]}"; do
        # 結尾多餘的冒號代表空欄位（read 會吃掉尾端空欄位，需另外擋）
        if [[ "$raw" == *: ]]; then
            echo "❌ 掛載格式錯誤（結尾多餘的冒號或空欄位）：$raw（應為 src[:dst[:ro|rw]]）"
            return 1
        fi
        # 以 : 切分欄位（here-string 會補上換行，read 回傳 0，set -e 安全）
        local -a parts=()
        IFS=':' read -ra parts <<< "$raw"
        nfields=${#parts[@]}
        if [[ ${nfields} -gt 3 ]]; then
            echo "❌ 掛載格式錯誤（欄位過多）：$raw（應為 src[:dst[:ro|rw]]）"
            return 1
        fi
        src=${parts[0]}
        dst=${parts[1]:-}
        opt=${parts[2]:-}

        # src 解析為絕對 host 路徑並驗證
        abs_src=$(readlink -f "$src" 2>/dev/null) || true
        if [[ ! -e "$abs_src" ]]; then
            echo "❌ 掛載來源不存在：$src"
            return 1
        fi
        if [[ ! -d "$abs_src" && ! -f "$abs_src" ]]; then
            echo "❌ 掛載來源必須是目錄或檔案：$src"
            return 1
        fi

        # dst：欄位省略則等於 src 絕對路徑；有給定則必須是非空絕對路徑
        if [[ ${nfields} -eq 1 ]]; then
            dst=$abs_src
        elif [[ -z "$dst" ]]; then
            echo "❌ 掛載目的路徑（container 內）不可為空：$raw"
            return 1
        elif [[ "$dst" != /* ]]; then
            echo "❌ 掛載目的路徑（container 內）必須是絕對路徑：$dst"
            return 1
        fi

        # opt：僅允許 ro / rw
        if [[ -n "$opt" && "$opt" != "ro" && "$opt" != "rw" ]]; then
            echo "❌ 掛載選項只能是 ro 或 rw：$opt"
            return 1
        fi

        # 以 dst 去重（同一 container 路徑只掛一次）；逐一字面比對，避免空白/萬用字元誤判
        local dd dup=false
        for dd in "${DSTS[@]}"; do
            if [[ "$dd" == "$dst" ]]; then dup=true; break; fi
        done
        if [[ "$dup" == "true" ]]; then
            continue
        fi
        DSTS+=("$dst")
        if [[ -d "$abs_src" ]]; then
            DIR_DSTS+=("$dst")
        fi
        if [[ -n "$opt" ]]; then
            MOUNT_ARGS+=(-v "${abs_src}:${dst}:${opt}")
            MOUNT_SPECS+=("${abs_src}:${dst}:${opt}")
        else
            MOUNT_ARGS+=(-v "${abs_src}:${dst}")
            MOUNT_SPECS+=("${abs_src}:${dst}")
        fi
    done

    # 決定開啟資料夾（workdir，為 container 路徑）
    local OPEN_PATH
    if [[ -n "$OPEN_PATH_ARG" ]]; then
        # 以 / 開頭視為 container 路徑原樣採用；否則對 host CWD 解析（相容相對路徑舊行為）
        if [[ "$OPEN_PATH_ARG" == /* ]]; then
            OPEN_PATH=$OPEN_PATH_ARG
        else
            OPEN_PATH=$(readlink -f "$OPEN_PATH_ARG" 2>/dev/null) || true
        fi
        if [[ -z "$OPEN_PATH" ]]; then
            echo "❌ 無效的開啟資料夾：${OPEN_PATH_ARG}"
            return 1
        fi
    else
        if [[ ${#DIR_DSTS[@]} -eq 0 ]]; then
            echo "❌ 沒有可開啟的目錄型掛載，請用 -w/--workdir 明確指定開啟資料夾"
            return 1
        fi
        OPEN_PATH=${DIR_DSTS[0]}
    fi

    # 開啟資料夾必須等於或位於某個目錄型掛載 (dst) 底下，否則 container 內看不到
    local under=false d
    for d in "${DIR_DSTS[@]}"; do
        if [[ "$OPEN_PATH" == "$d" || "$OPEN_PATH" == "$d"/* ]]; then
            under=true
            break
        fi
    done
    if [[ "$under" != "true" ]]; then
        echo "❌ 開啟資料夾 (${OPEN_PATH}) 必須位於其中一個目錄型掛載底下"
        return 1
    fi

    # 檢查同名容器是否已存在
    if docker ps -a --format '{{.Names}}' | grep -qx "${NAME}"; then
        echo "❌ 容器名稱 ${NAME} 已存在，請先停止/移除，或用 -n 指定其他名稱"
        echo "   docker rm -f ${NAME}"
        return 1
    fi

    local CONFIG_DIR=${KDE_PATH}/.code-server/${NAME}
    mkdir -p ${CONFIG_DIR}

    local DOCKER_SOCK_GID
    DOCKER_SOCK_GID=$( (stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock 2>/dev/null) ) || true

    # AI agent 相關環境變數：僅在有值時才附加，避免傳入空變數
    local -a AGENT_ARGS=()
    if [[ -n "${AGENTS_CSV}" ]]; then
        AGENT_ARGS+=(-e "KDE_CODE_SERVER_AI_AGENTS=${AGENTS_CSV}")
    fi
    if [[ -n "${KDE_CODE_SERVER_AI_AGENTS_REINSTALL:-}" ]]; then
        AGENT_ARGS+=(-e "KDE_CODE_SERVER_AI_AGENTS_REINSTALL=${KDE_CODE_SERVER_AI_AGENTS_REINSTALL}")
    fi

    if [[ "${DAEMON}" == "true" ]]; then
        docker run -it -d \
        --name ${NAME} \
        --workdir ${OPEN_PATH} \
        --group-add ${DOCKER_SOCK_GID} \
        -p ${PORT}:8080 \
        -e "PASSWORD=${PASSWORD}" \
        -v "${CONFIG_DIR}:/home/coder" \
        "${MOUNT_ARGS[@]}" \
        -v "${KDE_CLI_PATH}:/usr/local/lib/kde:ro" \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -u "$(id -u):$(id -g)" \
        -e "DOCKER_USER=$USER" \
        "${AGENT_ARGS[@]}" \
        ${CODE_SERVER_IMAGE} \
        ${OPEN_PATH}

        echo "✓ code-server 已在背景啟動 (${NAME})"
        echo "掛載目標:"
        for m in "${MOUNT_SPECS[@]}"; do echo "  - ${m}"; done
        echo "開啟資料夾: ${OPEN_PATH}"
        if [[ -n "${AGENTS_CSV}" ]]; then
            echo "AI Agents: ${AGENTS_CSV}"
        fi
        echo "存取網址: http://localhost:${PORT}"
        echo "停止服務: docker stop ${NAME}"
    else
        docker run -it --rm \
        --name ${NAME} \
        --workdir ${OPEN_PATH} \
        --group-add ${DOCKER_SOCK_GID} \
        -p ${PORT}:8080 \
        -e "PASSWORD=${PASSWORD}" \
        -v "${CONFIG_DIR}:/home/coder" \
        "${MOUNT_ARGS[@]}" \
        -v "${KDE_CLI_PATH}:/usr/local/lib/kde:ro" \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -u "$(id -u):$(id -g)" \
        -e "DOCKER_USER=$USER" \
        "${AGENT_ARGS[@]}" \
        ${CODE_SERVER_IMAGE} \
        ${OPEN_PATH}
    fi
}

# 暫時不使用
start_linuxserver_code_server() {
    PORT=$1
    DAEMON=$2

    if [[ "${DAEMON}" == "true" ]]; then
        docker run -it -d \
        -p ${PORT}:8443 \
        -e "PASSWORD=${PASSWORD}" \
        -v "${KDE_PATH}/.code-server:/config" \
        -v "${KDE_PATH}:/home/coder/project" \
        -e "PUID=${UID}" \
        -e "PGID=${GID}" \
        -e "DEFAULT_WORKSPACE=$USER" \
        --restart unless-stopped \
        lscr.io/linuxserver/code-server:latest
    else
        docker run -it --rm \
        -p ${PORT}:8443 \
        -e "PASSWORD=${PASSWORD}" \
        -e "SUDO_PASSWORD=${PASSWORD}" \
        -v "${KDE_PATH}/.code-server:/config" \
        -v "${KDE_PATH}:/home/coder/project" \
        -e "PUID=${UID}" \
        -e "PGID=${GID}" \
        -e "DEFAULT_WORKSPACE=$USER" \
        lscr.io/linuxserver/code-server:latest
    fi
}