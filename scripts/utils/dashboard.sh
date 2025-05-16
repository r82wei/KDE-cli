#!/bin/bash

open_browser() {
  local url="$1"
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url"
  elif command -v open >/dev/null 2>&1; then
    open "$url"
  elif command -v explorer.exe >/dev/null 2>&1; then
    explorer.exe "$url"
  else
    echo "請開啟瀏覽器並前往 http://localhost:${PORT}" >&2
  fi
}

start_dashboard() {
    PORT=${1:-9090}

    # echo "請使用瀏覽器開啟 http://localhost:${PORT}"
    open_browser "http://localhost:${PORT}"
    docker run --rm -it \
        --net ${DOCKER_NETWORK} \
        -p ${PORT}:9090 \
        -v ${KUBECONFIG}:/.kube/config:ro \
        -e KUBECONFIG=/.kube/config \
        ${K8S_UI_DASHBOARD_IMAGE:-kubernetesui/dashboard:v2.7.0} \
        --kubeconfig /.kube/config \
        --metric-client-check-period=99999
}
