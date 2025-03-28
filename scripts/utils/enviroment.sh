#!/bin/bash

# 檢查 $1 的環境在 enviroments 底下是否存在，而且 enviroments 底下有 ENV_NAME 資料夾，而且存在 .env 檔案，存在則回傳 true，不存在則回傳 false
is_env_exist() {
    ENV_NAME=$1
    if [[ -n ${ENV_NAME} && -d ${ENVIROMENTS_PATH}/${ENV_NAME} && -n "$(ls -A ${ENVIROMENTS_PATH}/${ENV_NAME})" && -f ${ENVIROMENTS_PATH}/${ENV_NAME}/.env ]]; then
        echo "true"
    else
        echo "false"
    fi
}

is_env_running() {
    RUNNING_STATUS=$(docker ps --format "{{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.ID}} " --filter name=${1})
    if [[ -z "${RUNNING_STATUS}" ]]; then
        echo "false"
    else
        echo "true"
    fi
}

get_env_containers() {
    ENV_NAME=$1
    ENV_TYPE=$(get_env_type ${ENV_NAME})
    if [[ "${ENV_TYPE}" == "kind" ]]; then
        ENV_NAME="${ENV_NAME}-control-plane"
    elif [[ "${ENV_TYPE}" == "k3d" ]]; then
        ENV_NAME="k3d-${ENV_NAME}-server"
    else
        echo "錯誤的 ENV_TYPE: ${ENV_TYPE}"
        exit 1
    fi
    echo $(docker ps --format "{{.Names}}" --filter name=${ENV_NAME})
}

has_any_env() {
    if [[ ! -d ${ENVIROMENTS_PATH} || -z $(ls -1 ${ENVIROMENTS_PATH}) ]]; then
        echo "false"
    else
        echo "true"
    fi
}

exit_if_env_not_exist() {
    if [[ -z $1 || $(is_env_exist $1) == "false" ]]; then
        echo "環境 ${1} 不存在"
        exit 1
    fi
}

exit_if_env_not_running() {
    if [[ $(is_env_running $1) == "false" ]]; then
        echo "環境 ${ENV_NAME} 未啟動"
        exit 1
    fi
}

get_env_type() {
    ENV_NAME=$1
    load_enviroment_env ${ENV_NAME}
    echo "${ENV_TYPE}"
}

load_enviroment_env() {
    ENV_PATH=${ENVIROMENTS_PATH}/${1:-${CUR_ENV}}
    if [[ $(is_env_exist ${1:-${CUR_ENV}}) == "true" && -f ${ENV_PATH}/.env ]]; then
        source ${ENV_PATH}/.env
        export KUBECONFIG=${ENV_PATH}/${KUBE_CONFIG_DIR}/config
    fi
}

# 如果有 $1 則設定 CUR_ENV 為 $1，否則將 enviroments 底下第一個資料夾設定為 CUR_ENV
set_default_env() {
    # 如果 $1 沒有帶入參數
    if [[ -z "$1" ]]; then
        # 如果有環境存在 則設定 CUR_ENV 為 enviroments 底下第一個資料夾
        if [[ $(has_any_env) == "true" ]]; then
            export CUR_ENV=$(basename $(ls -d ${ENVIROMENTS_PATH}/*/ | head -n 1))
            echo "CUR_ENV=${CUR_ENV}" > ${KDE_PATH}/current.env
            echo "當前 k8s 環境已變更為: ${CUR_ENV}"
            load_enviroment_env ${CUR_ENV}
        # 如果沒有任何環境存在，則刪除 current.env
        else
            rm -f ${KDE_PATH}/current.env
            echo "目前沒有 k8s 環境"
        fi
    # 如果 $1 有帶入參數
    else
        # 如果 $1 環境不存在，則退出
        exit_if_env_not_exist $1
        export CUR_ENV=$1
        echo "CUR_ENV=${CUR_ENV}" > ${KDE_PATH}/current.env
        echo "當前 k8s 環境已變更為: ${CUR_ENV}"
        load_enviroment_env ${CUR_ENV}
    fi
    
}

stop_env() {
    # 如果 enviroments 底下不存在 $1 環境，則退出
    exit_if_env_not_exist $1
    load_enviroment_env $1
    # 如果環境正在運行，則停止
    if [[ $(is_env_running ${K8S_CONTAINER_NAME}) == "true" ]]; then
        echo "環境 ${ENV_NAME} 正在運行"
        ENV_TYPE=$(get_env_type ${ENV_NAME})
        containers=$(get_env_containers ${ENV_NAME}) 
        if [[ "$2" == "-f" || "$2" == "--force" ]]; then
            echo "強制刪除 k8s 容器: ${containers}"
            docker rm -f ${containers}
        else
            echo "停止 k8s 容器: ${containers}"
            docker stop ${containers}
            echo "刪除 k8s 容器: ${containers}"
            docker rm ${containers}
        fi
    else
        echo "環境 ${ENV_NAME} 未運行"
    fi
}

remove_env() {
    export ENV_NAME=${1}
    
    # 強制刪除 k8s 容器
    stop_env ${ENV_NAME} -f

    rm -rf ${ENVIROMENTS_PATH}/${ENV_NAME}
    echo "環境 ${ENV_NAME} 已刪除"
    set_default_env
    exit 0
}

init_env() {
    # 設定環境名稱 & 建立環境目錄
    export ENV_NAME=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    export ENV_TYPE=$2
    export ENV_PATH=${ENVIROMENTS_PATH}/${ENV_NAME}
    export ENV_FILE_PATH=${ENV_PATH}/.env
    if [[ $(is_env_exist ${ENV_NAME}) == "true" ]]; then
        echo "環境 ${ENV_NAME} 相關設定已存在 (${ENV_PATH})"
    else
        echo "環境 ${ENV_NAME} 尚未存在，開始初始化環境..."
        mkdir -p ${ENV_PATH}
        echo "ENV_NAME=${ENV_NAME}" >> ${ENV_PATH}/.env
        echo "ENV_TYPE=${ENV_TYPE}" >> ${ENV_PATH}/.env
        echo "CUR_ENV=${ENV_NAME}" > ${KDE_PATH}/current.env
        
        # 設定環境變數檔案路徑
        touch ${ENV_FILE_PATH}

        # 設定 K8S container 名稱
        if [[ "${ENV_TYPE}" == "kind" ]]; then
            export K8S_CONTAINER_NAME=${ENV_NAME}-control-plane
        else
            export K8S_CONTAINER_NAME=k3d-${ENV_NAME}-serverlb
        fi
        echo "K8S_CONTAINER_NAME=${K8S_CONTAINER_NAME}" >> ${ENV_FILE_PATH}

        # 如果 ca.key 不存在，則生成 ca.key 和 ca.crt
        if [[ ! -f ${ENV_PATH}/pki/ca.key ]]; then
            mkdir -p ${ENV_PATH}/pki
            openssl genrsa -out ${ENV_PATH}/pki/ca.key 2048
            openssl req -x509 -new -nodes -key ${ENV_PATH}/pki/ca.key -sha256 -days 3650 -out ${ENV_PATH}/pki/ca.crt \
                -subj "/C=TW/ST=Taipei/L=Taipei/O=KDE/OU=KDE/CN=${K8S_CONTAINER_NAME}"
        fi

        # 設定 DOCKER_NETWORK
        export DOCKER_NETWORK="kde-${ENV_NAME}"
        echo "DOCKER_NETWORK=${DOCKER_NETWORK}" >> ${ENV_FILE_PATH}

        # 輸入 K8S_API_SERVER_PORT
        read -p "請輸入 K8S api server port (預設: 6443): " K8S_API_SERVER_PORT
        export K8S_API_SERVER_PORT=${K8S_API_SERVER_PORT:-6443}

        # 輸入 K8S_INGRESS_NGINX_PORT
        read -p "請輸入 K8S ingress nginx port (預設: 80): " K8S_INGRESS_NGINX_PORT
        export K8S_INGRESS_NGINX_PORT=${K8S_INGRESS_NGINX_PORT:-80}

        # 設定 STORAGE_CLASS
        STORAGE_CLASS=local-path
        echo "STORAGE_CLASS=${STORAGE_CLASS}" >> ${ENV_FILE_PATH}

        # 設定 VOLUME_DIR
        mkdir -p ${ENV_PATH}/${VOLUMES_DIR}

        # 設定 KUBE_CONFIG_DIR
        mkdir -p ${ENV_PATH}/${KUBE_CONFIG_DIR}
        export KUBECONFIG=${ENV_PATH}/${KUBE_CONFIG_DIR}/config

        echo "環境 ${ENV_NAME} 初始化完畢"
    fi

    source ${ENV_FILE_PATH}
}

exec_port_forward() {
    NAMESPACE=$1
    RESOURCE_TYPE=$2
    RESOURCE_NAME=$3
    TARGET_PORT=$4
    LOCAL_PORT=$5

    docker run --rm -it \
    --net ${DOCKER_NETWORK} \
    -v ${KUBECONFIG}:/root/.kube/config \
    -p ${LOCAL_PORT}:${LOCAL_PORT} \
    docker.anyong.com.tw/quick-start/deploy-env:1.0.0 \
    bash -c "kubectl -n ${NAMESPACE} port-forward --address 0.0.0.0 ${RESOURCE_TYPE}/${RESOURCE_NAME} ${LOCAL_PORT}:${TARGET_PORT}"
}

is_port_valid() {
    if [[ $1 -ge 1 && $1 -le 65535 ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# 在 deploy-env 容器中執行指令（使用 TTY 模式執行命令）
exec_script_in_deploy_env() {
    docker run --rm -it \
    --net ${DOCKER_NETWORK} \
    -e KUBECONFIG=/.kube/config \
    -v ${KUBECONFIG}:/.kube/config \
    docker.anyong.com.tw/quick-start/deploy-env:1.0.0 \
    bash -c "$1"
}

# 在 deploy-env 容器中執行指令，並且回傳結果（不使用 TTY 模式執行命令）
exec_script_in_deploy_env_without_tty() {
    output=$(docker run --rm -i \
    --net ${DOCKER_NETWORK} \
    -e KUBECONFIG=/.kube/config \
    -v ${KUBECONFIG}:/.kube/config \
    docker.anyong.com.tw/quick-start/deploy-env:1.0.0 \
    bash -c "$1")

    echo "${output}"
}

# 進入 deploy-env 容器中的 Bash 環境，並且把 Volumes 的資料夾掛載進去 (使用 TTY 模式執行命令)
exec_bash_in_deploy_env_with_projects() {
    docker run --rm -it \
    --user $UID:$(id -g) \
    --net ${DOCKER_NETWORK} \
    --workdir /projects \
    -e KUBECONFIG=/.kube/config \
    -v ${KUBECONFIG}:/.kube/config \
    -v ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}:/projects \
    docker.anyong.com.tw/quick-start/deploy-env:1.0.0 \
    bash
}

# 進入 deploy-env 容器中的 Bash 環境，並且把 Volumes/{PROJECT_NAME} 的資料夾掛載進去 (使用 TTY 模式執行命令)
exec_script_in_container_with_project() {
    PROJECT_NAME=$1
    DOCKER_IMAGE=$2
    SCRIPT=$3
    
    docker run --rm -it \
    --user $UID:$(id -g) \
    --net ${DOCKER_NETWORK} \
    --workdir /${PROJECT_NAME} \
    --env-file ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env \
    -e KUBECONFIG=/.kube/config \
    -v ${ENVIROMENTS_PATH}/${CUR_ENV}/${KUBE_CONFIG_DIR}/config:/.kube/config \
    -v ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}:/${PROJECT_NAME} \
    ${DOCKER_IMAGE} \
    bash -c "${SCRIPT}"
}

create_namespace() {
    NAMESPACE=$1
    exec_script_in_deploy_env "kubectl create namespace ${NAMESPACE}"
}

get_namespaces() {
    namespaces=($(exec_script_in_deploy_env_without_tty 'kubectl get namespaces --no-headers -o custom-columns=":metadata.name"'))
    echo "${namespaces[@]}"
}

get_pods() {
    NAMESPACE=$1
    pods=($(exec_script_in_deploy_env_without_tty "kubectl -n ${NAMESPACE} get pods --no-headers -o custom-columns=":metadata.name""))
    echo "${pods[@]}"
}

get_services() {
    NAMESPACE=$1
    services=($(exec_script_in_deploy_env_without_tty "kubectl -n ${NAMESPACE} get services --no-headers -o custom-columns=":metadata.name""))
    echo "${services[@]}"
}

is_namespace_exist() {
    NAMESPACE=$1
    namespaces=($(get_namespaces))
    # 判斷 NAMESPACE 是否在 namespaces 中
    if [[ " ${namespaces[@]} " =~ " ${NAMESPACE} " ]]; then
        echo "true"
    else
        echo "false"
    fi
}

is_pod_exist() {
    NAMESPACE=$1
    POD=$2

    if [[ -z "${NAMESPACE}" || -z "${POD}" ]]; then
        echo "false"
        return
    fi

    pods=($(get_pods ${NAMESPACE}))
    # 判斷 POD 是否在 pods 中
    if [[ " ${pods[@]} " =~ " ${POD} " ]]; then
        echo "true"
    else
        echo "false"
    fi
}

is_service_exist() {
    NAMESPACE=$1
    SERVICE=$2
    
    if [[ -z "${NAMESPACE}" || -z "${SERVICE}" ]]; then
        echo "false"
        return
    fi
    
    services=($(get_services ${NAMESPACE}))
    # 判斷 SERVICE 是否在 services 中
    if [[ " ${services[@]} " =~ " ${SERVICE} " ]]; then
        echo "true"
    else
        echo "false"
    fi
}

is_pod_or_service_exist() {
    NAMESPACE=$1
    RESOURCE_TYPE=$2
    RESOURCE_NAME=$3

    # echo "NAMESPACE: ${NAMESPACE}"
    # echo "RESOURCE_TYPE: ${RESOURCE_TYPE}"
    # echo "RESOURCE_NAME: ${RESOURCE_NAME}"

    # 如果 RESOURCE_TYPE 為 pod 則使用 is_pod_exist 檢查，否則使用 is_service_exist 檢查
    if [[ "${RESOURCE_TYPE}" == "pod" ]]; then
        # echo "is_pod_exist"
        result=$(is_pod_exist ${NAMESPACE} ${RESOURCE_NAME})
    else
        # echo "is_service_exist"
        result=$(is_service_exist ${NAMESPACE} ${RESOURCE_NAME})
    fi

    printf "%s" "${result}"
}

has_any_namespace() {
    namespaces=($(exec_script_in_deploy_env_without_tty 'kubectl get namespaces --no-headers -o custom-columns=":metadata.name"'))
    
    if [ ${#namespaces[@]} -eq 0 ]; then
        echo "false"
    else
        echo "true"
    fi
}

has_any_pod() {
    NAMESPACE=$1
    POD=$2

    pods=($(kubectl -n ${NAMESPACE} get pods --no-headers -o custom-columns=":metadata.name"))
    
    if [ ${#pods[@]} -eq 0 ]; then
        echo "false"
    else
        echo "true"
    fi
}

has_any_service() {
    NAMESPACE=$1
    SERVICE=$2

    services=($(kubectl -n ${NAMESPACE} get services --no-headers -o custom-columns=":metadata.name"))
    
    if [ ${#services[@]} -eq 0 ]; then
        echo "false"
    else
        echo "true"
    fi
}
