#!/bin/bash

cloudflare_login() {
    if [ ! -d ${KDE_PATH}/cloudflared ]; then
        mkdir -p ${KDE_PATH}/cloudflared
        touch ${KDE_PATH}/cloudflared/cert.pem
        chmod -R 777 ${KDE_PATH}/cloudflared
        docker run -it --rm \
            --name cloudflared \
            -v ${KDE_PATH}/cloudflared:/home/nonroot/.cloudflared \
            ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
            "cloudflared --no-autoupdate login"
        chmod -R 755 ${KDE_PATH}/cloudflared/cert.pem
    else
        echo "Cloudflare login already exists"
    fi

}

cloudflare_set_dns() {
    DOMAIN=$1
    TUNNEL_ID=$2

    echo "Setting DNS for ${DOMAIN} with tunnel ID ${TUNNEL_ID}"
    # 設定 cloudflare DNS 紀錄
    docker run -it --rm \
        --name cloudflared \
        -e TUNNEL_ORIGIN_CERT=/etc/cloudflared/cert.pem \
        -v ${KDE_PATH}/cloudflared:/etc/cloudflared \
        ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
        "cloudflared --no-autoupdate tunnel route dns --overwrite-dns ${DOMAIN} ${DOMAIN}"
    echo "DNS for ${DOMAIN} with tunnel ID ${TUNNEL_ID} set"
}

cloudflare_get_tunnel_id() {
    DOMAIN=$1

    TUNNEL_ID=$(docker run -it --rm \
        -e TUNNEL_ORIGIN_CERT=/etc/cloudflared/cert.pem \
        -v ${KDE_PATH}/cloudflared:/etc/cloudflared \
        ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
        "cloudflared --no-autoupdate tunnel list -n ${DOMAIN}" | grep ${DOMAIN} | awk '{print $1}')
    echo ${TUNNEL_ID}
}

cloudflare_create_tunnel() {
    DOMAIN=$1
    FILE_NAME=${DOMAIN/\*/all}
    TARGET_URL=$2
    
    # 如果 tunnel 存在，則刪除
    if [[ -n $(cloudflare_get_tunnel_id ${DOMAIN}) ]]; then
        cloudflare_delete_tunnel ${DOMAIN}
    fi

    docker run -it --rm \
        --user $UID \
        --name cloudflared \
        -e TUNNEL_ORIGIN_CERT=/etc/cloudflared/cert.pem \
        -e TUNNEL_CRED_FILE=/etc/cloudflared/${FILE_NAME}.json \
        -v ${KDE_PATH}/cloudflared:/etc/cloudflared \
        ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
       "cloudflared --no-autoupdate tunnel create ${DOMAIN}"

    chmod 755 ${KDE_PATH}/cloudflared/${FILE_NAME}.json

    # 取得 tunnel id
    TUNNEL_ID=$(cloudflare_get_tunnel_id ${DOMAIN})
    echo "Tunnel ID: ${TUNNEL_ID}"

    # 設定 cloudflare DNS 紀錄
    cloudflare_set_dns ${DOMAIN} ${TUNNEL_ID}

    echo "Creating config for tunnel ${DOMAIN} and target URL ${TARGET_URL}"
    cat > ${KDE_PATH}/cloudflared/${FILE_NAME}.yml << EOF
tunnel: "${DOMAIN}"
credentials-file: /etc/cloudflared/${FILE_NAME}.json
ingress:
  - hostname: "${DOMAIN}"
    service: ${TARGET_URL}
  - service: http_status:404
EOF
}

cloudflare_start_tunnel() {
    DOMAIN=$1
    FILE_NAME=${DOMAIN/\*/all}
    DOCKER_NETWORK=$2

    echo "Starting tunnel ${DOMAIN}"
    docker run -it --rm \
        --name cloudflared-tunnel-${DOMAIN/\*/all} \
        --network ${DOCKER_NETWORK} \
        -v ${KDE_PATH}/cloudflared:/etc/cloudflared \
        ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
        "cloudflared --no-autoupdate tunnel --config /etc/cloudflared/${FILE_NAME}.yml run ${DOMAIN}"
    echo "Tunnel ${DOMAIN} stopped"
}

cloudflare_stop_tunnel() {
    DOMAIN=$1

    docker stop cloudflared-tunnel-${DOMAIN}
    docker rm cloudflared-tunnel-${DOMAIN}
}

cloudflare_delete_tunnel() {
    DOMAIN=$1
    FILE_NAME=${DOMAIN/\*/all}
    
    echo "Deleting tunnel ${DOMAIN}"
    rm -f ${KDE_PATH}/cloudflared/${FILE_NAME}.json
    rm -f ${KDE_PATH}/cloudflared/${FILE_NAME}.yml
    docker run -it --rm \
        --name cloudflared \
        -e TUNNEL_ORIGIN_CERT=/etc/cloudflared/cert.pem \
        -v ${KDE_PATH}/cloudflared:/etc/cloudflared \
        ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
        "cloudflared --no-autoupdate tunnel delete ${DOMAIN}"
    echo "Tunnel ${DOMAIN} deleted"
}

cloudflare_tunnel_url() {
    DOMAIN=$1
    TARGET_URL=$2
    DOCKER_NETWORK=${3:-host}

    cloudflare_login
    cloudflare_create_tunnel ${DOMAIN} ${TARGET_URL}
    cloudflare_start_tunnel ${DOMAIN} ${DOCKER_NETWORK}
}

cloudflare_tunnel_service() {
    DOMAIN=$1
    NAMESPACE=$2
    SERVICE=$3
    PORT=$4
    FILE_NAME=${DOMAIN/\*/all}

    SCRIPT="(kubectl -n ${NAMESPACE} port-forward --address 0.0.0.0 svc/${SERVICE} 80:${PORT} &) && cloudflared --no-autoupdate tunnel --config /etc/cloudflared/${FILE_NAME}.yml run ${DOMAIN}"
    
    cloudflare_login
    cloudflare_create_tunnel ${DOMAIN} http://${SERVICE}
    docker run -it --rm \
        --name cloudflared-tunnel-${DOMAIN/\*/all} \
        --network ${DOCKER_NETWORK} \
        --add-host ${SERVICE}:127.0.0.1 \
        -v ${KUBECONFIG}:/home/nonroot/.kube/config \
        -v ${KDE_PATH}/cloudflared:/etc/cloudflared \
        ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
        "${SCRIPT}"
}

cloudflare_tunnel_pod() {
    DOMAIN=$1
    NAMESPACE=$2
    POD=$3
    PORT=$4
    FILE_NAME=${DOMAIN/\*/all}

    SCRIPT="(kubectl -n ${NAMESPACE} port-forward --address 0.0.0.0 pod/${POD} 80:${PORT} &) && cloudflared --no-autoupdate tunnel --config /etc/cloudflared/${FILE_NAME}.yml run ${DOMAIN}"
    echo "DOMAIN: ${DOMAIN}"
    echo "NAMESPACE: ${NAMESPACE}"
    echo "POD: ${POD}"
    echo "PORT: ${PORT}"
    echo "FILE_NAME: ${FILE_NAME}"
    echo "SCRIPT: ${SCRIPT}"
    cloudflare_login
    cloudflare_create_tunnel ${DOMAIN} http://${POD}.${NAMESPACE}
    docker run -it --rm \
        --name cloudflared-tunnel-${DOMAIN/\*/all} \
        --network ${DOCKER_NETWORK} \
        --add-host ${POD}.${NAMESPACE}:127.0.0.1 \
        -v ${KUBECONFIG}:/home/nonroot/.kube/config \
        -v ${KDE_PATH}/cloudflared:/etc/cloudflared \
        ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
        "${SCRIPT}"
}
