#!/bin/bash

is_kind_init() {
    ENV_NAME=$1
    if [[ -f ${ENVIROMENTS_PATH}/${ENV_NAME}/kind-config.yaml ]]; then
        echo "true"
    else
        echo "false"
    fi
}

get_kind_containers() {
    ENV_NAME=$1
    echo $(docker ps --format "{{.Names}}" --filter "name=^${ENV_NAME}-(control-plane|worker)*")
}

stop_kind() {
    ENV_NAME=$1
    # 如果 enviroments 底下不存在 $1 環境，則退出
    exit_if_env_not_exist ${ENV_NAME}
    load_enviroment_env ${ENV_NAME}
    exit_if_env_not_running ${ENV_NAME}
    containers=$(get_kind_containers ${ENV_NAME}) 
    if [[ "$2" == "-f" || "$2" == "--force" ]]; then
        echo "強制刪除 k8s 容器: ${containers}"
        docker rm -f ${containers}
    else
        echo "停止 k8s 容器: ${containers}"
        docker stop ${containers}
        echo "刪除 k8s 容器: ${containers}"
        docker rm ${containers}
    fi
}

create_kind_env() {
    CONFIG_PATH=$1
    
    # 如果 $1 存在，則使用指定的 kind 的 config 路徑，並且複製到 ${ENV_PATH}/kind-config.template.yaml
    if [[ -n "${CONFIG_PATH}" ]]; then
        if [[ ! -f "${CONFIG_PATH}" ]]; then
            echo "指定的 kind 的 config 路徑不存在"
            exit 1
        fi
        cp ${CONFIG_PATH} ${ENV_PATH}/kind-config.template.yaml
    fi

    # 設定 K8S container 名稱
    export K8S_CONTAINER_NAME=${ENV_NAME}-control-plane
    echo "K8S_CONTAINER_NAME=${K8S_CONTAINER_NAME}" >> ${K8S_ENV_FILE_PATH}

    # 設定 DOCKER_NETWORK
    export DOCKER_NETWORK="kde-${ENV_NAME}"
    echo "DOCKER_NETWORK=${DOCKER_NETWORK}" >> ${K8S_ENV_FILE_PATH}

    # 設定 STORAGE_CLASS
    export STORAGE_CLASS=local-path
    echo "STORAGE_CLASS=${STORAGE_CLASS}" >> ${K8S_ENV_FILE_PATH}
}

init_kind_config() {
    # 如果 ${ENV_PATH}/kind-config.template.yaml 存在，則使用 ${ENV_PATH}/kind-config.template.yaml 設定 kind-config.yaml
    # 否則使用預設的 kind-config.yaml 模板 ${KDE_SCRIPTS_PATH}/utils/environment/kind-config.yaml 設定 kind-config.yaml
    if [[ -f ${ENV_PATH}/kind-config.template.yaml ]]; then
        CONFIG_TEMPLATE_PATH=${ENV_PATH}/kind-config.template.yaml
        echo "使用自訂模板: ${CONFIG_TEMPLATE_PATH}"
    else
        CONFIG_TEMPLATE_PATH=${KDE_SCRIPTS_PATH}/utils/environment/kind-config.yaml
        echo "使用預設模板: ${CONFIG_TEMPLATE_PATH}"
    fi

    # 設定 kind-config.yaml
    envsubst < ${CONFIG_TEMPLATE_PATH} > ${ENV_PATH}/kind-config.yaml
}

start_kind() {
    # 每次啟動都重新渲染 kind-config.yaml，
    # 讓 k8s.env / .env / 模板的修改在重啟後生效（手動修改 kind-config.yaml 會被覆蓋，請改模板）
    init_kind_config

    # Ensure Docker network
    if [ -z "$( docker network ls | awk '{print $2}' | grep ^$DOCKER_NETWORK$ )" ]; then
        docker network create $DOCKER_NETWORK
    fi

    # Install K8S
    docker run \
    --rm \
    -it \
    --net $DOCKER_NETWORK \
    -e KIND_EXPERIMENTAL_DOCKER_NETWORK=${DOCKER_NETWORK} \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v ${ENV_PATH}/${KUBE_CONFIG_DIR}:/root/.kube \
    -v ${ENV_PATH}/kind-config.yaml:/config.yaml \
    ${KIND_IMAGE} \
    sh -c "kind create cluster --config=/config.yaml && sed "s/0.0.0.0:[0-9]*/$K8S_CONTAINER_NAME:6443/ig" ~/.kube/config > ~/.kube/config.new && mv ~/.kube/config.new ~/.kube/config && chown $(id -u):$(id -g) ~/.kube/config"

    if [ $? -ne 0 ]; then
        echo "kind 初始化失敗"
        exit 1
    fi

    script=$(< ${KDE_SCRIPTS_PATH}/utils/environment/kind-install-default-services.sh)
    exec_script_in_deploy_env "${script}"

    if [[ -f ${ENV_PATH}/init.sh ]]; then
        script=$(< ${ENV_PATH}/init.sh)
        exec_script_in_deploy_env "${script}"
    fi

    echo "kind 初始化已完成"
}

kind_load_image() {
    IMAGE=$1
    ENV_NAME=$2

    docker run \
    --rm \
    -it \
    --net $DOCKER_NETWORK \
    -e KIND_EXPERIMENTAL_DOCKER_NETWORK=${DOCKER_NETWORK} \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v ${ENV_PATH}/${KUBE_CONFIG_DIR}:/root/.kube \
    -v ${ENV_PATH}/kind-config.yaml:/config.yaml \
    ${KIND_IMAGE} \
    sh -c "kind load docker-image ${IMAGE} --name ${ENV_NAME}"
}
