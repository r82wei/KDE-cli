#!/bin/bash

set -euo pipefail

KDE_BIN="${KDE_CLI_PATH}/kde.sh"

source "${KDE_SCRIPTS_PATH}/utils/tui/selector.sh"
source "${KDE_SCRIPTS_PATH}/utils/tui/guard.sh"
source "${KDE_SCRIPTS_PATH}/utils/tui/args.sh"
source "${KDE_SCRIPTS_PATH}/utils/tui/execute.sh"

main() {
  require_tui_tools

  [[ -d "${ENVIROMENTS_PATH}" ]] || { echo "找不到 environments 目錄：${ENVIROMENTS_PATH}"; exit 1; }

  local selected_env selected_project selected_action
  local -a cmd=()

  selected_env=$(pick_tui_env)
  [[ -n "${selected_env}" ]] || exit 0

  "${KDE_BIN}" use "${selected_env}" >/dev/null

  selected_project=$(pick_tui_project "${selected_env}")
  [[ -n "${selected_project}" ]] || exit 0

  selected_action=$(pick_tui_action)
  [[ -n "${selected_action}" ]] || exit 0

  guard_tui_action "${selected_action}" "${selected_project}" || exit 0
  collect_tui_action_args "${selected_project}" "${selected_action}" cmd

  preview_tui_cmd "${cmd[@]}"
  execute_tui_cmd "${cmd[@]}"
}

main "$@"
