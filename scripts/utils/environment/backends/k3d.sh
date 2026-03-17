#!/bin/bash

# Environment backend: K3D
# Creates local K8s clusters using K3D (K3s in Docker).
# Implements _backend_env_* interface for the environment dispatcher.

_backend_env_create() {
    CONFIG_PATH=$1

    # 如果 $1 存在，則使用指定的 k3d 的 config 路徑
    if [[ -n "${CONFIG_PATH}" ]]; then
        if [[ ! -f "${CONFIG_PATH}" ]]; then
            echo "指定的 k3d 的 config 路徑不存在"
            exit 1
        fi
        cp ${CONFIG_PATH} ${ENV_PATH}/k3d-config.template.yaml
    fi

    # 設定 K8S container 名稱
    export K8S_CONTAINER_NAME=k3d-${ENV_NAME}-serverlb
    echo "K8S_CONTAINER_NAME=${K8S_CONTAINER_NAME}" >> ${K8S_ENV_FILE_PATH}

    # 設定 DOCKER_NETWORK
    export DOCKER_NETWORK="kde-${ENV_NAME}"
    echo "DOCKER_NETWORK=${DOCKER_NETWORK}" >> ${K8S_ENV_FILE_PATH}

    # 設定 STORAGE_CLASS
    export STORAGE_CLASS=local-path
    echo "STORAGE_CLASS=${STORAGE_CLASS}" >> ${K8S_ENV_FILE_PATH}
}

_backend_env_init() {
    # 如果 ${ENV_PATH}/k3d-config.template.yaml 存在，則使用 ${ENV_PATH}/k3d-config.template.yaml 設定 k3d-config.yaml
    # 否則使用預設的 k3d-config.yaml 模板 ${KDE_SCRIPTS_PATH}/utils/environment/k3d-config.yaml 設定 k3d-config.yaml
    if [[ -f ${ENV_PATH}/k3d-config.template.yaml ]]; then
        CONFIG_TEMPLATE_PATH=${ENV_PATH}/k3d-config.template.yaml
        echo "使用自訂模板: ${CONFIG_TEMPLATE_PATH}"
    else
        CONFIG_TEMPLATE_PATH=${KDE_SCRIPTS_PATH}/utils/environment/k3d-config.yaml
        echo "使用預設模板: ${CONFIG_TEMPLATE_PATH}"
    fi

    # 設定 k3d-config.yaml
    envsubst < ${CONFIG_TEMPLATE_PATH} > ${ENV_PATH}/k3d-config.yaml
}

_backend_env_start() {
    # 避免環境資料夾位置發生變動的防禦性機制
    # 如果 VOLUMES_PATH 不等于 ENV_PATH/${VOLUMES_DIR}，則重新初始化 k3d-config.yaml
    if [[ ${VOLUMES_PATH} != ${ENV_PATH}/${VOLUMES_DIR} ]]; then
        _backend_env_init
    fi

    # Ensure Docker network
    if [ -z "$( docker network ls | awk '{print $2}' | grep ^$DOCKER_NETWORK$ )" ]; then
        docker network create $DOCKER_NETWORK
    fi

    # Install K3S
    docker run \
    --rm \
    -it \
    --net $DOCKER_NETWORK \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v ${ENV_PATH}/${KUBE_CONFIG_DIR}:/root/.kube \
    -v ${ENV_PATH}/k3d-config.yaml:/config.yaml \
    ${K3D_IMAGE} \
    sh -c "k3d cluster create --config=/config.yaml && sed "s/0.0.0.0:[0-9]*/$K8S_CONTAINER_NAME:6443/ig" /root/.kube/config > /root/.kube/config.new && mv /root/.kube/config.new /root/.kube/config && chown $(id -u):$(id -g) /root/.kube/config"

    if [ $? -ne 0 ]; then
        echo "k3d 初始化失敗"
        exit 1
    fi

    script=$(< ${KDE_SCRIPTS_PATH}/utils/environment/k3d-install-default-services.sh)
    exec_script_in_deploy_env "${script}"

    if [[ -f ${ENV_PATH}/init.sh ]]; then
        script=$(< ${ENV_PATH}/init.sh)
        exec_script_in_deploy_env "${script}"
    fi

    echo "k3d 初始化已完成"
}

_backend_env_stop() {
    # 如果 enviroments 底下不存在 $1 環境，則退出
    exit_if_env_not_exist ${ENV_NAME}
    load_enviroment_env ${ENV_NAME}
    exit_if_env_not_running ${ENV_NAME}
    containers=$(_backend_get_k3d_containers ${ENV_NAME})
    if [[ "$1" == "-f" || "$1" == "--force" ]]; then
        echo "強制刪除 k8s 容器: ${containers}"
        docker rm -f ${containers}
    else
        echo "停止 k8s 容器: ${containers}"
        docker stop ${containers}
        echo "刪除 k8s 容器: ${containers}"
        docker rm ${containers}
    fi
}

_backend_env_delete() {
    _backend_env_stop
}

_backend_env_status() {
    local container_status
    container_status=$(docker inspect -f '{{.State.Running}}' "${K8S_CONTAINER_NAME}" 2>/dev/null)
    if [[ "$container_status" == "true" ]]; then
        echo "running"
    else
        echo "stopped"
    fi
}

_backend_env_exec_node() {
    docker exec -it ${K8S_CONTAINER_NAME} bash
}

_backend_env_load_image() {
    IMAGE=$1
    ENV_NAME=$2

    docker run \
    --rm \
    -it \
    --net $DOCKER_NETWORK \
    -e KIND_EXPERIMENTAL_DOCKER_NETWORK=${DOCKER_NETWORK} \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v ${ENV_PATH}/${KUBE_CONFIG_DIR}:/root/.kube \
    -v ${ENV_PATH}/k3d-config.yaml:/config.yaml \
    ${K3D_IMAGE} \
    sh -c "k3d image import ${IMAGE} -c ${ENV_NAME}"
}

# K3D-specific helper functions

_backend_is_k3d_init() {
    ENV_NAME=$1
    if [[ -f ${ENVIROMENTS_PATH}/${ENV_NAME}/k3d-config.yaml ]]; then
        echo "true"
    else
        echo "false"
    fi
}

_backend_get_k3d_containers() {
    ENV_NAME=$1
    echo $(docker ps --format "{{.Names}}" --filter "name=^k3d-${ENV_NAME}-server*")
}
