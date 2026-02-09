#!/bin/bash

# 列出指定 namespace 的 Pod
list_pods() {
    NAMESPACE=$1
    
    echo "Namespace: ${NAMESPACE}"
    echo ""
    
    # 根據環境類型選擇執行方式
    if [[ "${ENV_TYPE}" == "kind" ]] || [[ "${ENV_TYPE}" == "k3d" ]]; then
        # 透過 K8s 容器執行 kubectl
        docker exec ${K8S_CONTAINER_NAME} kubectl get pods -n ${NAMESPACE} --no-headers -o custom-columns="NAME:.metadata.name,READY:.status.containerStatuses[*].ready,STATUS:.status.phase,IP:.status.podIP"
    else
        # 外部 K8s，直接使用 kubectl
        kubectl get pods -n ${NAMESPACE} --no-headers -o custom-columns="NAME:.metadata.name,READY:.status.containerStatuses[*].ready,STATUS:.status.phase,IP:.status.podIP"
    fi
}

# 選擇 Pod（互動式）
select_pod() {
    NAMESPACE=$1

    # 根據環境類型選擇執行方式，列出所有 Running 狀態的 Pod
    if [[ "${ENV_TYPE}" == "kind" ]] || [[ "${ENV_TYPE}" == "k3d" ]]; then
        # 透過 K8s 容器執行 kubectl
        pods=($(docker exec ${K8S_CONTAINER_NAME} kubectl get pods -n ${NAMESPACE} --field-selector=status.phase=Running --no-headers -o custom-columns=":metadata.name" 2>/dev/null | xargs))
    else
        # 外部 K8s，直接使用 kubectl
        pods=($(kubectl get pods -n ${NAMESPACE} --field-selector=status.phase=Running --no-headers -o custom-columns=":metadata.name" 2>/dev/null | xargs))
    fi
    
    if [ ${#pods[@]} -eq 0 ]; then
        echo "Namespace ${NAMESPACE} 中沒有運行中的 Pod"
        exit 1
    fi
    
    PS3="請選擇一個目標 Pod（輸入編號）："
    select pod in "${pods[@]}" "退出"
    do
        case $pod in
            "退出")
                echo "退出"
                exit 0
                ;;
            "")
                echo "無效選擇，請重新輸入。"
                ;;
            *)
                echo "你選擇了目標 Pod: $pod"
                export POD=$pod
                break
                ;;
        esac
    done
}

# 停止所有 mirrord 容器
stop_all_mirrord_containers() {
    MIRRORD_CONTAINERS=$(docker ps -q -f name=kde-mirrord-)
    
    if [[ -z "${MIRRORD_CONTAINERS}" ]]; then
        echo "沒有找到任何執行中的 Mirrord 容器"
        exit 1
    fi
    
    echo "停止所有 Mirrord 容器..."
    docker ps -q -f name=kde-mirrord- | xargs docker stop
    echo "✅ 清理完成"
}

# 提示使用者輸入啟動命令
prompt_user_command() {
    echo ""
    echo "=========================================="
    echo "請輸入程式啟動命令"
    echo "=========================================="
    echo "範例："
    echo "  - Node.js: npm run dev"
    echo "  - Python: python app.py"
    echo "  - Go: go run main.go"
    echo "  - 自訂: ./start.sh"
    echo "  - 互動式 Shell: bash"
    echo "=========================================="
    echo ""
    read -p "啟動命令: " USER_COMMAND
    
    if [[ -z "${USER_COMMAND}" ]]; then
        echo "❌ 啟動命令不能為空"
        exit 1
    fi
    
    export USER_COMMAND
}

# 組合 docker run 命令（用於 mirrord container）
build_mirrord_docker_command() {
    PROJECT_NAME=$1
    USER_COMMAND=$2
    
    PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    source ${PROJECT_PATH}/project.env
    REPO_NAME=$(git_repo_name ${GIT_REPO_URL})
    
    # 組合 docker run 命令
    DOCKER_CMD="docker run --rm -it \
        --user $UID:$(id -g) \
        --workdir /workspace/${REPO_NAME} \
        --network ${DOCKER_NETWORK} \
        -v ${PROJECT_PATH}:/workspace \
        ${DEVELOP_IMAGE} \
        bash -c 'cd ${REPO_NAME} && ${USER_COMMAND}'"
    
    export DOCKER_CMD
}

# 執行 mirrord container（前台執行）
run_mirrord_container() {
    NAMESPACE=$1
    POD=$2
    DOCKER_CMD=$3
    MODE=$4
    
    ENVIRONMENT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}
    
    echo ""
    echo "=========================================="
    echo "啟動 Mirrord"
    echo "=========================================="
    echo "目標 Pod: ${POD}"
    echo "Namespace: ${NAMESPACE}"
    echo "模式: ${MODE}"
    echo "=========================================="
    echo ""
    
    # 前台執行 mirrord container
    # 使用 --network host 以確保 mirrord 的 internal proxy sidecar 可以正常通信
    docker run --rm -it \
        --name kde-mirrord-${CUR_ENV}-${NAMESPACE}-$(date +%s) \
        --network ${DOCKER_NETWORK} \
        -e MIRRORD_TARGET_NAMESPACE=${NAMESPACE} \
        -e MIRRORD_TARGET_POD=${POD} \
        -e MIRRORD_MODE=${MODE} \
        -e CONTAINER_COMMAND="${DOCKER_CMD}" \
        -v ${KUBECONFIG}:/root/.kube/config:ro \
        -v /var/run/docker.sock:/var/run/docker.sock \
        ${KDE_MIRRORD_IMAGE:-r82wei/kde-mirrord:latest}
}
