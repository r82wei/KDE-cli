#!/bin/bash

set -eo pipefail

# 設定 KDE 版本
export KDE_VERSION=v1.0.0-rc.6
# 設定 KDE cli 根目錄路徑
export KDE_CLI_PATH=$(dirname $(readlink -f "$0"))
# 設定 KDE 文件路徑
export KDE_DOCS_PATH=${KDE_CLI_PATH}/docs
# 設定 KDE 模板路徑
export KDE_TEMPLATES_PATH=${KDE_CLI_PATH}/templates
# 設定 KDE scripts 路徑
export KDE_SCRIPTS_PATH=${KDE_CLI_PATH}/scripts
# 解析全域旗標。目前只有 -C/--workspace，且一律要寫在子命令之前
# （kde -C <path> <command> ...）。
#
# 為什麼不用 -w：kde code-server 的 -w/--workdir 已經是「code-server 要開哪個
# 資料夾」，而全域旗標與子命令旗標可以同時出現在同一行
# （kde -C ~/ws code-server -w /ws/proj），共用同一個字母會真的看不懂。
# 這與 openclaw 的 -f 敢在 onboard(force)/log(follow) 共用不同 —— 那兩者不可能
# 同時適用於一個 action。-C 沿用 git/make 的「指定工作目錄」慣例。
#
# 記錄 workspace 是「明確指定」還是「由 $PWD 推導」：兩者定位失敗時該說的話不同。
# 推導不到時該建議 kde init；明確指定卻不對時，該指出那個路徑本身有問題 ——
# 對容器內的 agent 尤其重要，它拿到的 KDE_PATH 是帶入的。
KDE_WORKSPACE_GIVEN=false
if [[ -n "${KDE_PATH}" ]]; then
    KDE_WORKSPACE_GIVEN=true
fi
while [[ $# -gt 0 ]]; do
    case "$1" in
        -C|--workspace)
            if [[ -z "$2" ]]; then
                echo "❌ $1 需要一個 workspace 路徑" >&2
                exit 1
            fi
            # 絕對化：KDE_PATH 會被烤進容器的 -v 與 --workdir 參數
            # （見 scripts/utils/openclaw.sh、scripts/utils/code-server.sh），
            # 相對路徑傳給 Docker 會直接失敗。
            KDE_PATH=$(readlink -f "$2")
            KDE_WORKSPACE_GIVEN=true
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

# 設定 KDE workspace 根目錄路徑。
#
# 優先採用呼叫端帶入的 KDE_PATH（-C 旗標或環境變數）；只在它缺席（或為空字串）時，才由 $PWD 往上找
# kde.env（找到、或走到 / 為止；都沒有就退回 $PWD，讓後面的 kde.env 檢查報錯）。
#
# 為什麼要留這個出口：$PWD 推導的前提是「執行 kde 的人就站在 workspace 裡」。
# 這對人類成立，對容器內的 agent 不成立 —— kde openclaw 的 OpenClaw agent 家目錄
# 是 ~/.openclaw/workspace，它在那裡跑 kde 只會得到「kde.env 不存在，請先執行
# kde init」，而照著做會把整套 workspace 模板灌進 agent 自己的家目錄（kde init 是
# touch kde.env + cp -r templates/init/. ${KDE_PATH}/）。也就是說原本的行為不只是
# 「用不了」，是會主動誤導。帶入 KDE_PATH 讓 kde 在任何 cwd 下都指向同一個
# workspace，見 scripts/utils/openclaw.sh 的 -e KDE_PATH。
if [[ -z "${KDE_PATH}" ]]; then
    KDE_PATH=$PWD
    while [[ ! -f ${KDE_PATH}/kde.env && ${KDE_PATH} != "/" ]]; do
        KDE_PATH=$(dirname ${KDE_PATH})
    done
    if [[ ! -f ${KDE_PATH}/kde.env ]]; then
        KDE_PATH=$PWD
    fi
fi
export KDE_PATH

# 明確指定的路徑要先確認存在。不能只靠後面的 kde.env 檢查：目錄不存在與
# 目錄存在但不是 workspace 是兩種錯誤，混成一句話會讓打錯路徑的人去找 kde.env。
if [[ "${KDE_WORKSPACE_GIVEN}" == "true" && ! -d "${KDE_PATH}" ]]; then
    echo "❌ 指定的 workspace 目錄不存在：${KDE_PATH}" >&2
    exit 1
fi

# 設定環境目錄路徑(enviroments)
export ENVIROMENTS_PATH=${KDE_PATH}/environments
# 設定 KDE 文件目標路徑
export KDE_DOCS_TARGET_PATH=${KDE_PATH}/docs/kde-cli

# 設定 KUBE_CONFIG_DIR
export KUBE_CONFIG_DIR=kubeconfig
# 設定 VOLUMES_DIR
export VOLUMES_DIR=namespaces
# 設定 kde env 檔案路徑
export KDE_ENV_FILE=${KDE_PATH}/kde.env

# 定義顯示說明的函數
show_help() {
    echo "usage: kde [-C <workspace>] <command>"
    echo ""
    echo "global option (必須寫在 command 之前):"
    echo "  -C, --workspace <path>                              指定 workspace 根目錄，不由當前路徑往上找 kde.env"
    echo "                                                      (亦可用環境變數 KDE_PATH；-C 優先)"
    echo ""
    echo "command:"
    echo "  init                                                初始化 kde 環境"
    echo "  docs                                                建立 kde-cli 文件"
    echo "  list, ls                                            列出 k8s 環境"
    echo "  start <env_name> [kind|k3d|k8s]                     建立/啟動 k8s 環境並且啟動 K9S (預設使用 kind，可使用參數 k3d 啟動 k3d，可使用參數 k8s 啟動外部 K8S)"
    echo "  create <env_name> [kind|k3d|k8s]                    建立/啟動 k8s 環境 (預設使用 kind，可使用參數 k3d 建立 k3d，可使用參數 k8s 建立外部 K8S)"
    echo "  stop [env_name]                                     停止 k8s 環境 (預設操作 current.env 的當前使用中的 k8s 環境)"
    echo "  restart [env_name]                                  重啟 k8s 環境 (預設操作 current.env 的當前使用中的 k8s 環境)"
    echo "  status                                              顯示 k8s 環境狀態"
    echo "  remove, rm                                          移除 k8s 環境"
    echo "  current, cur                                        顯示當前使用中的 k8s 環境名稱"
    echo "  use [env_name]                                      切換當前使用中的 k8s 環境名稱"
    echo "  load-image <image> [env_name]                       載入 docker image 到 k8s 環境"
    echo "  k9s [-p port]                                       進入 k9s dashboard, 可使用 -p 參數，設定 k9s port-forward 的 port"
    echo "  dashboard [-p port] [--insecure]                    進入 k8s Web UI Dashboard"
    echo "  headlamp [-p port]                                  進入 headlamp Dashboard"
    echo "  expose                                              將 service/pod port forward 到本地指定的 port"
    echo "  exec                                                進入 k8s node container 環境"
    echo "  reset                                               重置 kde 環境，清除全部 environments 和 projects 資料夾"
    echo "  project, proj, namespace, ns                        project 管理 (可以使用 kde project -h 查看詳細說明)"
    echo "  projects, projs                                     projects(namespaces) 專案集合管理"
    echo "  ngrok                                               啟動 ngrok"
    echo "  cloudflare-tunnel <target> [options]                透過 Cloudflare Tunnel 建立連線 (可以使用 kde cloudflare-tunnel -h 查看詳細說明)"
    echo "  telepresence <command> [namespace] [workload]       透過 Telepresence 連接 k8s 環境，透過本地容器環境取代目標 Pod 的流量 (可以使用 kde telepresence -h 查看詳細說明)"
    echo "  code-server [-d] [-p port] [-n name] [-v dir] [-w dir] [-a agent]   啟動 code-server，-d 背景執行，-p 指定 port，-n 指定容器名稱(可同時啟動多個)，-v 指定掛載目錄或檔案，格式 src[:dst[:ro|rw]](可重複指定多次，預設當前路徑)，-w 指定開啟的資料夾，-a 啟動時安裝 AI agent(可重複指定多次)"
    echo "  openclaw <run|onboard|stop|restart|backup|upgrade|downgrade|tui|exec|log|token|dashboard|reset> 以容器啟動 OpenClaw agent，可在容器內使用 kde CLI (可以使用 kde openclaw -h 查看詳細說明)"
    echo "  claude-skill <install|update|status>                安裝 KDE Claude Code 技能到 ~/.claude/skills/"
    echo "  alias <name> [path]                                 建立 alias 指令，透過 tmux 快速啟動 session 到指定路徑的目錄 (需要安裝 tmux)"
    echo "  version                                             顯示 KDE 版本"
}

# 如果沒有參數，則顯示說明
if [[ $# -eq 0 ]]; then
    show_help
    exit 0
fi

# 不需要環境初始化就可以執行的指令
case "$1" in
    --init|init)
        touch ${KDE_ENV_FILE}
        cp -r ${KDE_TEMPLATES_PATH}/init/. ${KDE_PATH}/
        cp -r ${KDE_DOCS_PATH} ${KDE_DOCS_TARGET_PATH}
        exit 0
        ;;
    -v|version|--version)
        echo "${KDE_VERSION}"
        exit 0
        ;;
    ls|list)
        if [[ -d ${ENVIROMENTS_PATH} ]]; then
            ls ${ENVIROMENTS_PATH}
        else
            echo "environments 資料夾不存在"
        fi
        exit 0
        ;;
    alias)
        shift  # 移除 "alias" 指令
        source ${KDE_SCRIPTS_PATH}/alias/command.sh
        exit 0
        ;;
    -h|help|--help)
        show_help
        exit 0
        ;;
    claude-skill)
        shift  # 移除 "claude-skill" 指令
        source ${KDE_SCRIPTS_PATH}/claude-skill/command.sh
        exit 0
        ;;
esac

source ${KDE_SCRIPTS_PATH}/utils/environment/k8s.sh
source ${KDE_SCRIPTS_PATH}/utils/environment/kind.sh
source ${KDE_SCRIPTS_PATH}/utils/environment/k3d.sh
source ${KDE_SCRIPTS_PATH}/utils/k9s.sh

# 新增或載入 kde.env 環境變數設定檔
# 使用 set -a 載入，讓 envsubst 渲染 config 模板時看得到 kde.env 的變數
if [[ ! -f ${KDE_ENV_FILE} ]]; then
    # 明確指定（-C 或帶入 KDE_PATH）與 $PWD 推導失敗要分開講。
    # 前者叫人跑裸的 kde init 是錯的建議：那會把模板灌進當下的 KDE_PATH，
    # 而容器內的 agent 照做就是灌進它自己的家目錄。
    if [[ "${KDE_WORKSPACE_GIVEN}" == "true" ]]; then
        echo "❌ 指定的 workspace 沒有 kde.env：${KDE_PATH}" >&2
        echo "   若要在該路徑初始化：kde -C ${KDE_PATH} init" >&2
    else
        echo "kde.env 不存在，請先執行 kde init 初始化環境"
    fi
    exit 1
else
    set -a
    source ${KDE_ENV_FILE}
    set +a
fi

# 設定 KDE 的 debug 模式
if [[ -n ${KDE_DEBUG} && ${KDE_DEBUG} != "false" ]]; then
    set -x
fi

# 設定預設 kde 預設 image 環境變數
if [[ -z ${KIND_IMAGE} ]]; then
    export KIND_IMAGE=r82wei/kind:v0.27.0
    echo "KIND_IMAGE=${KIND_IMAGE}" >> ${KDE_ENV_FILE}
fi
if [[ -z ${K3D_IMAGE} ]]; then
    export K3D_IMAGE=r82wei/k3d:v5.8.3
    echo "K3D_IMAGE=${K3D_IMAGE}" >> ${KDE_ENV_FILE}
fi
if [[ -z ${KDE_DEPLOY_ENV_IMAGE} ]]; then
    export KDE_DEPLOY_ENV_IMAGE=r82wei/deploy-env:1.0.0
    echo "KDE_DEPLOY_ENV_IMAGE=${KDE_DEPLOY_ENV_IMAGE}" >> ${KDE_ENV_FILE}
fi
if [[ -z ${NGROK_PROXY_IMAGE} ]]; then
    export NGROK_PROXY_IMAGE=r82wei/ngrok-proxy:1.0.0
    echo "NGROK_PROXY_IMAGE=${NGROK_PROXY_IMAGE}" >> ${KDE_ENV_FILE}
fi
if [[ -z ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} ]]; then
    export CLOUDFLARE_TUNNEL_PROXY_IMAGE=r82wei/cloudflare-tunnel-proxy:1.0.0
    echo "CLOUDFLARE_TUNNEL_PROXY_IMAGE=${CLOUDFLARE_TUNNEL_PROXY_IMAGE}" >> ${KDE_ENV_FILE}
fi
if [[ -z ${K8S_UI_DASHBOARD_IMAGE} ]]; then
    export K8S_UI_DASHBOARD_IMAGE=kubernetesui/dashboard:v2.7.0
    echo "K8S_UI_DASHBOARD_IMAGE=${K8S_UI_DASHBOARD_IMAGE}" >> ${KDE_ENV_FILE}
fi
if [[ -z ${K9S_IMAGE} ]]; then
    export K9S_IMAGE=r82wei/k9s:v0.50.18
    echo "K9S_IMAGE=${K9S_IMAGE}" >> ${KDE_ENV_FILE}
fi
if [[ -z ${TELEPRESENCE_IMAGE} ]]; then
    export TELEPRESENCE_IMAGE=r82wei/telepresence:1.0.6
    echo "TELEPRESENCE_IMAGE=${TELEPRESENCE_IMAGE}" >> ${KDE_ENV_FILE}
fi
if [[ -z ${CODE_SERVER_IMAGE} ]]; then
    export CODE_SERVER_IMAGE=docker.io/r82wei/kde-code-server:latest
    echo "CODE_SERVER_IMAGE=${CODE_SERVER_IMAGE}" >> ${KDE_ENV_FILE}
fi
if [[ -z ${OPENCLAW_IMAGE} ]]; then
    export OPENCLAW_IMAGE=docker.io/r82wei/kde-openclaw:latest
    echo "OPENCLAW_IMAGE=${OPENCLAW_IMAGE}" >> ${KDE_ENV_FILE}
fi


# 設定 ngrok 的環境變數
if [[ -f ${KDE_PATH}/ngrok.env ]]; then
    source ${KDE_PATH}/ngrok.env
fi

# 設定當前環境的環境變數
# 判斷 $PWD 是否在 ENVIROMENTS_PATH 底下某個環境資料夾內（含該環境資料夾及其子資料夾）
if [[ -d ${ENVIROMENTS_PATH} ]]; then
    pwd_resolved=$(readlink -f "${PWD}")
    for env in $(ls ${ENVIROMENTS_PATH}); do
        env_path=$(readlink -f "${ENVIROMENTS_PATH}/${env}")
        if [[ ${pwd_resolved} == "${env_path}" ]] || [[ ${pwd_resolved} == "${env_path}"/* ]]; then
            CUR_ENV=${env}
            echo "目前在 ${CUR_ENV} 環境底下，設定當前環境為 ${CUR_ENV}"
            break
        fi
    done
fi

if [[ -z ${CUR_ENV} ]]; then
    if [[ -f ${KDE_PATH}/current.env ]]; then
        source ${KDE_PATH}/current.env
        # 導到 stderr：這是資訊性提示，不是指令的輸出。留在 stdout 會汙染
        # 以 stdout 當資料通道的子命令（例如 kde openclaw token | xclip）。
        echo "從 current.env 檔案中讀取當前環境為 ${CUR_ENV}" >&2
    fi
fi

if [[ $(is_env_exist ${CUR_ENV}) == "false" ]]; then
    echo "環境 ${CUR_ENV} 不存在"
    # 修改預設環境
    set_default_env
fi

# 載入環境變數
load_enviroment_env ${CUR_ENV}

# 根據第一個參數來選擇不同的處理流程
case "$1" in
    docs)
        if [[ -d ${KDE_DOCS_TARGET_PATH} ]]; then
            # 提示是否要覆蓋
            read -p "kde-cli 文件已存在，是否要覆蓋？(y/n) " answer
            if [[ $answer != "y" ]]; then
                exit 0
            fi
        fi
        cp -r ${KDE_DOCS_PATH} ${KDE_DOCS_TARGET_PATH}
        echo "kde-cli 文件已建立"
        exit 0
        ;;
    start)
        shift  # 移除 "start" 指令
        source ${KDE_SCRIPTS_PATH}/start/command.sh
        start_k9s
        ;;
    create)
        shift  # 移除 "create" 指令
        source ${KDE_SCRIPTS_PATH}/start/command.sh
        ;;
    stop)
        shift  # 移除 "stop" 指令
        source ${KDE_SCRIPTS_PATH}/stop/command.sh
        ;;
    restart)
        shift  # 移除 "restart" 指令
        source ${KDE_SCRIPTS_PATH}/restart/command.sh
        ;;
    status)
        shift  # 移除 "status" 指令
        source ${KDE_SCRIPTS_PATH}/status/command.sh
        ;;
    current|cur)
        if [[ -z "${CUR_ENV}" ]]; then
            echo "目前沒有設定任何 k8s 環境"
        else
            echo "當前 k8s 環境名稱: ${CUR_ENV}"
        fi
        ;;
    use)
        shift  # 移除 "use" 指令
        source ${KDE_SCRIPTS_PATH}/use/command.sh
        ;;
    load-image)
        shift  # 移除 "load-image" 指令
        source ${KDE_SCRIPTS_PATH}/load-image/command.sh
        ;;
    remove|rm)
        shift  # 移除 "remove" 指令
        source ${KDE_SCRIPTS_PATH}/remove/command.sh
        ;;
    exec)
        shift  # 移除 "exec" 指令
        source ${KDE_SCRIPTS_PATH}/exec/command.sh
        ;;
    expose)
        shift  # 移除 "expose" 指令
        source ${KDE_SCRIPTS_PATH}/expose/command.sh
        ;;
    k9s)
        shift  # 移除 "k9s" 指令
        source ${KDE_SCRIPTS_PATH}/k9s/command.sh
        ;;
    dashboard)
        shift  # 移除 "dashboard" 指令
        source ${KDE_SCRIPTS_PATH}/dashboard/command.sh
        ;;
    headlamp)
        shift  # 移除 "headlamp" 指令
        source ${KDE_SCRIPTS_PATH}/headlamp/command.sh
        ;;
    project|proj|namespace|ns)
        shift  # 移除 "project"  指令
        source ${KDE_SCRIPTS_PATH}/project/command.sh
        ;;
    projects|projs)
        shift  # 移除 "projects"  指令
        source ${KDE_SCRIPTS_PATH}/projects/command.sh
        ;;
    reset)
        shift  # 移除 "reset" 指令
        source ${KDE_SCRIPTS_PATH}/reset/command.sh
        ;;
    ngrok)
        shift  # 移除 "ngrok" 指令
        source ${KDE_SCRIPTS_PATH}/ngrok/command.sh
        ;;
    cloudflare-tunnel)
        shift  # 移除 "cloudflare-tunnel" 指令
        source ${KDE_SCRIPTS_PATH}/cloudflare-tunnel/command.sh
        ;;
    telepresence)
        shift  # 移除 "telepresence" 指令
        source ${KDE_SCRIPTS_PATH}/telepresence/command.sh
        ;;
    code-server)
        shift  # 移除 "code-server" 指令
        source ${KDE_SCRIPTS_PATH}/code-server/command.sh
        ;;
    openclaw)
        shift  # 移除 "openclaw" 指令
        source ${KDE_SCRIPTS_PATH}/openclaw/command.sh
        ;;
    *)
        show_help
        ;;
esac
