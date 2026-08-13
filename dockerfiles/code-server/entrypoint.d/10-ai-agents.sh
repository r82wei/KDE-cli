#!/bin/bash

# KDE-CLI：依 KDE_CODE_SERVER_AI_AGENTS 安裝 AI coding agent
#
# 由 code-server base image 的 /usr/bin/entrypoint.sh 透過 /entrypoint.d hook
# 執行，時機在 fixuid 與 DOCKER_USER 改名之後、code-server 啟動之前。
#
# 兩個刻意的設計，改動前請先讀 docs/superpowers/specs/2026-08-13-*：
#   1. 無條件 exit 0：純屬防禦性設計。base entrypoint 目前是透過
#      `find ... -exec bash {} \;` 呼叫本 hook，而 find 不會依 exec 的指令結果
#      回傳非零，所以此 hook 的結束碼本來就不會影響是否繼續啟動 code-server；
#      但我們不想依賴這個現況，因此仍明確以 exit 0 收尾，避免將來呼叫方式改變時
#      失敗的 agent 安裝連帶擋住 code-server 啟動。
#   2. 不使用 set -e：否則單一 agent 安裝失敗會中止後續 agent 的處理。

AGENT_DIR="${KDE_CODE_SERVER_AGENT_DIR:-/usr/local/lib/kde-agents}"
AGENT_BIN_DIR="${HOME}/.local/bin"

# 未指定任何 agent → 完全靜默結束（不干擾正常啟動訊息）
if [[ -z "${KDE_CODE_SERVER_AI_AGENTS:-}" ]]; then
    exit 0
fi

# 僅供本程序的 command -v 偵測使用；此 export 無法傳給 code-server，
# 給使用者的 PATH 是靠下面寫進 shell profile
export PATH="${AGENT_BIN_DIR}:${PATH}"
mkdir -p "${AGENT_BIN_DIR}"

# 冪等地把 ~/.local/bin 寫進 shell profile
ensure_path_in_profile() {
    local rc_file=$1
    local guard="# >>> kde-cli agents PATH >>>"

    [[ -f "${rc_file}" ]] || touch "${rc_file}" 2>/dev/null || return 0
    grep -qF "${guard}" "${rc_file}" 2>/dev/null && return 0

    {
        echo ""
        echo "${guard}"
        echo 'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac'
        echo 'export PATH'
        echo "# <<< kde-cli agents PATH <<<"
    } >> "${rc_file}" 2>/dev/null || true
}

ensure_path_in_profile "${HOME}/.bashrc"
ensure_path_in_profile "${HOME}/.profile"

# 由檔名約定動態產生可用 agent 清單，entrypoint 不硬編任何 agent 名稱
list_available_agents() {
    local f name
    for f in "${AGENT_DIR}"/install-*.sh; do
        [[ -e "${f}" ]] || continue
        name=${f##*/install-}
        echo "${name%.sh}"
    done
}

INSTALLED=(); SKIPPED=(); UNKNOWN=(); FAILED=()

IFS=',' read -ra RAW_AGENTS <<< "${KDE_CODE_SERVER_AI_AGENTS}"
for raw in "${RAW_AGENTS[@]}"; do
    # 去除前後空白
    name="${raw#"${raw%%[![:space:]]*}"}"
    name="${name%"${name##*[![:space:]]}"}"
    [[ -z "${name}" ]] && continue

    script="${AGENT_DIR}/install-${name}.sh"

    if [[ ! -f "${script}" ]]; then
        echo "⚠ 不認識的 AI agent：${name}"
        echo "  可用：$(list_available_agents | tr '\n' ' ')"
        UNKNOWN+=("${name}")
        continue
    fi

    if [[ "${KDE_CODE_SERVER_AI_AGENTS_REINSTALL:-}" != "true" ]] \
       && command -v "${name}" >/dev/null 2>&1; then
        echo "✓ ${name} 已安裝，跳過"
        SKIPPED+=("${name}")
        continue
    fi

    echo "→ 安裝 ${name} ..."
    if AGENT_NAME="${name}" \
       AGENT_BIN_DIR="${AGENT_BIN_DIR}" \
       AGENT_REINSTALL="${KDE_CODE_SERVER_AI_AGENTS_REINSTALL:-}" \
       bash "${script}"; then
        echo "✓ ${name} 安裝完成"
        INSTALLED+=("${name}")
    else
        echo "❌ ${name} 安裝失敗（code-server 仍會啟動，可稍後在終端機手動重試）"
        FAILED+=("${name}")
    fi
done

print_summary_line() { # $1=標籤 $2...=項目
    local label=$1
    shift
    [[ $# -eq 0 ]] && return 0
    echo "  ${label}：$*"
}

echo "--- AI agents ---"
print_summary_line "已安裝" "${INSTALLED[@]}"
print_summary_line "已跳過" "${SKIPPED[@]}"
print_summary_line "不認識" "${UNKNOWN[@]}"
print_summary_line "失敗"   "${FAILED[@]}"

# 無條件成功退出，詳見檔頭說明
exit 0
