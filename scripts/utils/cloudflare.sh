#!/bin/bash

cloudflare_login() {
    if [ ! -d ${KDE_PATH}/cloudflared ]; then
        mkdir -p ${KDE_PATH}/cloudflared
        touch ${KDE_PATH}/cloudflared/cert.pem
        chmod -R 777 ${KDE_PATH}/cloudflared
        docker run -it --rm \
            --name cloudflared \
            -v ${KDE_PATH}/cloudflared:/home/nonroot/.cloudflared \
            cloudflare/cloudflared:latest \
            login
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
        -e TUNNEL_CRED_FILE=/etc/cloudflared/${DOMAIN}.json \
        -v ${KDE_PATH}/cloudflared:/etc/cloudflared \
        cloudflare/cloudflared:latest \
        tunnel route dns --overwrite-dns ${DOMAIN} ${DOMAIN}
    echo "DNS for ${DOMAIN} with tunnel ID ${TUNNEL_ID} set"
}

cloudflare_get_tunnel_id() {
    DOMAIN=$1

    TUNNEL_ID=$(docker run -it --rm \
        -e TUNNEL_ORIGIN_CERT=/etc/cloudflared/cert.pem \
        -v ${KDE_PATH}/cloudflared:/etc/cloudflared \
        cloudflare/cloudflared:latest \
        tunnel list | grep ${DOMAIN} | awk '{print $1}')
    echo ${TUNNEL_ID}
}

cloudflare_create_tunnel() {
    DOMAIN=$1
    TARGET_URL=$2
    
    # 如果 tunnel 存在，則刪除
    if [[ -n $(cloudflare_get_tunnel_id ${DOMAIN}) ]]; then
        cloudflare_delete_tunnel ${DOMAIN}
    fi

    docker run -it --rm \
        --user $UID \
        --name cloudflared \
        -e TUNNEL_ORIGIN_CERT=/etc/cloudflared/cert.pem \
        -e TUNNEL_CRED_FILE=/etc/cloudflared/${DOMAIN}.json \
        -v ${KDE_PATH}/cloudflared:/etc/cloudflared \
        cloudflare/cloudflared:latest \
        tunnel create ${DOMAIN}

    chmod 755 ${KDE_PATH}/cloudflared/${DOMAIN}.json

    # 取得 tunnel id
    TUNNEL_ID=$(cloudflare_get_tunnel_id ${DOMAIN})
    echo "Tunnel ID: ${TUNNEL_ID}"

    # 設定 cloudflare DNS 紀錄
    cloudflare_set_dns ${DOMAIN} ${TUNNEL_ID}

    echo "Creating config for tunnel ${DOMAIN} and target URL ${TARGET_URL}"
    cat > ${KDE_PATH}/cloudflared/${DOMAIN}.yml << EOF
tunnel: ${DOMAIN}
credentials-file: /etc/cloudflared/${DOMAIN}.json
ingress:
  - hostname: ${DOMAIN}
    service: ${TARGET_URL}
  - service: http_status:404
EOF
}


cloudflare_start_tunnel() {
    DOMAIN=$1
    DOCKER_NETWORK=$2

    echo "Starting tunnel ${DOMAIN}"
    docker run -it --rm \
        --name cloudflared-tunnel-${DOMAIN} \
        --network ${DOCKER_NETWORK} \
        -v ${KDE_PATH}/cloudflared:/etc/cloudflared \
        cloudflare/cloudflared:latest \
        tunnel --config /etc/cloudflared/${DOMAIN}.yml run ${DOMAIN}
    echo "Tunnel ${DOMAIN} stopped"
}

cloudflare_stop_tunnel() {
    DOMAIN=$1

    docker stop cloudflared-tunnel-${DOMAIN}
    docker rm cloudflared-tunnel-${DOMAIN}
}

cloudflare_delete_tunnel() {
    DOMAIN=$1
    
    echo "Deleting tunnel ${DOMAIN}"
    rm -f ${KDE_PATH}/cloudflared/${DOMAIN}.json
    rm -f ${KDE_PATH}/cloudflared/${DOMAIN}.yml
    docker run -it --rm \
        --name cloudflared \
        -e TUNNEL_ORIGIN_CERT=/etc/cloudflared/cert.pem \
        -v ${KDE_PATH}/cloudflared:/etc/cloudflared \
        cloudflare/cloudflared:latest \
        tunnel delete ${DOMAIN}
    echo "Tunnel ${DOMAIN} deleted"
}





