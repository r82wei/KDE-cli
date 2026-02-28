#!/bin/bash

set -e

KDE_BIN=${KDE_CLI_PATH}/kde.sh

choose_from_array() {
  local title="$1"
  shift
  local options=("$@")

  if [[ ${#options[@]} -eq 0 ]]; then
    return 1
  fi

  echo ""
  echo "$title"
  local i=1
  for opt in "${options[@]}"; do
    echo "  $i) $opt"
    i=$((i+1))
  done

  while true; do
    read -p "請輸入編號: " idx
    if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >=1 && idx <= ${#options[@]} )); then
      echo "${options[$((idx-1))]}"
      return 0
    fi
    echo "無效輸入，請重新輸入。"
  done
}

# 1) 選擇環境
if [[ ! -d ${ENVIROMENTS_PATH} ]]; then
  echo "找不到 environments 目錄：${ENVIROMENTS_PATH}"
  exit 1
fi

mapfile -t ENVS < <(ls -1 ${ENVIROMENTS_PATH} 2>/dev/null)
if [[ ${#ENVS[@]} -eq 0 ]]; then
  echo "目前沒有可用環境，請先執行：kde start <env> kind|k3d|k8s"
  exit 1
fi

SELECTED_ENV=$(choose_from_array "[1/4] 請選擇環境（kde ls）" "${ENVS[@]}")
${KDE_BIN} use ${SELECTED_ENV}

# 2) 選擇專案
PROJECT_ROOT="${ENVIROMENTS_PATH}/${SELECTED_ENV}/${VOLUMES_DIR}"
if [[ ! -d ${PROJECT_ROOT} ]]; then
  echo "當前環境沒有 namespaces 目錄：${PROJECT_ROOT}"
  exit 1
fi

mapfile -t PROJECTS < <(ls -1 ${PROJECT_ROOT} 2>/dev/null)
if [[ ${#PROJECTS[@]} -eq 0 ]]; then
  echo "環境 ${SELECTED_ENV} 目前沒有專案。"
  echo "你可以先用：kde proj create <project_name>"
  exit 1
fi

SELECTED_PROJECT=$(choose_from_array "[2/4] 請選擇專案（kde project ls）" "${PROJECTS[@]}")

# 3) 選擇功能
FEATURES=(
  "pipeline"
  "deploy"
  "undeploy"
  "redeploy"
  "exec"
  "tail"
  "pod"
  "pod-exec"
  "pull"
  "fetch"
  "ingress"
  "remove"
)

SELECTED_FEATURE=$(choose_from_array "[3/4] 請選擇功能（kde project 子功能）" "${FEATURES[@]}")

# 4) 輸入參數並執行
CMD=("${KDE_BIN}" project "${SELECTED_FEATURE}" "${SELECTED_PROJECT}")

echo ""
echo "[4/4] 參數輸入"

case "${SELECTED_FEATURE}" in
  pipeline|deploy)
    read -p "是否只執行單一階段？(y/N): " only_mode
    if [[ "${only_mode}" == "y" || "${only_mode}" == "Y" ]]; then
      read -p "請輸入階段名稱（例如 build/test/deploy）: " stage
      if [[ -n "${stage}" ]]; then
        CMD+=("--only" "${stage}")
      fi
    else
      read -p "是否指定 from 階段？(y/N): " from_mode
      if [[ "${from_mode}" == "y" || "${from_mode}" == "Y" ]]; then
        read -p "from 階段: " from_stage
        [[ -n "${from_stage}" ]] && CMD+=("--from" "${from_stage}")
      fi
      read -p "是否指定 to 階段？(y/N): " to_mode
      if [[ "${to_mode}" == "y" || "${to_mode}" == "Y" ]]; then
        read -p "to 階段: " to_stage
        [[ -n "${to_stage}" ]] && CMD+=("--to" "${to_stage}")
      fi
    fi
    read -p "是否使用 manual 模式？(y/N): " manual_mode
    if [[ "${manual_mode}" == "y" || "${manual_mode}" == "Y" ]]; then
      CMD+=("--manual")
    fi
    ;;
  exec)
    read -p "執行模式（develop/deploy，預設 develop）: " exec_mode
    exec_mode=${exec_mode:-develop}
    CMD+=("${exec_mode}")
    read -p "是否指定 port（留空略過）: " exec_port
    [[ -n "${exec_port}" ]] && CMD+=("${exec_port}")
    ;;
  tail)
    read -p "指定 pod 名稱（留空自動選）: " pod_name
    [[ -n "${pod_name}" ]] && CMD+=("${pod_name}")
    read -p "指定顯示行數（預設 100）: " line_count
    [[ -n "${line_count}" ]] && CMD+=("${line_count}")
    ;;
  pod|pod-exec|undeploy|redeploy|ingress)
    # 這些功能直接執行，若有額外輸入會由原子命令繼續互動
    ;;
  pull)
    read -p "是否使用 --force 重新抓取？(y/N): " force_pull
    if [[ "${force_pull}" == "y" || "${force_pull}" == "Y" ]]; then
      CMD+=("--force")
    fi
    ;;
  fetch)
    read -p "Git URL: " git_url
    read -p "Branch（預設 main）: " git_branch
    git_branch=${git_branch:-main}
    if [[ -z "${git_url}" ]]; then
      echo "Git URL 不可為空"
      exit 1
    fi
    CMD=("${KDE_BIN}" project "fetch" "${SELECTED_PROJECT}" "${git_url}" "${git_branch}")
    ;;
  remove)
    read -p "確認刪除專案 ${SELECTED_PROJECT}？(y/N): " confirm_remove
    if [[ "${confirm_remove}" != "y" && "${confirm_remove}" != "Y" ]]; then
      echo "已取消"
      exit 0
    fi
    ;;
esac

echo ""
echo "即將執行：${CMD[*]}"
"${CMD[@]}"
