#!/bin/bash

# 如果 $1 有帶入參數，則設定 CUR_ENV 為 $1
if [[ -n "$1" ]]; then
    set_default_env $1
else
    PS3="請選擇環境（輸入編號）："
    select resource in $(ls ${ENVIROMENTS_PATH}) "退出"
    do
        case $resource in
            "退出")
                echo "退出"
                exit 0
                ;;
            "")
                echo "無效選擇，請重新輸入。"
                ;;
            *)
                set_default_env ${resource}
                break
                ;;
        esac
    done
fi


if [[ ! -f ${ENVIROMENTS_PATH}/${CUR_ENV}/.env || ! -f ${ENVIROMENTS_PATH}/${CUR_ENV}/kind-config.yaml ]]; then
    # 判斷 k8s.env 是否存在，如果存在就讀取 ENV_TYPE  
    if [[ -f ${ENVIROMENTS_PATH}/${CUR_ENV}/k8s.env ]]; then
        source ${ENVIROMENTS_PATH}/${CUR_ENV}/k8s.env    
    else
        export ENV_TYPE="kind"
    fi

    kde create ${CUR_ENV} ${ENV_TYPE}
fi