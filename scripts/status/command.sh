#!/bin/bash

# 使用 kde list 命令列出所有環境
environments=$(kde list)
FORMAT=$1
JSON_STRING=""

case $FORMAT in
    "json")
        JSON_STRING="["
        ;;
    *)
        echo -e "[STATUS]\t[Environment]"
        ;;
esac

# 使用 kde status 命令查看每個環境的狀態
for environment in $environments; do
    status=$(is_env_running $environment)
    if [[ $status == "true" ]]; then
        case $FORMAT in
            "json")
                JSON_STRING+="{\"status\":\"running\",\"environment\":\"$environment\"},"
                ;;
            *)
                echo -e "\033[32m[RUNNING]\033[0m\t \033[32m$environment\033[0m"
                ;;
        esac
    else
        case $FORMAT in
            "json")
                JSON_STRING+="{\"status\":\"unready\",\"environment\":\"$environment\"},"
                ;;
            *)
                echo -e "\033[31m[UNREADY]\033[0m\t \033[31m$environment\033[0m"
                ;;
        esac
    fi
done

case $FORMAT in
    "json")
        # JSON_STRING 移除最後一個逗號
        JSON_STRING=${JSON_STRING%?}
        JSON_STRING+="]"
        echo $JSON_STRING
        ;;
    *)
        ;;
esac