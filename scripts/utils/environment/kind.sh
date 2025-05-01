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

init_kind() {
    # 設定 K8S container 名稱
    export K8S_CONTAINER_NAME=${ENV_NAME}-control-plane
    echo "K8S_CONTAINER_NAME=${K8S_CONTAINER_NAME}" >> ${K8S_ENV_FILE_PATH}

    # 設定 DOCKER_NETWORK
    export DOCKER_NETWORK="kde-${ENV_NAME}"
    echo "DOCKER_NETWORK=${DOCKER_NETWORK}" >> ${K8S_ENV_FILE_PATH}

    # 設定 STORAGE_CLASS
    STORAGE_CLASS=local-path
    echo "STORAGE_CLASS=${STORAGE_CLASS}" >> ${K8S_ENV_FILE_PATH}
    
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

    touch ${KUBECONFIG}

    init_kind_config
}

init_kind_config() {
    # 輸入 K8S_API_SERVER_PORT
    if [[ -z "${K8S_API_SERVER_PORT}" ]]; then
        read -p "請輸入 K8S api server port (預設: 6443): " K8S_API_SERVER_PORT
        export K8S_API_SERVER_PORT=${K8S_API_SERVER_PORT:-6443}
        echo "K8S_API_SERVER_PORT=${K8S_API_SERVER_PORT}" >> ${LOCAL_ENV_FILE_PATH}
    fi

    # 輸入 K8S_INGRESS_NGINX_PORT
    if [[ -z "${K8S_INGRESS_NGINX_PORT}" ]]; then
        read -p "請輸入 K8S ingress nginx port (預設: 80): " K8S_INGRESS_NGINX_PORT
        export K8S_INGRESS_NGINX_PORT=${K8S_INGRESS_NGINX_PORT:-80}
        echo "K8S_INGRESS_NGINX_PORT=${K8S_INGRESS_NGINX_PORT}" >> ${LOCAL_ENV_FILE_PATH}
    fi

    # 設定 VOLUMES_PATH
    echo "VOLUMES_PATH=${ENV_PATH}/${VOLUMES_DIR}" > ${LOCAL_ENV_FILE_PATH}

    # 設定 kind-config.yaml
    envsubst < ${KDE_SCRIPTS_PATH}/utils/environment/kind-config.yaml > ${ENV_PATH}/kind-config.yaml
}

start_kind() {
    exit_if_env_running ${ENV_NAME}
    
    if [[ $(is_kind_init ${ENV_NAME}) == "false" ]]; then
        init_kind
    fi

    if [[ ${VOLUMES_PATH} != ${ENV_PATH}/${VOLUMES_DIR} ]]; then
        init_kind_config
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
    r82wei/kind:v0.27.0 \
    sh -c "kind create cluster --config=/config.yaml && sed "s/0.0.0.0:[0-9]*/$K8S_CONTAINER_NAME:6443/ig" ~/.kube/config > ~/.kube/config.new && mv ~/.kube/config.new ~/.kube/config && chown $(id -u):$(id -g) ~/.kube/config"

    if [ $? -ne 0 ]; then
        echo "kind 初始化失敗"
        exit 1
    fi

    script=$(< ${KDE_SCRIPTS_PATH}/utils/environment/kind-install-default-services.sh)
    exec_script_in_deploy_env "${script}"
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
    r82wei/kind:v0.27.0 \
    sh -c "kind load docker-image ${IMAGE} --name ${ENV_NAME}"
}
