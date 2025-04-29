#!/bin/bash

###### Init K8S ######
# 檢查同名 K8S 叢集是否存在
if [[ $(is_env_running ${K8S_CONTAINER_NAME}) == "true" ]]; then
    echo "K8S named '${K8S_CONTAINER_NAME}' exists."
else
    if [[ $(is_kind_init ${ENV_NAME}) == "false" || ${VOLUMES_PATH} != ${ENV_PATH}/${VOLUMES_DIR} ]]; then
        envsubst < ${KDE_SCRIPTS_PATH}/start/kind/kind-config.yaml > ${ENV_PATH}/kind-config.yaml
    fi

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
    docker.anyong.com.tw/quick-start/kind:v0.27.0 \
    sh -c "kind create cluster --config=/config.yaml && sed "s/0.0.0.0:[0-9]*/$K8S_CONTAINER_NAME:6443/ig" ~/.kube/config > ~/.kube/config.new && mv ~/.kube/config.new ~/.kube/config && chown $(id -u):$(id -g) ~/.kube/config"

    if [ $? -ne 0 ]; then
        echo "kind 初始化失敗"
        exit 1
    fi

    script=$(< ${KDE_SCRIPTS_PATH}/start/kind/install-default-services.sh)
    exec_script_in_deploy_env "${script}"
    echo "K8S 初始化已完成"
fi
###### Init K8S ######
