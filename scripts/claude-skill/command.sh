#!/bin/bash

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde claude-skill <command>  管理 KDE Claude Code 技能"
    echo ""
    echo "command:"
    echo "  install    安裝 kde-usage skill 到 ~/.claude/skills/"
    echo "  update     更新已安裝的 kde-usage skill（同 install）"
    echo "  status     顯示目前安裝狀態"
}

COMMAND=$1

if [[ -z "${COMMAND}" || "${COMMAND}" == "-h" || "${COMMAND}" == "--help" ]]; then
    show_help
    exit 0
fi

SKILL_SRC="${KDE_CLI_PATH}/.claude/skills/kde-usage"
SKILL_DEST="${HOME}/.claude/skills/kde-usage"

case "${COMMAND}" in
    install|update)
        if [[ ! -d "${SKILL_SRC}" ]]; then
            echo "錯誤：找不到 skill 來源目錄：${SKILL_SRC}" >&2
            exit 1
        fi
        mkdir -p "${HOME}/.claude/skills"
        cp -r "${SKILL_SRC}" "${HOME}/.claude/skills/"
        echo "✅ kde-usage skill 已安裝至 ${SKILL_DEST}"
        echo ""
        echo "重新啟動 Claude Code 後即可使用。"
        ;;
    status)
        if [[ -f "${SKILL_DEST}/SKILL.md" ]]; then
            echo "✅ 已安裝：${SKILL_DEST}"
            # 顯示 skill 描述
            grep -A2 "^description:" "${SKILL_DEST}/SKILL.md" 2>/dev/null | head -3 || true
        else
            echo "❌ 尚未安裝"
            echo "執行 'kde claude-skill install' 來安裝"
        fi
        ;;
    *)
        echo "不支援的指令: ${COMMAND}"
        show_help
        exit 1
        ;;
esac
