#!/bin/bash

read -p "請輸入 kind 版本 (default: v5.8.3)： " K3D_VERSION
K3D_VERSION=${K3D_VERSION:-v5.8.3}

echo "Build k3d ${K3D_VERSION} image ..."
docker buildx build --platform linux/amd64,linux/arm64 --push --build-arg K3D_VERSION=${K3D_VERSION} -f Dockerfile -t docker.anyong.com.tw/quick-start/k3d:${K3D_VERSION} .