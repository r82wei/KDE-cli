#!/bin/bash

docker run -it --rm \
    --name tp-session \
    --cap-add=NET_ADMIN \
    --device /dev/net/tun \
    --network telepresence \
    -e TELEPRESENCE_CONNECT_NAMESPACE=gosu \
    -v ~/.kube/concords.ay.telepresence.config:/root/.kube/config:ro \
    -v $(pwd)/entrypoint.sh:/usr/local/bin/entrypoint.sh \
    -v $(pwd)/env-files:/root/env-files \
    r82wei/telepresence:1.0.0-alpha-4