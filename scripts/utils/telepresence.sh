#!/bin/bash

create_telepresence_session_container() {
    NAMESPACE=$1
    DOCKER_NETWORK=kde-telepresence
    PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}

    # Ensure Docker network
    if [ -z "$( docker network ls | awk '{print $2}' | grep ^$DOCKER_NETWORK$ )" ]; then
        docker network create $DOCKER_NETWORK
    fi

    # 啟動 telepresence container 並且透過 telepresence connect ${NAMESPACE} 連線
    docker run -itd \
    --name kde-telepresence-session-${NAMESPACE} \
    --cap-add=NET_ADMIN \
    --device /dev/net/tun \
    --network ${DOCKER_NETWORK} \
    -e TELEPRESENCE_CONNECT_NAMESPACE=${NAMESPACE} \
    -v ~/.kube/concords.ay.telepresence.config:/root/.kube/config:ro \
    -v ${PROJECT_PATH}/.telepresence/env-files:/root/.telepresence/env-files \
    r82wei/telepresence:1.0.2
}

remove_telepresence_session_container() {
    NAMESPACE=$1
    if [[ -n "$(docker ps -q -f name=kde-telepresence-session-${NAMESPACE})" ]]; then
        docker stop kde-telepresence-session-${NAMESPACE}
        docker rm kde-telepresence-session-${NAMESPACE}
    fi
}

select_workload() {
    # TODO: 透過 telepresence list 列出所有可用的 workload
    export WORKLOAD=${TARGET_SERVICE}
}

# exec_project_develop_container() {
#     PROJECT_NAME=$1
#     PORT=$2

#     exit_if_project_not_exist ${PROJECT_NAME}
#     source ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}/project.env
#     REPO_NAME=$(git_repo_name ${GIT_REPO_URL})
#     echo "REPO_NAME: ${REPO_NAME}"
#     if [[ -z "${PORT}" ]]; then
#         exec_script_in_container_with_project ${PROJECT_NAME} ${DEVELOP_IMAGE} "cd ${REPO_NAME} && bash"
#     else
#         exec_script_in_container_with_project_and_port ${PROJECT_NAME} ${DEVELOP_IMAGE} "cd ${REPO_NAME} && bash" ${PORT}
#     fi
# }

exec_script_in_container_with_project_and_port() {
    PROJECT_NAME=$1
    DOCKER_IMAGE=$2
    SCRIPT=$3
    PORT=$4
    export PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    HOME_IN_CONTAINER=/home/${USER}

    touch ${HOME}/.netrc
    
    docker run --rm -it \
    --user $UID:$(id -g) \
    --net ${DOCKER_NETWORK} \
    --workdir ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME} \
    --group-add $(getent group docker | cut -d: -f3) \
    --env-file ${PROJECT_PATH}/.telepresence/env-files/${WORKLOAD}.env \
    -e HOME=${HOME_IN_CONTAINER} \
    -e KUBECONFIG=/.kube/config \
    -p ${PORT}:${PORT} \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v ${HOME}/.docker:/.home/.docker \
    -v ${HOME}/.netrc:/.home/.netrc \
    -v ${KUBECONFIG}:/.kube/config \
    -v ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}:${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME} \
    ${DOCKER_IMAGE} \
    bash -c "${SCRIPT}"
    
    remove_telepresence_session_container ${NAMESPACE}
}

# 進入 deploy-env 容器中的 Bash 環境，並且把 Volumes/{PROJECT_NAME} 的資料夾掛載進去 (使用 TTY 模式執行命令)
exec_script_in_container_with_project() {
    PROJECT_NAME=$1
    DOCKER_IMAGE=$2
    SCRIPT=$3
    export PROJECT_PATH=${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}
    HOME_IN_CONTAINER=/home/${USER}

    touch ${HOME}/.netrc
    
    docker run --rm -it \
    --user $UID:$(id -g) \
    --net ${DOCKER_NETWORK} \
    --workdir ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME} \
    --group-add $(getent group docker | cut -d: -f3) \
    --env-file ${PROJECT_PATH}/.telepresence/env-files/${WORKLOAD}.env \
    -e HOME=${HOME_IN_CONTAINER} \
    -e KUBECONFIG=/.kube/config \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v ${HOME}/.docker:/${HOME_IN_CONTAINER}/.docker \
    -v ${HOME}/.netrc:/${HOME_IN_CONTAINER}/.netrc \
    -v ${KUBECONFIG}:/.kube/config \
    -v ${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME}:${ENVIROMENTS_PATH}/${CUR_ENV}/${VOLUMES_DIR}/${PROJECT_NAME} \
    ${DOCKER_IMAGE} \
    bash -c "${SCRIPT}"

    remove_telepresence_session_container ${NAMESPACE}
}