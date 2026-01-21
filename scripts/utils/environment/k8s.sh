#!/bin/bash

# 檢查 $1 的環境在 enviroments 底下是否存在，而且 enviroments 底下有 ENV_NAME 資料夾，而且存在 k8s.env 檔案，存在則回傳 true，不存在則回傳 false
is_env_exist() {
    ENV_NAME=$1
    if [[ -n ${ENV_NAME} && -d ${ENVIROMENTS_PATH}/${ENV_NAME} && -n "$(ls -A ${ENVIROMENTS_PATH}/${ENV_NAME})" && -f ${ENVIROMENTS_PATH}/${ENV_NAME}/k8s.env ]]; then
        echo "true"
    else
        echo "false"
    fi
}

is_env_initializing() {
    if [[ ${INITIALIZING} == "true" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

is_env_init() {
    ENV_NAME=$1
    if [[ -f ${ENVIROMENTS_PATH}/${ENV_NAME}/${KUBE_CONFIG_DIR}/config ]]; then
        echo "true"
    else
        echo "false"
    fi
}

is_env_running() {
    ENV_NAME=${1:-${CUR_ENV}}
    load_enviroment_env ${ENV_NAME}
    if [[ $(is_env_init ${ENV_NAME}) == "false" ]]; then
        echo "false"
    elif [[ $(is_k8s_node_ready) == "false" ]]; then
        echo "false"
    else
        echo "true"
    fi
}

is_k8s_node_ready() {
    # 設定 timeout (預設 2 秒)
    NODE_READY_TIMEOUT_SETTING="timeout ${K8S_NODE_READY_TIMEOUT:-2s}"
    # 設定 kubectl 指令
    NODE_READY_CHECK_COMMAND='kubectl get nodes --no-headers -o custom-columns=":status.conditions[?(@.type==\"Ready\")].status"'
    # 執行 kubectl 指令
    nodes=($(exec_script_in_deploy_env_without_tty "$NODE_READY_TIMEOUT_SETTING $NODE_READY_CHECK_COMMAND"))
    # 如果 nodes 數量為 0 則回傳 false
    if [[ ${#nodes[@]} -eq 0 ]]; then
        echo "false"
    else
        # 如果每個 node 的 status 都為 True 則回傳 true，只要有一個 node 的 status 為 False 則回傳 false
        for node in ${nodes}; do
            if [[ "${node}" != "True" ]]; then
                echo "false"
                return
            fi
        done
        echo "true"
    fi
}

has_any_env() {
    if [[ ! -d ${ENVIROMENTS_PATH} || -z $(ls -1 ${ENVIROMENTS_PATH}) ]]; then
        echo "false"
    else
        echo "true"
    fi
}

exit_if_env_init() {
    if [[ $(is_env_init $1) == "true" ]]; then
        echo "環境 ${1} 已初始化"
        exit 1
    fi
}

exit_if_env_not_exist() {
    if [[ -z $1 || $(is_env_exist $1) == "false" ]]; then
        echo "環境 ${1} 不存在"
        exit 1
    fi
}

exit_if_env_running() {
    ENV_NAME=$1
    if [[ $(is_env_running ${ENV_NAME}) == "true" ]]; then
        echo "環境 ${ENV_NAME} 已啟動"
        exit 1
    fi
}

exit_if_env_not_running() {
    ENV_NAME=$1
    if [[ $(is_env_running ${ENV_NAME}) == "false" ]]; then
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
    ENV_NAME=${1:-${CUR_ENV}}
    export ENV_PATH=${ENVIROMENTS_PATH}/${ENV_NAME}
    if [[ $(is_env_exist ${ENV_NAME}) == "true" ]]; then
        source ${ENV_PATH}/k8s.env
    fi
    if [[ $(is_env_init ${ENV_NAME}) == "true" ]]; then
        if [[ ! -f ${ENV_PATH}/.env ]]; then
            touch ${ENV_PATH}/.env
        fi
        source ${ENV_PATH}/.env
        export KUBECONFIG=${ENV_PATH}/${KUBE_CONFIG_DIR}/config
    fi
}

# 設定預設的 k8s 環境
# 如果有 $1 則設定 CUR_ENV 為 $1，否則將 enviroments 底下第一個資料夾設定為 CUR_ENV
set_default_env() {
    # 如果 $1 沒有帶入參數
    if [[ -z "$1" ]]; then
        # 如果有環境存在 則設定 CUR_ENV 為 enviroments 底下第一個資料夾
        if [[ $(has_any_env) == "true" ]]; then
            export CUR_ENV=$(basename $(ls -d ${ENVIROMENTS_PATH}/*/ | head -n 1))
            init_current_env
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
        init_current_env
        echo "當前 k8s 環境為: ${CUR_ENV}"
        load_enviroment_env ${CUR_ENV}
    fi
    
}

remove_env() {
    ENV_NAME=$1

    rm -rf ${ENVIROMENTS_PATH}/${ENV_NAME}
    echo "環境 ${ENV_NAME} 已刪除"
    set_default_env
}

init_current_env() {
    echo "CUR_ENV=${CUR_ENV}" > ${KDE_PATH}/current.env
}

create_k8s_env() {
    echo "開始初始化 ${ENV_NAME} 環境..."
    
    # 設定環境初始化中
    export INITIALIZING=true
    
    # 設定環境資料夾路徑
    mkdir -p ${ENV_PATH}

    # 設定 K8S 環境變數檔案路徑
    touch ${K8S_ENV_FILE_PATH}
    
    # 設定環境變數
    echo "ENV_NAME=${ENV_NAME}" >> ${K8S_ENV_FILE_PATH}
    echo "ENV_TYPE=${ENV_TYPE}" >> ${K8S_ENV_FILE_PATH}
}

init_kubeconfig_dir() {
    # 設定 KUBE_CONFIG_DIR
    mkdir -p ${ENV_PATH}/${KUBE_CONFIG_DIR}
    touch ${KUBECONFIG}
}

init_volume_dir() {
    # 設定 VOLUME_DIR
    export VOLUMES_PATH=${ENV_PATH}/${VOLUMES_DIR}
    echo "VOLUMES_PATH=${VOLUMES_PATH}" >> ${LOCAL_ENV_FILE_PATH}
    mkdir -p ${VOLUMES_PATH}
}

init_pki(){
    # 如果 ca.key 不存在，則生成 ca.key 和 ca.crt
    if [[ ! -f ${ENV_PATH}/pki/ca.key ]]; then
        mkdir -p ${ENV_PATH}/pki
        openssl genrsa -out ${ENV_PATH}/pki/ca.key 2048
        openssl req -x509 -new -nodes -key ${ENV_PATH}/pki/ca.key -sha256 -days 3650 -out ${ENV_PATH}/pki/ca.crt \
            -subj "/C=TW/ST=Taipei/L=Taipei/O=KDE/OU=KDE/CN=${K8S_CONTAINER_NAME}" \
            -extensions v3_ca \
            -config <(cat /etc/ssl/openssl.cnf <(printf "\n[v3_ca]\n\
                basicConstraints=CA:TRUE\n\
                subjectKeyIdentifier=hash\n\
                authorityKeyIdentifier=keyid:always,issuer:always\n"))
    fi
}

init_k8s_port() {
    # 如果 .env 檔案中沒有 K8S_API_SERVER_PORT 則輸入 K8S_API_SERVER_PORT
    if ! grep -q "K8S_API_SERVER_PORT" ${LOCAL_ENV_FILE_PATH}; then
        read -p "請輸入 K8S api server port (預設: 6443): " K8S_API_SERVER_PORT
        export K8S_API_SERVER_PORT=${K8S_API_SERVER_PORT:-6443}
        echo "K8S_API_SERVER_PORT=${K8S_API_SERVER_PORT}" >> ${LOCAL_ENV_FILE_PATH}
    else
        echo "K8S_API_SERVER_PORT=${K8S_API_SERVER_PORT}"
    fi

    # 輸入 K8S_INGRESS_NGINX_PORT
    if ! grep -q "K8S_INGRESS_NGINX_PORT" ${LOCAL_ENV_FILE_PATH}; then
        read -p "請輸入 K8S ingress nginx port (預設: 80): " K8S_INGRESS_NGINX_PORT
        export K8S_INGRESS_NGINX_PORT=${K8S_INGRESS_NGINX_PORT:-80}
        echo "K8S_INGRESS_NGINX_PORT=${K8S_INGRESS_NGINX_PORT}" >> ${LOCAL_ENV_FILE_PATH}
    else
        echo "K8S_INGRESS_NGINX_PORT=${K8S_INGRESS_NGINX_PORT}"
    fi
}

create_external_k8s_env() {
    # 設定 DOCKER_NETWORK
    export DOCKER_NETWORK="bridge"
    echo "DOCKER_NETWORK=${DOCKER_NETWORK}" >> ${K8S_ENV_FILE_PATH}
}

init_external_k8s() {
    KUBECONFIG_PATH=${1:-${KUBECONFIG_PATH}}
    # 設定 KUBECONFIG 路徑
    if [[ -z "${KUBECONFIG_PATH}" ]]; then
        read -e -p "請輸入 kubeconfig 路徑: " KUBECONFIG_PATH
    fi
    KUBECONFIG_PATH="${KUBECONFIG_PATH/#\~/$HOME}"
    cp ${KUBECONFIG_PATH} ${ENV_PATH}/${KUBE_CONFIG_DIR}/config

    if [[ -z "${K8S_CONTAINER_NAME}" ]]; then
        # Get the current context from kubeconfig
        CURRENT_CONTEXT=$(exec_script_in_deploy_env_without_tty "kubectl config current-context")

        # Get the cluster name from the current context
        CLUSTER_NAME=$(exec_script_in_deploy_env_without_tty "kubectl config view -o jsonpath=\"{.contexts[?(@.name == '${CURRENT_CONTEXT}')].context.cluster}\"")

        # Get the server IP from the cluster configuration
        SERVER_IP=$(exec_script_in_deploy_env_without_tty "kubectl config view -o jsonpath=\"{.clusters[?(@.name == '${CLUSTER_NAME}')].cluster.server}\" | sed 's|https://||' | cut -d: -f1")

        # 設定 K8S control plane node IP
        export K8S_CONTAINER_NAME=${SERVER_IP}
        echo "K8S_CONTAINER_NAME=${K8S_CONTAINER_NAME}" >> ${K8S_ENV_FILE_PATH}
    fi

    echo "K8S 環境設定初始化已完成"
}

exec_port_forward() {
    NAMESPACE=$1
    RESOURCE_TYPE=$2
    RESOURCE_NAME=$3
    TARGET_PORT=$4
    LOCAL_PORT=$5
    BACKGROUND=$6

    # 如果 BACKGROUND 為 true，則在背景執行
    if [[ "${BACKGROUND}" == "true" ]]; then
        docker run --rm -d \
        --net ${DOCKER_NETWORK} \
        -v ${KUBECONFIG}:/root/.kube/config \
        -p ${LOCAL_PORT}:${LOCAL_PORT} \
        ${KDE_DEPLOY_ENV_IMAGE} \
        bash -c "kubectl -n ${NAMESPACE} port-forward --address 0.0.0.0 ${RESOURCE_TYPE}/${RESOURCE_NAME} ${LOCAL_PORT}:${TARGET_PORT}"
    else
        docker run --rm -it \
        --net ${DOCKER_NETWORK} \
        -v ${KUBECONFIG}:/root/.kube/config \
        -p ${LOCAL_PORT}:${LOCAL_PORT} \
        ${KDE_DEPLOY_ENV_IMAGE} \
        bash -c "kubectl -n ${NAMESPACE} port-forward --address 0.0.0.0 ${RESOURCE_TYPE}/${RESOURCE_NAME} ${LOCAL_PORT}:${TARGET_PORT}"
    fi
}

is_port_valid() {
    if [[ $1 -ge 1 && $1 -le 65535 ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# kde-cli 使用
# 在 deploy-env 容器中執行指令（使用 TTY 模式執行命令）
exec_script_in_deploy_env() {
    docker run --rm -it \
    --net ${DOCKER_NETWORK} \
    -e KUBECONFIG=/.kube/config \
    -v ${KUBECONFIG}:/.kube/config \
    ${KDE_DEPLOY_ENV_IMAGE} \
    bash -c "$1"
}

# kde-cli 使用
# 在 deploy-env 容器中執行指令，並且回傳結果（不使用 TTY 模式執行命令）
exec_script_in_deploy_env_without_tty() {
    KUBECONFIG=${ENVIROMENTS_PATH}/${ENV_NAME}/${KUBE_CONFIG_DIR}/config

    output=$(docker run --rm -i \
    --net ${DOCKER_NETWORK} \
    -e KUBECONFIG=/.kube/config \
    -v ${KUBECONFIG}:/.kube/config \
    ${KDE_DEPLOY_ENV_IMAGE} \
    bash -c "$1" 2>/dev/null || echo "")
    
    echo "${output}"
}

# projects exec 使用
# 進入 deploy-env 容器中的 Bash 環境，並且把 Volumes 的資料夾掛載進去 (使用 TTY 模式執行命令)
exec_bash_in_deploy_env_with_projects() {
    docker run --rm -it \
    --user $UID:$(id -g) \
    --net ${DOCKER_NETWORK} \
    --workdir ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR} \
    --group-add $( (stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock) ) \
    -e KUBECONFIG=/.kube/config \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v ${KUBECONFIG}:/.kube/config \
    -v ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}:${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR} \
    ${KDE_DEPLOY_ENV_IMAGE} \
    bash
}

# project exec 、build、deploy 使用
# 進入 deploy-env 容器中的 Bash 環境(expose port)，並且把 Volumes/{PROJECT_NAME} 的資料夾掛載進去 (使用 TTY 模式執行命令)
exec_script_in_container_with_project_and_port() {
    PROJECT_NAME=$1
    DOCKER_IMAGE=$2
    SCRIPT=$3
    PORT=$4
    export PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    PROJECT_ENV_FILE=${PROJECT_PATH}/project.env
    PROJECT_ENV_FILE_TMP=${PROJECT_ENV_FILE}.tmp

    envsubst < ${PROJECT_ENV_FILE} > ${PROJECT_ENV_FILE_TMP}

    # 如果 .env 檔案不存在，則建立 .env 檔案
    if [ ! -f ${PROJECT_PATH}/.env ]; then
        touch ${PROJECT_PATH}/.env
    fi

    # 自動 export 所有 env 變數
    set -a
    . ${KDE_ENV_FILE}
    . ${ENVIROMENTS_PATH}/${CUR_ENV}/k8s.env
    . ${ENVIROMENTS_PATH}/${CUR_ENV}/.env
    . ${PROJECT_ENV_FILE_TMP}
    . ${PROJECT_PATH}/.env
    set +a
    # 將 KDE_MOUNT_* 環境變數轉換為 docker volume 參數
    set +e
    DOCKER_VOLUMES=$(env | grep '^KDE_MOUNT_' | cut -d= -f2- | sed 's/^/-v /' | xargs)
    set -e
    
    docker run --rm -it \
    --user $UID:$(id -g) \
    --net ${DOCKER_NETWORK} \
    --workdir ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME} \
    --group-add $( (stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock) ) \
    -p ${PORT}:${PORT} \
    --env-file ${PROJECT_ENV_FILE_TMP} \
    --env-file ${PROJECT_PATH}/.env \
    -e KUBECONFIG=/.kube/config \
    -v ${KUBECONFIG}:/.kube/config \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    ${DOCKER_VOLUMES} \
    -v ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}:${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME} \
    ${DOCKER_IMAGE} \
    bash -c "${SCRIPT}"
    
    if [[ -f "${PROJECT_ENV_FILE_TMP}" ]]; then
        rm -f ${PROJECT_ENV_FILE_TMP}
    fi
}

# project exec 、build、deploy 使用
# 進入 deploy-env 容器中的 Bash 環境，並且把 Volumes/{PROJECT_NAME} 的資料夾掛載進去 (使用 TTY 模式執行命令)
exec_script_in_container_with_project() {
    PROJECT_NAME=$1
    DOCKER_IMAGE=$2
    SCRIPT=$3
    export PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    PROJECT_ENV_FILE=${PROJECT_PATH}/project.env
    PROJECT_ENV_FILE_TMP=${PROJECT_ENV_FILE}.tmp

    envsubst < ${PROJECT_ENV_FILE} > ${PROJECT_ENV_FILE_TMP}
    
    # 如果 .env 檔案不存在，則建立 .env 檔案
    if [ ! -f ${PROJECT_PATH}/.env ]; then
        touch ${PROJECT_PATH}/.env
    fi

    # 自動 export 所有 env 變數
    set -a
    . ${KDE_ENV_FILE}
    . ${ENVIROMENTS_PATH}/${CUR_ENV}/k8s.env
    . ${ENVIROMENTS_PATH}/${CUR_ENV}/.env
    . ${PROJECT_ENV_FILE_TMP}
    . ${PROJECT_PATH}/.env
    set +a
    # 將 KDE_MOUNT_* 環境變數轉換為 docker volume 參數
    set +e
    DOCKER_VOLUMES=$(env | grep '^KDE_MOUNT_' | cut -d= -f2- | sed 's/^/-v /' | xargs)
    set -e
    
    docker run --rm -it \
    --user $UID:$(id -g) \
    --net ${DOCKER_NETWORK} \
    --workdir ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME} \
    --group-add $( (stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock) ) \
    --env-file ${PROJECT_ENV_FILE_TMP} \
    --env-file ${PROJECT_PATH}/.env \
    -e KUBECONFIG=/.kube/config \
    -v ${KUBECONFIG}:/.kube/config \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    ${DOCKER_VOLUMES} \
    -v ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}:${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME} \
    ${DOCKER_IMAGE} \
    bash -c "${SCRIPT}"

    if [[ -f "${PROJECT_ENV_FILE_TMP}" ]]; then
        rm -f ${PROJECT_ENV_FILE_TMP}
    fi
}

# 進入 deploy-env 容器中的 Bash 環境，並且把 Volumes/{PROJECT_NAME} 的資料夾掛載進去 (使用 TTY 模式執行命令)
exec_k8s_node() {
    docker exec -it ${K8S_CONTAINER_NAME} bash
}

create_namespace() {
    NAMESPACE=$1
    exec_script_in_deploy_env "kubectl create namespace ${NAMESPACE}"
}

get_nodes() {
    nodes=($(exec_script_in_deploy_env_without_tty 'kubectl get nodes --no-headers -o custom-columns=":metadata.name"'))
    echo "${nodes[@]}"
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

get_pod_ports() {
    NAMESPACE=$1
    POD=$2

    ports=($(exec_script_in_deploy_env_without_tty "kubectl -n ${NAMESPACE} get pod ${POD} --no-headers -o custom-columns=":spec.containers[*].ports[*].containerPort" | tr ',' ' '"))
    echo "${ports[@]}"
}

get_services() {
    NAMESPACE=$1
    services=($(exec_script_in_deploy_env_without_tty "kubectl -n ${NAMESPACE} get services --no-headers -o custom-columns=":metadata.name""))
    echo "${services[@]}"
}

get_service_ports() {
    NAMESPACE=$1
    SERVICE=$2

    ports=($(exec_script_in_deploy_env_without_tty "kubectl -n ${NAMESPACE} get service ${SERVICE} --no-headers -o custom-columns=":spec.ports[*].port" | tr ',' ' '"))
    echo "${ports[@]}"
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

select_namespace() {
    # 如果已經有 TARGET_NAMESPACE，則直接使用
    if [[ -n "${TARGET_NAMESPACE}" ]]; then
        return
    fi
    
    # 顯示所有 namespace
    namespaces=($(get_namespaces))
    PS3="請選擇一個 Namespace（輸入編號）："
    select namespace in "${namespaces[@]}" "退出"
    do
        case $namespace in
            "退出")
                echo "退出"
                exit 0
                ;;
            "")
                echo "無效選擇，請重新輸入。"
                ;;
            *)
                echo "你選擇了 Namespace: $namespace"
                export TARGET_NAMESPACE=$namespace
                break
                ;;
        esac
    done
}

select_service() {
    if [[ -n "${TARGET_SERVICE}" ]]; then
        return
    fi

    TARGET_NAMESPACE=$1

    # 顯示 namespace 下所有 service
    services=($(get_services ${TARGET_NAMESPACE}))

    # 檢查是否存在
    if [ ${#services[@]} -eq 0 ]; then
        echo "Namespace: ${TARGET_NAMESPACE} 目前沒有任何 service 存在。"
        exit 1
    elif [ ${#services[@]} -eq 1 ]; then
        export TARGET_SERVICE=${services[0]}
        echo "你選擇了 Service: ${TARGET_SERVICE}"
    else
        PS3="請選擇一個 Service（輸入編號）："
        select service in "${services[@]}" "退出"
        do
        case $service in
            "退出")
                echo "退出"
                exit 0
                ;;
            "")
                echo "無效選擇，請重新輸入。"
                ;;
            *)
                echo "你選擇了 Service: $service"
                export TARGET_SERVICE=$service
                break
                ;;
            esac
        done
    fi
}

select_pod() {
    if [[ -n "${TARGET_POD}" ]]; then
        return
    fi

    TARGET_NAMESPACE=$1

    # 顯示 namespace 下所有 pod
    pods=($(get_pods ${TARGET_NAMESPACE}))

    # 檢查是否存在
    if [ ${#pods[@]} -eq 0 ]; then
        # 如果 pods 數量等於 0 則顯示錯誤
        echo "Namespace: ${TARGET_NAMESPACE} 目前沒有任何 pod 存在。"
        exit 1
    elif [ ${#pods[@]} -eq 1 ]; then
        # 如果 pods 數量等於 1，則直接使用 Pod
        export TARGET_POD=${pods[0]}
        echo "你選擇了 Pod: ${TARGET_POD}"
    else
        PS3="請選擇一個 Pod（輸入編號）："
        select pod in "${pods[@]}" "退出"
        do
            case $pod in
                "退出")
                    echo "退出"
                    exit 0
                    ;;
                "")
                    echo "無效選擇，請重新輸入。"
                    ;;
                *)
                    echo "你選擇了 Pod: $pod"
                    export TARGET_POD=$pod
                    break
                    ;;
            esac
        done
    fi
}

select_port() {
    if [[ -n "${TARGET_PORT}" ]]; then
        return
    fi

    TARGET_NAMESPACE=$1
    TYPE=$2
    TARGET_RESOURCE=$3

    if [[ "${TYPE}" == "pod" ]]; then
        ports=($(get_pod_ports ${TARGET_NAMESPACE} ${TARGET_RESOURCE}))
    elif [[ "${TYPE}" == "service" ]]; then
        ports=($(get_service_ports ${TARGET_NAMESPACE} ${TARGET_RESOURCE}))
    else
        echo "錯誤的 TYPE: ${TYPE}"
        exit 1
    fi

    if [[ ${#ports[@]} == 0 || (${#ports[@]} == 1 && "${ports[0]}" == "<none>") ]]; then
        # 如果 ports 數量等於 0 或是顯示 "<none>"，請使用者輸入 port
        read -p "請輸入 ${TYPE} port: " LOCAL_PORT
        export TARGET_PORT=${LOCAL_PORT}
        echo "你選擇了 Port: ${TARGET_PORT}"
    else
        # 如果 ports 數量大於 1，則顯示選單
        PS3="請選擇要轉發的 Port（輸入編號）："
        select port in "${ports[@]}" "自選 Port" "退出"
        do
            case $port in
                "退出")
                    echo "退出"
                    exit 0
                    ;;
                "自選 Port")
                    read -p "請選擇要轉發的 Port: " LOCAL_PORT
                    export TARGET_PORT=${LOCAL_PORT}
                    echo "你選擇了 Port: ${TARGET_PORT}"
                    break
                    ;;
                "")
                    echo "無效選擇，請重新輸入。"
                    ;;
                *)
                    echo "你選擇了 Port: $port"
                    export TARGET_PORT=$port
                    break
                    ;;
            esac
        done
    fi
}

create_ingress(){
    NAMESPACE=$1
    INGRESS_NAME=$2
    DOMAIN=$3
    SERVICE=$4
    PORT=$5

    exec_script_in_deploy_env_without_tty "kubectl -n ${NAMESPACE} create ingress ${INGRESS_NAME} --rule=\"${DOMAIN}/*=${SERVICE}:${PORT}\" --class=nginx"
}

tail_pod_logs() {
    NAMESPACE=$1
    POD=$2
    TAIL_COUNT=${3:-100}

    exec_script_in_deploy_env "kubectl -n ${NAMESPACE} logs --tail ${TAIL_COUNT} -f ${POD}"
}

exec_pod() {
    NAMESPACE=$1
    POD=$2


    exec_script_in_deploy_env "kubectl -n ${NAMESPACE} exec -it ${POD} -- bash || kubectl -n ${NAMESPACE} exec -it ${POD} -- sh"
}