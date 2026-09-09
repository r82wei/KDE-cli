#!/bin/bash

# safety guards for destructive actions

guard_tui_action() {
  local action="$1"
  local project="$2"

  case "${action}" in
    remove)
      local verify
      verify=$(gum input --placeholder "輸入專案名稱確認刪除: ${project}")
      [[ "${verify}" == "${project}" ]] || { echo "名稱不符，取消執行"; return 1; }
      ;;
    undeploy|redeploy)
      gum confirm "確認執行 ${action}（project: ${project}）？" || return 1
      ;;
    *)
      ;;
  esac

  return 0
}
