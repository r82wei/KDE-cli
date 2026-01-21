#!/bin/bash

CUR_ENV=${1:-${CUR_ENV}}

if [[ $(is_env_exist ${CUR_ENV}) == "false" ]]; then
    echo "環境 ${CUR_ENV} 不存在"
    exit 1
fi

# 詢問使用者是否確定要重置環境，如果不是 y 就退出
read -p "確定要重置 ${CUR_ENV} K8S 環境？ (y/n): " RESET_ENV
if [[ "${RESET_ENV}" != "y" ]]; then
    exit 0;
fi

# 停止環境
if [[ $(is_env_running ${CUR_ENV}) == "true" ]]; then
    kde stop ${CUR_ENV}
fi

# 列出 ${ENVIROMENTS_PATH}/${CUR_ENV} 底下的資料夾與檔案(包含隱藏檔但不包含 *.template.yaml 檔案與 . 和 .. 資料夾)，使用 for 迴圈移除 namespace 以外的資料夾與檔案
for item in $(ls -a ${ENVIROMENTS_PATH}/${CUR_ENV}); do
    if [[ "${item}" != "namespaces" && "${item}" != "." && "${item}" != ".." && "${item}" != "*.template.yaml" ]]; then
        rm -rf ${ENVIROMENTS_PATH}/${CUR_ENV}/${item}
        echo "移除：${ENVIROMENTS_PATH}/${CUR_ENV}/${item}"
    fi
done

read -p "是否要保留 namespaces (專案集合)資料夾？ (y/n): " KEEP_NAMESPACES
if [[ "${KEEP_NAMESPACES}" != "y" && "${KEEP_NAMESPACES}" != "Y" ]]; then
    rm -rf ${ENVIROMENTS_PATH}/${CUR_ENV}
fi