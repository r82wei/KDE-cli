#!/bin/bash

# # 設定 KDE 根目錄路徑
# export KDE_PATH=$PWD
# # 設定環境目錄路徑(enviroments)
# export ENVIROMENTS_PATH=${KDE_PATH}/enviroments
# # 設定專案目錄路徑(projects)
# export PROJECTS_PATH=${KDE_PATH}/projects
# # 設定 KUBE_CONFIG_DIR
# export KUBE_CONFIG_DIR=kubeconfig
# # 設定 VOLUMES_DIR
# export VOLUMES_DIR=volumes

source scripts/utils/enviroment.sh
source scripts/utils/project.sh

# # 設定當前環境的環境變數
# if [[ -f ${KDE_PATH}/current.env ]]; then
#     source ${KDE_PATH}/current.env
#     if [[ $(is_env_exist ${CUR_ENV}) == "false" ]]; then
#         echo "環境 ${CUR_ENV} 不存在"
#         # 修改預設環境
#         set_default_env
#     fi
#     load_enviroment_env ${CUR_ENV}
# fi

# # namespaces=($(get_namespaces))
# # echo "namespaces: ${namespaces[@]}"

# # pods=($(get_pods ${namespaces[1]}))
# # echo "pods: ${pods[@]}"

# # services=($(get_services ${namespaces[1]}))
# # echo "services: ${services[@]}"

# # is_namespace_exist "ingress-nginx"
# # echo "is_namespace_exist: ${is_namespace_exist}"    

# # is_pod_exist=$(is_pod_exist "ingress-nginx" "ingress-nginx-controller-cd9d6bbd7-mwp67")
# # echo "is_pod_exist: ${is_pod_exist}"    

# # is_service_exist=$(is_service_exist "ingress-nginx" "ingrdess-nginx-controller")
# # echo "is_service_exist: ${is_service_exist}"    


# # is_pod_exist=$(is_pod_or_service_exist "ingress-nginx" "pod" "ingress-nginx-controller-cd9d6bbd7-mwp67")
# # echo "is_pod_or_service_exist: ${is_pod_exist}"    

# # is_service_exist=$(is_pod_or_service_exist "ingress-nginx" "service" "ingress-nginx-controller")
# # echo "is_service_exist: ${is_service_exist}"    


# # exec_in_deploy_env "kubectl get pods -A"

# # has_any_env
# # echo $(basename $(ls -d ${ENVIROMENTS_PATH}/*/ | head -n 1))

# # if [[ $(has_any_env) == "true" ]]; then
# #     export CUR_ENV=$(basename $(ls -d ${ENVIROMENTS_PATH}/*/ | head -n 1))
# #     echo "CUR_ENV=${CUR_ENV}" > ${KDE_PATH}/current.env
# #     echo "當前 k8s 環境已變更為: ${CUR_ENV}"
# # # 如果沒有任何環境存在，則刪除 current.env
# # else
# #     rm -f ${KDE_PATH}/current.env
# #     echo "目前沒有 k8s 環境"
# # fi

# if [[ $(is_env_exist ${CUR_ENV}) == "false" ]]; then
#     echo "環境 ${CUR_ENV} 不存在"
#     # 修改預設環境
#     set_default_env
# fi
# GIT_REPO_URL="https://github.com/docker.anyong.com.tw/quick-start/k8s-deploy-env.git"
# echo $(git_repo_name ${GIT_REPO_URL})

containers=$(get_env_containers ubuntu kind)
echo "${containers}"
containers=$(get_env_containers k3s k3d)
echo "${containers}"