#!/bin/bash

# 通用 JSON 欄位讀取函數
get_json_value() {
    local json_file="$1"
    local key="$2"
    
    # 使用 grep 和 sed 提取值
    grep -o "\"${key}\"[^,}]*" "$json_file" | \
    sed -E 's/.*"[^"]*"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/'
}

cloudflare_login() {
    if [[ ! -d ${KDE_PATH}/.cloudflared || ! -f ${KDE_PATH}/.cloudflared/cert.pem ]]; then
        mkdir -p ${KDE_PATH}/.cloudflared
        touch ${KDE_PATH}/.cloudflared/cert.pem
        chmod -R 777 ${KDE_PATH}/.cloudflared
        docker run -it --rm \
            --name cloudflared \
            -v ${KDE_PATH}/.cloudflared:/home/nonroot/.cloudflared \
            ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
            "cloudflared --no-autoupdate login"
        chmod -R 755 ${KDE_PATH}/.cloudflared/cert.pem
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
        -v ${KDE_PATH}/.cloudflared:/etc/cloudflared \
        ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
        "cloudflared --no-autoupdate tunnel route dns --overwrite-dns ${DOMAIN} ${DOMAIN}"
    echo "DNS for ${DOMAIN} with tunnel ID ${TUNNEL_ID} set"
}

cloudflare_get_tunnel_id() {
    DOMAIN=$1

    TUNNEL_ID=$(docker run -it --rm \
        -e TUNNEL_ORIGIN_CERT=/etc/cloudflared/cert.pem \
        -v ${KDE_PATH}/.cloudflared:/etc/cloudflared \
        ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
        "cloudflared --no-autoupdate tunnel list -n ${DOMAIN}" | grep ${DOMAIN} | awk '{print $1}')
    echo ${TUNNEL_ID}
}

cloudflare_get_tunnel_id_from_json() {
    DOMAIN=$1

    # 從 .cloudflared 底下檢查是否有 ${DOMAIN}.json 檔案，如果有則回傳 JSON 檔案中的 TunnelID 的值，否則回傳空字串
    if [[ -f ${KDE_PATH}/.cloudflared/${DOMAIN}.json ]]; then
        TUNNEL_ID=$(get_json_value ${KDE_PATH}/.cloudflared/${DOMAIN}.json "TunnelID")
    else
        TUNNEL_ID=""
    fi
    echo ${TUNNEL_ID}
}

cloudflare_is_tunnel_exist() {
    DOMAIN=$1

    if [[ -n $(cloudflare_get_tunnel_id ${DOMAIN}) ]]; then
        return 0
    fi
}

cloudflare_create_tunnel() {
    DOMAIN=$1
    FILE_NAME=${DOMAIN/\*/all}
    TARGET_URL=$2
    
    cloudflare_delete_tunnel ${DOMAIN}

    docker run -it --rm \
        --user $UID \
        --name cloudflared \
        -e TUNNEL_ORIGIN_CERT=/etc/cloudflared/cert.pem \
        -e TUNNEL_CRED_FILE=/etc/cloudflared/${FILE_NAME}.json \
        -v ${KDE_PATH}/.cloudflared:/etc/cloudflared \
        ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
       "cloudflared --no-autoupdate tunnel create ${DOMAIN}"

    chmod 755 ${KDE_PATH}/.cloudflared/${FILE_NAME}.json

    # 取得 tunnel id
    TUNNEL_ID=$(cloudflare_get_tunnel_id_from_json ${DOMAIN})
    echo "Tunnel ID: ${TUNNEL_ID}"

    # 設定 cloudflare DNS 紀錄
    cloudflare_set_dns ${DOMAIN} ${TUNNEL_ID}

    echo "Creating config for tunnel ${DOMAIN} and target URL ${TARGET_URL}"
    cat > ${KDE_PATH}/.cloudflared/${FILE_NAME}.yml << EOF
tunnel: "${DOMAIN}"
credentials-file: /etc/cloudflared/${FILE_NAME}.json
ingress:
  - hostname: "${DOMAIN}"
    service: ${TARGET_URL}
  - service: http_status:404
EOF
}

cloudflare_stop_tunnel() {
    DOMAIN=$1

    docker stop cloudflared-tunnel-${DOMAIN}
    docker rm cloudflared-tunnel-${DOMAIN}
}

cloudflare_delete_tunnel() {
    DOMAIN=$1
    TUNNEL_ID=$(cloudflare_get_tunnel_id_from_json ${DOMAIN})
    FILE_NAME=${DOMAIN/\*/all}
    
    rm -f ${KDE_PATH}/.cloudflared/${FILE_NAME}.json && echo "Delete file: ${KDE_PATH}/.cloudflared/${FILE_NAME}.json"
    rm -f ${KDE_PATH}/.cloudflared/${FILE_NAME}.yml && echo "Delete file: ${KDE_PATH}/.cloudflared/${FILE_NAME}.yml"

    # 如果 tunnel id 存在，則刪除 tunnel
    if [[ -n "${TUNNEL_ID}" ]]; then
        echo "Deleting tunnel ${DOMAIN} with tunnel ID ${TUNNEL_ID}"
        docker run -it --rm \
            --name cloudflared \
            -e TUNNEL_ORIGIN_CERT=/etc/cloudflared/cert.pem \
            -v ${KDE_PATH}/.cloudflared:/etc/cloudflared \
            ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
            "cloudflared --no-autoupdate tunnel delete ${TUNNEL_ID}"
        echo "Tunnel ${DOMAIN} deleted"
    fi
}

cloudflare_start_tunnel() {
    DOMAIN=$1
    FILE_NAME=${DOMAIN/\*/all}
    DOCKER_NETWORK=$2

    echo "Starting tunnel ${DOMAIN}"
    docker run -it --rm \
        --name cloudflared-tunnel-${FILE_NAME} \
        --network ${DOCKER_NETWORK} \
        -v ${KDE_PATH}/.cloudflared:/etc/cloudflared \
        ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
        "cloudflared --no-autoupdate tunnel --config /etc/cloudflared/${FILE_NAME}.yml run ${DOMAIN}"
    echo "Tunnel ${DOMAIN} stopped"
}


cloudflare_tunnel_url() {
    DOMAIN=$1
    TARGET_URL=$2
    DOCKER_NETWORK=$3

    cloudflare_login
    cloudflare_create_tunnel ${DOMAIN} ${TARGET_URL}
    cloudflare_start_tunnel ${DOMAIN} ${DOCKER_NETWORK}
}

cloudflare_quick_tunnel_url() {
    TARGET_URL=$1
    DOCKER_NETWORK=${2:-host}

    SCRIPT="cloudflared --no-autoupdate tunnel --url ${TARGET_URL}"

    echo "Starting tunnel forwarding for ${TARGET_URL} on docker network ${DOCKER_NETWORK}"
    docker run -it --rm \
        --network ${DOCKER_NETWORK} \
        ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
        "${SCRIPT}"
    echo "Tunnel forwarding for ${TARGET_URL} stopped"
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
        -v ${KDE_PATH}/.cloudflared:/etc/cloudflared \
        ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
        "${SCRIPT}"
}

cloudflare_quick_tunnel_service() {
    NAMESPACE=$1
    SERVICE=$2
    PORT=$3
    TARGET_URL=http://${SERVICE}:${PORT}

    # 使用 port-forward 轉發 port 到本地端 80 port，並且使用 cloudflared 建立 tunnel 並且轉發到 TARGET_URL
    SCRIPT="(kubectl -n ${NAMESPACE} port-forward --address 0.0.0.0 svc/${SERVICE} 80:${PORT} &) && cloudflared --no-autoupdate tunnel --url ${TARGET_URL}"
    
    echo "Starting tunnel forwarding for ${TARGET_URL} on docker network ${DOCKER_NETWORK}"
    docker run -it --rm \
        --network ${DOCKER_NETWORK} \
        --add-host ${SERVICE}:127.0.0.1 \
        -v ${KUBECONFIG}:/home/nonroot/.kube/config \
        ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
        "${SCRIPT}"
    echo "Tunnel forwarding for ${TARGET_URL} stopped"
}

cloudflare_tunnel_pod() {
    DOMAIN=$1
    NAMESPACE=$2
    POD=$3
    PORT=$4
    FILE_NAME=${DOMAIN/\*/all}

    SCRIPT="(kubectl -n ${NAMESPACE} port-forward --address 0.0.0.0 pod/${POD} 80:${PORT} &) && cloudflared --no-autoupdate tunnel --config /etc/cloudflared/${FILE_NAME}.yml run ${DOMAIN}"

    cloudflare_login
    cloudflare_create_tunnel ${DOMAIN} http://${POD}.${NAMESPACE}
    docker run -it --rm \
        --name cloudflared-tunnel-${DOMAIN/\*/all} \
        --network ${DOCKER_NETWORK} \
        --add-host ${POD}.${NAMESPACE}:127.0.0.1 \
        -v ${KUBECONFIG}:/home/nonroot/.kube/config \
        -v ${KDE_PATH}/.cloudflared:/etc/cloudflared \
        ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
        "${SCRIPT}"
}

cloudflare_quick_tunnel_pod() {
    NAMESPACE=$1
    POD=$2
    PORT=$3
    TARGET_URL=http://${POD}.${NAMESPACE}

    # 使用 port-forward 轉發 port 到本地端 80 port，並且使用 cloudflared 建立 tunnel 並且轉發到 TARGET_URL
    SCRIPT="(kubectl -n ${NAMESPACE} port-forward --address 0.0.0.0 pod/${POD} 80:${PORT} &) && cloudflared --no-autoupdate tunnel --url ${TARGET_URL}"

    echo "Starting tunnel forwarding for ${TARGET_URL} on docker network ${DOCKER_NETWORK}"
    docker run -it --rm \
        --network ${DOCKER_NETWORK} \
        --add-host ${POD}.${NAMESPACE}:127.0.0.1 \
        -v ${KUBECONFIG}:/home/nonroot/.kube/config \
        ${CLOUDFLARE_TUNNEL_PROXY_IMAGE} \
        "${SCRIPT}"

    echo "Tunnel forwarding for ${TARGET_URL} stopped"
}
