#!/bin/bash

preview_tui_cmd() {
  local -a cmd=("$@")
  local cmd_preview
  cmd_preview=$(printf '%q ' "${cmd[@]}")
  gum style --border normal --padding "1 2" --margin "1 0" "Will run:\n${cmd_preview}"
}

execute_tui_cmd() {
  local -a cmd=("$@")
  gum confirm "執行命令？" || return 1
  echo ""
  echo "▶ 執行中..."
  "${cmd[@]}"
  echo ""
  gum style --foreground 42 "✅ 完成"
}
