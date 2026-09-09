#!/bin/bash

# collect args for kde project actions

collect_tui_action_args() {
  local project="$1"
  local action="$2"
  local -n _out_cmd=$3

  _out_cmd=("${KDE_BIN}" project "${action}" "${project}")

  case "${action}" in
    pipeline|deploy)
      local mode stage from_stage to_stage
      mode=$(gum choose "full" "only" "from-to")
      if [[ "${mode}" == "only" ]]; then
        stage=$(gum input --placeholder "stage (e.g. build/test/deploy)")
        [[ -n "${stage}" ]] && _out_cmd+=("--only" "${stage}")
      elif [[ "${mode}" == "from-to" ]]; then
        from_stage=$(gum input --placeholder "from stage")
        to_stage=$(gum input --placeholder "to stage")
        [[ -n "${from_stage}" ]] && _out_cmd+=("--from" "${from_stage}")
        [[ -n "${to_stage}" ]] && _out_cmd+=("--to" "${to_stage}")
      fi
      gum confirm "啟用 manual 模式？" && _out_cmd+=("--manual") || true
      ;;
    exec)
      local exec_mode exec_port
      exec_mode=$(gum choose "develop" "deploy")
      _out_cmd+=("${exec_mode}")
      exec_port=$(gum input --placeholder "port (optional)")
      [[ -n "${exec_port}" ]] && _out_cmd+=("${exec_port}")
      ;;
    tail)
      local pod_name lines
      pod_name=$(gum input --placeholder "pod name (optional)")
      [[ -n "${pod_name}" ]] && _out_cmd+=("${pod_name}")
      lines=$(gum input --placeholder "lines (default 100)")
      [[ -n "${lines}" ]] && _out_cmd+=("${lines}")
      ;;
    pull)
      gum confirm "使用 --force 重新抓取？" && _out_cmd+=("--force") || true
      ;;
    fetch)
      local git_url git_branch
      git_url=$(gum input --placeholder "Git URL")
      [[ -z "${git_url}" ]] && { echo "Git URL 不可為空"; return 1; }
      git_branch=$(gum input --placeholder "Branch (default main)")
      git_branch=${git_branch:-main}
      _out_cmd=("${KDE_BIN}" project fetch "${project}" "${git_url}" "${git_branch}")
      ;;
    *)
      ;;
  esac

  return 0
}
