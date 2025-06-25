#!/bin/bash

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
    DOCKER_NETWORK=kde-telepresence
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
    --network ${DOCKER_NETWORK} \
    -e TELEPRESENCE_CONNECT_NAMESPACE=${NAMESPACE} \
    -e TELEPRESENCE_ALSO_PROXY_CIDR=${TELEPRESENCE_ALSO_PROXY_CIDR} \
    -v ~/.kube/concords.ay.telepresence.config:/root/.kube/config:ro \
    -v ${ENVIRONMENT_PATH}/.telepresence/env-files/${NAMESPACE}:${ENVIRONMENT_PATH}/.telepresence/env-files/${NAMESPACE} \
    -v ${ENVIRONMENT_PATH}/.telepresence/mounts/${NAMESPACE}:${ENVIRONMENT_PATH}/.telepresence/mounts/${NAMESPACE} \
    r82wei/telepresence:1.0.2

    # 使用 docker logs 判斷 telepresence container 是否啟動成功
    count=0
    while ! docker logs kde-telepresence-session-${CUR_ENV}-${NAMESPACE} | grep "Connected to OSS Traffic Agent"; do
        echo "telepresence container 連線中..."
        sleep 1
        count=$((count + 1))
        if [[ ${count} -gt 30 ]]; then
            echo "telepresence container 連線失敗"
            stop_telepresence_session_container ${NAMESPACE}
            exit 1
        fi
    done

    if [[ -n "$(docker ps -q -f name=kde-telepresence-session-${CUR_ENV}-${NAMESPACE})" ]]; then
        echo "telepresence container 連線成功"
    else
        echo "telepresence container 連線失敗"
        exit 1
    fi
}

stop_telepresence_session_container() {
    NAMESPACE=$1
    
    if [[ -n "$(docker ps -q -f name=kde-telepresence-session-${CUR_ENV}-${NAMESPACE})" ]]; then
        docker stop kde-telepresence-session-${CUR_ENV}-${NAMESPACE}
    fi
}

stop_all_telepresence_session_containers() {
    exit_if_not_any_telepresence_session_container
    docker ps -q -f name=kde-telepresence-session- | xargs docker stop
}



exec_script_in_container_with_project_and_port() {
    PROJECT_NAME=$1
    DOCKER_IMAGE=$2
    SCRIPT=$3
    PORT=$4
    PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    PROJECT_ENV_FILE=${PROJECT_PATH}/project.env
    PROJECT_ENV_FILE_TMP=${PROJECT_ENV_FILE}.tmp
    ENVIRONMENT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}
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
    -p ${PORT}:${PORT} \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v ${HOME}/.docker:/.home/.docker \
    -v ${HOME}/.netrc:/.home/.netrc \
    -v ${KUBECONFIG}:/.kube/config \
    -v ${ENVIRONMENT_PATH}/.telepresence/mounts/${NAMESPACE}:${ENVIRONMENT_PATH}/.telepresence/mounts/${NAMESPACE} \
    -v ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}:${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME} \
    ${DOCKER_IMAGE} \
    bash -c "${SCRIPT}"
}

# 進入 deploy-env 容器中的 Bash 環境，並且把 Volumes/{PROJECT_NAME} 的資料夾掛載進去 (使用 TTY 模式執行命令)
exec_script_in_container_with_project() {
    PROJECT_NAME=$1
    DOCKER_IMAGE=$2
    SCRIPT=$3
    PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    PROJECT_ENV_FILE=${PROJECT_PATH}/project.env
    PROJECT_ENV_FILE_TMP=${PROJECT_ENV_FILE}.tmp
    ENVIRONMENT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}
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
    -v ${ENVIRONMENT_PATH}/.telepresence/mounts/${NAMESPACE}:${ENVIRONMENT_PATH}/.telepresence/mounts/${NAMESPACE} \
    -v ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}:${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME} \
    ${DOCKER_IMAGE} \
    bash -c "${SCRIPT}"
}

replace_workload() {
    NAMESPACE=$1
    WORKLOAD=$2
    LOCAL_PORT=$3
    ENVIRONMENT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}

    docker exec -it kde-telepresence-session-${CUR_ENV}-${NAMESPACE} telepresence replace ${WORKLOAD} --env-file ${ENVIRONMENT_PATH}/.telepresence/env-files/${NAMESPACE}/${WORKLOAD}.env --port ${LOCAL_PORT} --mount ${ENVIRONMENT_PATH}/.telepresence/mounts/${NAMESPACE}/${WORKLOAD}
}

intercept_workload() {
    NAMESPACE=$1
    WORKLOAD=$2
    LOCAL_PORT=$3
    ENVIRONMENT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}

    docker exec -it kde-telepresence-session-${CUR_ENV}-${NAMESPACE} telepresence intercept ${WORKLOAD} --env-file ${ENVIRONMENT_PATH}/.telepresence/env-files/${NAMESPACE}/${WORKLOAD}.env --port ${LOCAL_PORT} --mount ${ENVIRONMENT_PATH}/.telepresence/mounts/${NAMESPACE}/${WORKLOAD}
}

wiretap_workload() {
    NAMESPACE=$1
    WORKLOAD=$2
    LOCAL_PORT=$3
    ENVIRONMENT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}

    docker exec -it kde-telepresence-session-${CUR_ENV}-${NAMESPACE} telepresence wiretap ${WORKLOAD} --env-file ${ENVIRONMENT_PATH}/.telepresence/env-files/${NAMESPACE}/${WORKLOAD}.env --port ${LOCAL_PORT} --mount ${ENVIRONMENT_PATH}/.telepresence/mounts/${NAMESPACE}/${WORKLOAD}
}

ingest_workload() {
    NAMESPACE=$1
    WORKLOAD=$2
    ENVIRONMENT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}

    docker exec -it kde-telepresence-session-${CUR_ENV}-${NAMESPACE} telepresence ingest ${WORKLOAD} --env-file ${ENVIRONMENT_PATH}/.telepresence/env-files/${NAMESPACE}/${WORKLOAD}.env --mount ${ENVIRONMENT_PATH}/.telepresence/mounts/${NAMESPACE}/${WORKLOAD}
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