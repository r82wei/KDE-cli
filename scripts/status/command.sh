#!/bin/bash

# 使用 kde list 命令列出所有環境
environments=$(kde list)

echo -e "[STATUS]\t[Environment]"

# 使用 kde status 命令查看每個環境的狀態
for environment in $environments; do
    status=$(is_env_running $environment)
    if [[ $status == "true" ]]; then
        echo -e "\033[32m[RUNNING]\033[0m\t \033[32m$environment\033[0m"
    else
        echo -e "\033[31m[UNREADY]\033[0m\t \033[31m$environment\033[0m"
    fi
done