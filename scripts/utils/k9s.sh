#!/bin/bash

start_k9s() {
    docker run --rm -it --net ${DOCKER_NETWORK} -v ${KUBECONFIG}:/root/.kube/config ${K9S_IMAGE} -A
}

expose_k9s() {
    K9S_PORT=$1
    
    docker run --rm -it --net ${DOCKER_NETWORK} -v ${KUBECONFIG}:/root/.kube/config -p "${K9S_PORT}":"${K9S_PORT}" ${K9S_IMAGE} -A
}

