#!/bin/bash

# 詢問使用者是否確定要重置環境，如果不是 y 就退出
read -p "確定要重置環境？ (y/n): " RESET_ENV
if [[ "${RESET_ENV}" != "y" ]]; then
    exit 0;
fi

# 停止環境
kde stop ${CUR_ENV}

# 重置環境
rm -rf ${ENVIROMENTS_PATH}/${CUR_ENV}