#!/bin/bash

get_local_ip() {
  # 1. hostname -I
  if command -v hostname >/dev/null 2>&1 && hostname -I >/dev/null 2>&1; then
    echo "$(hostname -I | awk '{print $1}')"
    return
  fi

  # 2. ip addr
  if command -v ip >/dev/null 2>&1; then
    local ipaddr
    ipaddr=$(ip -4 addr show scope global \
              | grep -oP '(?<=inet\s)\d+(\.\d+){3}' \
              | head -n1)
    [ -n "$ipaddr" ] && { echo "$ipaddr"; return; }
  fi

  # 3. ip route
  if command -v ip >/dev/null 2>&1; then
    local ipaddr
    ipaddr=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {print $7}')
    [ -n "$ipaddr" ] && { echo "$ipaddr"; return; }
  fi

  # 4. ifconfig
  if command -v ifconfig >/dev/null 2>&1; then
    local iface
    iface=$(ifconfig -l 2>/dev/null | awk '{print $1}')  # 取第一張非迴圈網卡
    if [ -n "$iface" ]; then
      local ipaddr
      ipaddr=$(ifconfig "$iface" | awk '/inet /{print $2}')
      [ -n "$ipaddr" ] && { echo "$ipaddr"; return; }
    fi
  fi

  # 5. macOS ipconfig
  if command -v ipconfig >/dev/null 2>&1; then
    echo "$(ipconfig getifaddr en0 2>/dev/null)"
    return
  fi

  echo "無法偵測到本機 IP" >&2
  return 1
}

open_browser() {
  local url="$1"
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url"
  elif command -v open >/dev/null 2>&1; then
    open "$url"
  elif command -v explorer.exe >/dev/null 2>&1; then
    explorer.exe "$url"
  else
    echo "請開啟瀏覽器並前往 http://$(get_local_ip):${PORT}" >&2
  fi
}

start_headlamp() {
    PORT=${1:-4466}
    BACKGROUND=${2:-false}
    KUBECONFIG=${ENV_PATH}/${KUBE_CONFIG_DIR}/config
    
    local LOCAL_IP=$(get_local_ip)
    local URL="http://${LOCAL_IP}:${PORT}"
    
    if [[ "${BACKGROUND}" == "true" ]]; then
        # 背景執行模式
        echo "正在背景啟動 Headlamp..."
        docker run --rm -d \
          --name headlamp-${CUR_ENV} \
          -p ${PORT}:4466 \
          -v ${KUBECONFIG}:/home/headlamp/.kube/config \
          --network ${DOCKER_NETWORK} \
          ghcr.io/headlamp-k8s/headlamp:latest /headlamp/headlamp-server -html-static-dir /headlamp/frontend -plugins-dir=/headlamp/plugins
        
        echo "✓ Headlamp 已在背景啟動"
        echo "存取網址: ${URL}"
        echo "停止服務: docker stop headlamp-${CUR_ENV}"
    else
        # 前景執行模式
        open_browser "${URL}"
        
        docker run --rm -it \
          --name headlamp-${CUR_ENV} \
          -p ${PORT}:4466 \
          -v ${KUBECONFIG}:/home/headlamp/.kube/config \
          --network ${DOCKER_NETWORK} \
          ghcr.io/headlamp-k8s/headlamp:latest /headlamp/headlamp-server -html-static-dir /headlamp/frontend -plugins-dir=/headlamp/plugins
    fi
}
