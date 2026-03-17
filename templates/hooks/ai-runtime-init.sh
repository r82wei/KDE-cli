#!/bin/bash
# KDE_HOOK_EXEC_MODE=direct

# AI Runtime 安裝腳本
# 用於 workspace 初始化時自動安裝 AI coding agent 所需的工具。
# 將此檔案複製到 <workspace>/hooks/workspace-init.sh 來啟用。

set -eux

echo "=== 安裝 AI Runtime 工具 ==="

# Node.js (Claude Code 依賴)
if ! command -v node &>/dev/null; then
    echo "安裝 Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Claude Code
if ! command -v claude &>/dev/null; then
    echo "安裝 Claude Code..."
    sudo npm install -g @anthropic-ai/claude-code
fi

# Python (Codex 依賴)
if ! command -v python3 &>/dev/null; then
    echo "安裝 Python3..."
    sudo apt-get update -qq
    sudo apt-get install -y python3 python3-pip python3-venv
fi

# 可選：Codex CLI
# if ! command -v codex &>/dev/null; then
#     echo "安裝 Codex CLI..."
#     pip3 install openai-codex
# fi

echo "=== AI Runtime 安裝完成 ==="
