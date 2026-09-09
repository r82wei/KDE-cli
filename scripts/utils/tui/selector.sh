#!/bin/bash

# selector utilities for kde tui2 (fzf/gum)

require_tui_tools() {
  command -v fzf >/dev/null 2>&1 || { echo "缺少必要工具：fzf"; return 1; }
  command -v gum >/dev/null 2>&1 || { echo "缺少必要工具：gum"; return 1; }
}

pick_tui_env() {
  ls -1 "${ENVIROMENTS_PATH}" 2>/dev/null | fzf --prompt="[KDE] Environment > " --height=40% --reverse
}

pick_tui_project() {
  local env="$1"
  ls -1 "${ENVIROMENTS_PATH}/${env}/${VOLUMES_DIR}" 2>/dev/null | fzf --prompt="[KDE] Project(${env}) > " --height=40% --reverse
}

pick_tui_action() {
  printf "%s\n" pipeline deploy undeploy redeploy exec tail pod pod-exec pull fetch ingress remove | \
    fzf --prompt="[KDE] Action > " --height=50% --reverse
}
