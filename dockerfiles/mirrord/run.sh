#!/bin/bash
# 用於測試的腳本

echo "啟動 Mirrord 測試容器..."
docker run -it --rm \
    -v ~/.kube/config:/root/.kube/config:ro \
    kde-mirrord:latest bash
