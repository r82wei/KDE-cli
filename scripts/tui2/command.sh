#!/bin/bash

set -euo pipefail

KDE_BIN="${KDE_CLI_PATH}/kde.sh"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "缺少必要工具：$1"
    echo "請先安裝：$1"
    exit 1
  }
}

need_cmd fzf
need_cmd gum

pick_env() {
  ls -1 "${ENVIROMENTS_PATH}" 2>/dev/null | fzf --prompt="[KDE] Environment > " --height=40% --reverse
}

pick_project() {
  local env="$1"
  ls -1 "${ENVIROMENTS_PATH}/${env}/${VOLUMES_DIR}" 2>/dev/null | fzf --prompt="[KDE] Project(${env}) > " --height=40% --reverse
}

pick_action() {
  printf "%s\n" pipeline deploy undeploy redeploy exec tail pod pod-exec pull fetch ingress remove | \
    fzf --prompt="[KDE] Action > " --height=50% --reverse
}

build_cmd() {
  local project="$1"
  local action="$2"
  local -a cmd
  cmd=("${KDE_BIN}" project "${action}" "${project}")

  case "${action}" in
    pipeline|deploy)
      mode=$(gum choose "full" "only" "from-to")
      if [[ "${mode}" == "only" ]]; then
        stage=$(gum input --placeholder "stage (e.g. build/test/deploy)")
        [[ -n "${stage}" ]] && cmd+=("--only" "${stage}")
      elif [[ "${mode}" == "from-to" ]]; then
        from_stage=$(gum input --placeholder "from stage")
        to_stage=$(gum input --placeholder "to stage")
        [[ -n "${from_stage}" ]] && cmd+=("--from" "${from_stage}")
        [[ -n "${to_stage}" ]] && cmd+=("--to" "${to_stage}")
      fi

      if gum confirm "啟用 manual 模式？"; then
        cmd+=("--manual")
      fi
      ;;
    exec)
      exec_mode=$(gum choose "develop" "deploy")
      cmd+=("${exec_mode}")
      exec_port=$(gum input --placeholder "port (optional)")
      [[ -n "${exec_port}" ]] && cmd+=("${exec_port}")
      ;;
    tail)
      pod_name=$(gum input --placeholder "pod name (optional)")
      [[ -n "${pod_name}" ]] && cmd+=("${pod_name}")
      lines=$(gum input --placeholder "lines (default 100)")
      [[ -n "${lines}" ]] && cmd+=("${lines}")
      ;;
    pull)
      if gum confirm "使用 --force 重新抓取？"; then
        cmd+=("--force")
      fi
      ;;
    fetch)
      git_url=$(gum input --placeholder "Git URL")
      [[ -z "${git_url}" ]] && { echo "Git URL 不可為空"; exit 1; }
      git_branch=$(gum input --placeholder "Branch (default main)")
      git_branch=${git_branch:-main}
      cmd=("${KDE_BIN}" project fetch "${project}" "${git_url}" "${git_branch}")
      ;;
    remove)
      verify=$(gum input --placeholder "輸入專案名稱確認刪除: ${project}")
      [[ "${verify}" != "${project}" ]] && { echo "名稱不符，取消執行"; exit 0; }
      ;;
  esac

  printf '%q ' "${cmd[@]}"
}

main() {
  [[ -d "${ENVIROMENTS_PATH}" ]] || { echo "找不到 environments 目錄：${ENVIROMENTS_PATH}"; exit 1; }

  selected_env=$(pick_env)
  [[ -n "${selected_env}" ]] || exit 0

  "${KDE_BIN}" use "${selected_env}" >/dev/null

  selected_project=$(pick_project "${selected_env}")
  [[ -n "${selected_project}" ]] || exit 0

  selected_action=$(pick_action)
  [[ -n "${selected_action}" ]] || exit 0

  cmd_preview=$(build_cmd "${selected_project}" "${selected_action}")

  gum style --border normal --padding "1 2" --margin "1 0" "Will run:\n${cmd_preview}"

  gum confirm "執行命令？" || exit 0

  echo ""
  echo "▶ 執行中..."
  eval "${cmd_preview}"
  echo ""
  gum style --foreground 42 "✅ 完成"
}

main "$@"
