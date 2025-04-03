#!/bin/bash

check_ngrok_token() {
    CUR_ENV=$1
    load_enviroment_env ${CUR_ENV}
    if [[ -z "${NGROK_TOKEN}" ]]; then
        read -p "請輸入 NGROK_TOKEN: " NGROK_TOKEN
        echo "NGROK_TOKEN=${NGROK_TOKEN}" >> ${ENVIROMENTS_PATH}/${CUR_ENV}/.env
    fi
}

if_ngrok_container_exist() {
    CUR_ENV=$1
    CONTAINER_NAME=kde-ngrok-${CUR_ENV}
    if docker ps -a | grep -q ${CONTAINER_NAME}; then
        echo "true"
    else
        echo "false"
    fi
}

ngrok_http_ingress() {
    CUR_ENV=$1

    check_ngrok_token ${CUR_ENV}
    # 啟動 ngrok
    docker run -it --rm -e NGROK_AUTHTOKEN=${NGROK_TOKEN} --network ${DOCKER_NETWORK} ngrok/ngrok:latest http http://${K8S_CONTAINER_NAME}:30080
}

ngrok_http_k8s_service() {
    CUR_ENV=$1
    NAMESPACE=$2
    SERVICE=$3
    PORT=$4

    check_ngrok_token ${CUR_ENV}
    SCRIPT="(kubectl -n ${NAMESPACE} port-forward --address 0.0.0.0 svc/${SERVICE} 80:${PORT} &) && ngrok http 80"
    echo "${SCRIPT}"

    # 啟動 ngrok
    docker run -it --rm \
    --network ${DOCKER_NETWORK} \
    -e NGROK_AUTHTOKEN=${NGROK_TOKEN} \
    -v ${KUBECONFIG}:/root/.kube/config \
    r82wei/ngrok-proxy:1.0.0 \
    sh -c "${SCRIPT}"
}

ngrok_http_k8s_pod() {
    CUR_ENV=$1
    NAMESPACE=$2
    POD=$3
    PORT=$4

    check_ngrok_token ${CUR_ENV}
    SCRIPT="(kubectl -n ${NAMESPACE} port-forward --address 0.0.0.0 pod/${POD} 80:${PORT} &) && ngrok http 80"
    echo "${SCRIPT}"

    # 啟動 ngrok
    docker run -it --rm \
    --network ${DOCKER_NETWORK} \
    -e NGROK_AUTHTOKEN=${NGROK_TOKEN} \
    -v ${KUBECONFIG}:/root/.kube/config \
    r82wei/ngrok-proxy:1.0.0 \
    sh -c "${SCRIPT}"
}
