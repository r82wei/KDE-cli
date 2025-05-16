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

start_dashboard() {
    PORT=${1:-8443}
    ENABLE_SSL=${2:-true}
    KUBECONFIG=${ENV_PATH}/${KUBE_CONFIG_DIR}/config

    echo "PORT: ${PORT}"
    HTTP_PROTO="https"
    ARGS="--metric-client-check-period=99999"
    if [[ "${ENABLE_SSL}" == "true" ]]; then
        DASHBOARD_SERVER_PORT=8443
        ARGS+=" --auto-generate-certificates "
    else
        DASHBOARD_SERVER_PORT=9090
        HTTP_PROTO="http"
    fi

    echo "ARGS: ${ARGS}"
    open_browser "${HTTP_PROTO}://$(get_local_ip):${PORT}"
    docker run --rm -it \
        --net ${DOCKER_NETWORK} \
        -p ${PORT}:${DASHBOARD_SERVER_PORT} \
        -v ${KUBECONFIG}:/.kube/config:ro \
        -e KUBECONFIG=/.kube/config \
        ${K8S_UI_DASHBOARD_IMAGE:-kubernetesui/dashboard:v2.7.0} \
        --kubeconfig /.kube/config ${ARGS} 
        
}
