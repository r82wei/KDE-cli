#!/bin/bash

###### Init K3S ######
# 檢查同名 K3S 叢集是否存在
if [[ $(is_env_running ${K8S_CONTAINER_NAME}) == "true" ]]; then
    echo "K3S named '${K8S_CONTAINER_NAME}' exists."
else
    echo "K3S named '${K8S_CONTAINER_NAME}' not exists."
    if [[ $(is_k3d_init ${ENV_NAME}) == "false" || ${VOLUMES_PATH} != ${ENV_PATH}/${VOLUMES_DIR} ]]; then
        envsubst < ${KDE_SCRIPTS_PATH}/start/k3d/k3d-config.yaml > ${ENV_PATH}/k3d-config.yaml
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
    docker.anyong.com.tw/quick-start/k3d:v5.8.3 \
    sh -c "k3d cluster create --config=/config.yaml && sed "s/0.0.0.0:[0-9]*/$K8S_CONTAINER_NAME:6443/ig" /root/.kube/config > /root/.kube/config.new && mv /root/.kube/config.new /root/.kube/config && chown $(id -u):$(id -g) /root/.kube/config"

    if [ $? -ne 0 ]; then
        echo "K3S 初始化失敗"
        exit 1
    fi

    script=$(< ${KDE_SCRIPTS_PATH}/start/k3d/install-default-services.sh)
    exec_script_in_deploy_env "${script}"
    echo "K8S 初始化已完成"

fi
###### Init K3S ######
