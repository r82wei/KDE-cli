#!/bin/bash

is_any_container_use_telepresence_session_network() {
    NAMESPACE=$1
    
    TELEPRESENCE_DOCKER_NETWORK="container:$(docker ps -q --no-trunc -f name=kde-telepresence-session-${CUR_ENV}-${NAMESPACE})"
    if [[ -n "$(docker ps -aq | xargs docker inspect --format '{{.Id}} {{.HostConfig.NetworkMode}}' | grep ${TELEPRESENCE_DOCKER_NETWORK})" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

exit_if_not_telepresence_session_container() {
    NAMESPACE=$1

    if [[ -z "$(docker ps -q -f name=kde-telepresence-session-${CUR_ENV}-${NAMESPACE})" ]]; then
        echo "NAMESPACE: ${NAMESPACE} 的 telepresence session container 不存在"
        exit 1
    fi
}

exit_if_not_any_telepresence_session_container() {
    NAMESPACE=$1

    if [[ -z "$(docker ps -q -f name=kde-telepresence-session-)" ]]; then
        echo "沒有找到任何 Telepresence 的連線"
        exit 1
    fi
}

select_workload() {
    NAMESPACE=$1

    # 透過 telepresence list 列出所有可用的 workload
    workloads=($(docker exec -it kde-telepresence-session-${CUR_ENV}-${NAMESPACE} telepresence list | grep "ready" | awk '{print $2}' | xargs))
    # echo "workloads: ${workloads[@]}"
    PS3="請選擇一個目標服務 （輸入編號）："
    select workload in "${workloads[@]}" "退出"
    do
        case $workload in
            "退出")
                echo "退出"
                exit 0
                ;;
            "")
                echo "無效選擇，請重新輸入。"
                ;;
            *)
                echo "你選擇了目標服務: $workload"
                export WORKLOAD=$workload
                break
                ;;
        esac
    done
}

list_status() {
    NAMESPACE=$1

    exit_if_not_telepresence_session_container ${NAMESPACE}
    docker exec -it kde-telepresence-session-${CUR_ENV}-${NAMESPACE} telepresence list -igrt
}

create_telepresence_session_container() {
    NAMESPACE=$1
    ENVIRONMENT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}

    # Ensure Docker network
    if [ -z "$( docker network ls | awk '{print $2}' | grep ^$DOCKER_NETWORK$ )" ]; then
        docker network create $DOCKER_NETWORK
    fi

    # 如果 telepresence container 已經存在，則跳出函式
    if [[ -n "$(docker ps -q -f name=kde-telepresence-session-${CUR_ENV}-${NAMESPACE})" ]]; then
        echo "telepresence session container 已經存在"
        return
    fi
    
    # 啟動 telepresence container 並且透過 telepresence connect ${NAMESPACE} 連線
    docker run -d --rm \
    --name kde-telepresence-session-${CUR_ENV}-${NAMESPACE} \
    --cap-add NET_ADMIN \
    --device /dev/net/tun \
    --device /dev/fuse \
    --cap-add SYS_ADMIN \
    --security-opt apparmor:unconfined \
    --network ${DOCKER_NETWORK} \
    -e TELEPRESENCE_CONNECT_NAMESPACE=${NAMESPACE} \
    -e TELEPRESENCE_ALSO_PROXY_CIDR=${TELEPRESENCE_ALSO_PROXY_CIDR} \
    -v ${KUBECONFIG}:/root/.kube/config:ro \
    -v ${ENVIRONMENT_PATH}/.telepresence/mounts/local/${NAMESPACE}:${ENVIRONMENT_PATH}/.telepresence/mounts/local/${NAMESPACE} \
    -v ${ENVIRONMENT_PATH}/.telepresence/env-files/${NAMESPACE}:${ENVIRONMENT_PATH}/.telepresence/env-files/${NAMESPACE} \
    ${TELEPRESENCE_IMAGE}

    # 提示使用者可以另開視窗執行：docker logs -f kde-telepresence-session-${CUR_ENV}-${NAMESPACE} 來查看詳細的連線資訊
    echo "telepresence 連線中，如果要看詳細的連線資訊，可以另開終端機視窗執行："
    echo "docker logs -f kde-telepresence-session-${CUR_ENV}-${NAMESPACE}"

    # 使用 docker logs 判斷 telepresence 是否啟動成功
    count=0
    while ! docker logs kde-telepresence-session-${CUR_ENV}-${NAMESPACE} | grep "Connected to context"; do
        echo "telepresence 連線中..."
        sleep 1
        count=$((count + 1))
        if [[ ${count} -gt 30 ]]; then
            echo "telepresence 連線失敗"
            stop_telepresence_session_container ${NAMESPACE}
            exit 1
        fi
    done

    if [[ -n "$(docker ps -q -f name=kde-telepresence-session-${CUR_ENV}-${NAMESPACE})" ]]; then
        echo "telepresence 連線成功"
    else
        echo "telepresence 連線失敗"
        exit 1
    fi
}

stop_telepresence_session_container() {
    NAMESPACE=$1
    
    if [[ -n "$(docker ps -q -f name=kde-telepresence-session-${CUR_ENV}-${NAMESPACE})" ]]; then
        echo "stop telepresence session container: $(docker stop kde-telepresence-session-${CUR_ENV}-${NAMESPACE})"
    fi
}

stop_all_telepresence_session_containers() {
    exit_if_not_any_telepresence_session_container
    docker ps -q -f name=kde-telepresence-session- | xargs docker stop
}

# 進入 deploy-env 容器中的 Bash 環境，並且把 Volumes/{PROJECT_NAME} 的資料夾掛載進去 (使用 TTY 模式執行命令)
exec_script_in_container_with_project() {
    PROJECT_NAME=$1
    DOCKER_IMAGE=$2
    SCRIPT=$3
    export PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    PROJECT_ENV_FILE=${PROJECT_PATH}/project.env
    PROJECT_ENV_FILE_TMP=${PROJECT_ENV_FILE}.tmp
    export ENVIRONMENT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}
    HOME_IN_CONTAINER=/home/${USER}

    envsubst < ${PROJECT_ENV_FILE} > ${PROJECT_ENV_FILE_TMP}

    touch ${HOME}/.netrc
    
    docker run --rm -it \
    --user $UID:$(id -g) \
    --net ${DOCKER_NETWORK} \
    --workdir ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME} \
    --group-add $(getent group docker | cut -d: -f3) \
    --env-file ${ENVIRONMENT_PATH}/.telepresence/env-files/${NAMESPACE}/${WORKLOAD}.env \
    --env-file ${PROJECT_ENV_FILE_TMP} \
    -e HOME=${HOME_IN_CONTAINER} \
    -e KUBECONFIG=/.kube/config \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v ${HOME}/.docker:/${HOME_IN_CONTAINER}/.docker \
    -v ${HOME}/.netrc:/${HOME_IN_CONTAINER}/.netrc \
    -v ${KUBECONFIG}:/.kube/config \
    -v ${ENVIRONMENT_PATH}/.telepresence/mounts/local/${NAMESPACE}:${ENVIRONMENT_PATH}/.telepresence/mounts/local/${NAMESPACE} \
    -v ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}:${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME} \
    ${DOCKER_IMAGE} \
    bash -c "${SCRIPT}"
}

select_ports() {
    FORWARD_PORTS=()
    IS_MORE_PORTS="y"

    while [[ ${IS_MORE_PORTS} == "y" ]]; do
        read -p "請輸入遠端 Pod 使用的 Port: " REMOTE_PORT
        read -p "請輸入本地對應的 Port: " LOCAL_PORT
        FORWARD_PORTS+=("--port ${LOCAL_PORT}:${REMOTE_PORT} ")

        read -p "是否還有其他 Port 需要轉發? (y/n): " IS_MORE_PORTS
        # 將 IS_MORE_PORTS 轉小寫
        IS_MORE_PORTS=$(echo ${IS_MORE_PORTS} | tr '[:upper:]' '[:lower:]')
    done
    
    echo "${FORWARD_PORTS[@]}"
}

replace_workload() {
    NAMESPACE=$1
    WORKLOAD=$2
    ENVIRONMENT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}

    docker exec -it kde-telepresence-session-${CUR_ENV}-${NAMESPACE} telepresence replace ${WORKLOAD} --env-file ${ENVIRONMENT_PATH}/.telepresence/env-files/${NAMESPACE}/${WORKLOAD}.env $(select_ports) --mount ${ENVIRONMENT_PATH}/.telepresence/mounts/remote/${NAMESPACE}/${WORKLOAD}
}

intercept_workload() {
    NAMESPACE=$1
    WORKLOAD=$2
    ENVIRONMENT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}

    docker exec -it kde-telepresence-session-${CUR_ENV}-${NAMESPACE} telepresence intercept ${WORKLOAD} --env-file ${ENVIRONMENT_PATH}/.telepresence/env-files/${NAMESPACE}/${WORKLOAD}.env $(select_ports) --mount ${ENVIRONMENT_PATH}/.telepresence/mounts/remote/${NAMESPACE}/${WORKLOAD}
}

wiretap_workload() {
    NAMESPACE=$1
    WORKLOAD=$2
    ENVIRONMENT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}

    docker exec -it kde-telepresence-session-${CUR_ENV}-${NAMESPACE} telepresence wiretap ${WORKLOAD} --env-file ${ENVIRONMENT_PATH}/.telepresence/env-files/${NAMESPACE}/${WORKLOAD}.env $(select_ports) --mount ${ENVIRONMENT_PATH}/.telepresence/mounts/remote/${NAMESPACE}/${WORKLOAD}
}

ingest_workload() {
    NAMESPACE=$1
    WORKLOAD=$2
    ENVIRONMENT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}

    docker exec -it kde-telepresence-session-${CUR_ENV}-${NAMESPACE} telepresence ingest ${WORKLOAD} --env-file ${ENVIRONMENT_PATH}/.telepresence/env-files/${NAMESPACE}/${WORKLOAD}.env --mount ${ENVIRONMENT_PATH}/.telepresence/mounts/remote/${NAMESPACE}/${WORKLOAD}
}

uninstall_telepresence_agents() {
    NAMESPACE=$1

    # 如果 telepresence session container 不存在，則建立連線
    if [[ -z "$(docker ps -q -f name=kde-telepresence-session-${CUR_ENV}-${NAMESPACE})" ]]; then
        create_telepresence_session_container ${NAMESPACE}
    fi

    docker exec -it kde-telepresence-session-${CUR_ENV}-${NAMESPACE} telepresence uninstall --all-agents

    stop_telepresence_session_container ${NAMESPACE}
}