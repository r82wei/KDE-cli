#!/bin/bash

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde start <name> [option] [config] 啟動 k8s 環境"
    echo ""
    echo "option:"
    echo "  --kind           啟動 kind 環境 (預設)"
    echo "  --k3d, --k3s     啟動 k3d 環境"
    echo "  --k8s            啟動外部 K8S 環境"
    echo "config:            kind/k3d 的 config 路徑 (Optional)"
}

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    show_help
    exit 0
fi

export ENV_NAME=${1:-${CUR_ENV}}
while [[ -z "${ENV_NAME}" ]]; do
    read -p "請輸入環境名稱: " ENV_NAME
    ENV_NAME=$(echo "$ENV_NAME" | tr '[:upper:]' '[:lower:]')
done
export CUR_ENV=${ENV_NAME}
export ENV_PATH=${ENVIROMENTS_PATH}/${ENV_NAME}
export K8S_ENV_FILE_PATH=${ENV_PATH}/k8s.env
export LOCAL_ENV_FILE_PATH=${ENV_PATH}/.env
export KUBECONFIG=${ENV_PATH}/${KUBE_CONFIG_DIR}/config

if [[ $2 == "--k3d" || $2 == "k3d" || $2 == "--k3s" || $2 == "k3s" ]]; then
    ENV_TYPE="k3d"
elif [[ $2 == "--k8s" || $2 == "k8s" ]]; then
    ENV_TYPE="k8s"
else
    ENV_TYPE="kind"
fi

load_enviroment_env ${ENV_NAME}

# --- New-style environment path ---
# If environment.env exists, use the new environment abstraction layer
if [[ -f "${ENV_PATH}/environment.env" ]]; then
    source ${KDE_SCRIPTS_PATH}/utils/environment/environment.sh

    if [[ $(is_env_exist ${CUR_ENV}) == "false" ]]; then
        env_create
    fi

    if [[ $(is_env_init ${CUR_ENV}) == "false" ]]; then
        if declare -f _backend_env_init > /dev/null 2>&1; then
            _backend_env_init
        fi
    fi

    set_default_env ${CUR_ENV}
    env_start
    exit 0
fi
# --- End new-style path ---

# Legacy path below (existing code, unchanged)...

# 建立環境(判斷是否有 k8s.env)
if [[ $(is_env_exist ${CUR_ENV}) == "false" ]]; then
    create_k8s_env
    case "${ENV_TYPE}" in
        k3d)
            create_k3d_env $3
            ;;
        kind)
            create_kind_env $3
            ;;
        k8s)
            create_external_k8s_env
            ;;
    esac
fi

# 初始化環境(判斷是否有 kube config 檔案)
if [[ $(is_env_init ${CUR_ENV}) == "false" ]]; then
    touch ${LOCAL_ENV_FILE_PATH}

    init_kubeconfig_dir
    init_volume_dir

    case "${ENV_TYPE}" in
        k3d)
            init_pki
            init_k8s_port
            init_k3d_config
            ;;
        kind)
            init_pki
            init_k8s_port
            init_kind_config
            ;;
        k8s)
            init_external_k8s $3
            ;;
    esac
fi

# 設定預設環境
set_default_env ${CUR_ENV}

# 根據環境類型來選擇不同的處理流程
case "${ENV_TYPE}" in
    k3d)
        exit_if_env_running ${ENV_NAME}
        echo "啟動 k3d 環境"
        start_k3d
        ;;
    kind)
        exit_if_env_running ${ENV_NAME}
        echo "啟動 kind 環境"
        start_kind
        ;;
    k8s)
        echo -e "[STATUS]\t[Environment]"
        if [[ $(is_k8s_node_ready) == "true" ]]; then
            echo -e "\033[32m[RUNNING]\033[0m\t \033[32m${ENV_NAME}\033[0m"
        else
            echo -e "\033[31m[UNREADY]\033[0m\t \033[31m${ENV_NAME}\033[0m"
        fi
        exit 0
        ;;
esac