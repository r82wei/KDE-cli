#!/bin/bash

# 設定 KDE scripts 路徑
export KDE_SCRIPTS_PATH=$(dirname "$(realpath "$0")")/scripts
# 設定 KDE 根目錄路徑
export KDE_PATH=$PWD
# 設定環境目錄路徑(enviroments)
export ENVIROMENTS_PATH=${KDE_PATH}/environments
# 設定 KUBE_CONFIG_DIR
export KUBE_CONFIG_DIR=kubeconfig
# 設定 VOLUMES_DIR
export VOLUMES_DIR=namespaces

source ${KDE_SCRIPTS_PATH}/utils/enviroment.sh

# 設定當前環境的環境變數
if [[ -f ${KDE_PATH}/current.env ]]; then
    source ${KDE_PATH}/current.env
fi

if [[ $(is_env_exist ${CUR_ENV}) == "false" ]]; then
    echo "環境 ${CUR_ENV} 不存在"
    # 修改預設環境
    set_default_env
fi

# 載入環境變數
load_enviroment_env ${CUR_ENV}


# 定義顯示說明的函數
show_help() {
    echo "usage: kde <command>"
    echo ""
    echo "command:"
    echo "  list, ls                            列出 k8s 環境"
    echo "  start <env_name> [--k3d]            建立/啟動 k8s 環境並且啟動 K9S (預設使用 kind，可使用參數 --k3d 啟動 k3d)"
    echo "  create <env_name> [--k3d]           建立/啟動 k8s 環境 (預設使用 kind，可使用參數 --k3d 建立 k3d)"
    echo "  stop [env_name]                     停止 k8s 環境 (預設停止 current.env 的當前使用中的 k8s 環境)"
    echo "  restart                             重啟 k8s 環境 (預設停止 current.env 的當前使用中的 k8s 環境)"
    echo "  status                              顯示 k8s 環境狀態"
    echo "  remove, rm                          移除 k8s 環境"
    echo "  current, cur                        顯示當前使用中的 k8s 環境名稱"
    echo "  use [env_name]                      切換當前使用中的 k8s 環境名稱"
    echo "  k9s [-p port]                       進入 k9s dashboard, 可使用 -p 參數，設定 k9s port-forward 的 port"
    echo "  expose                              將 service/pod port forward 到本地指定的 port"
    echo "  exec                                進入有部署相關工具的環境，並且掛載當前環境的 namespace 資料夾"
    echo "  reset                               重置 kde 環境，清除全部 environments 和 projects 資料夾"
    echo "  project, proj, namespace, ns        project 管理 (可以使用 kde project -h 查看詳細說明)"
    echo "  projects, projs                     projects(namespaces) 專案集合管理 (可以使用 kde projects -h 查看詳細說明)"
}


# 根據第一個參數來選擇不同的處理流程
case "$1" in
    ls|list)
        ls ${ENVIROMENTS_PATH}
        ;;
    start)
        shift  # 移除 "start" 指令
        source ${KDE_SCRIPTS_PATH}/start/command.sh
        source ${KDE_SCRIPTS_PATH}/k9s/start.sh
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
        shift  # 移除 "status" 指令
        set_default_env $1
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
        exit 0
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
        exit 0
        ;;
    *)
        show_help
        exit 0
        ;;
esac
