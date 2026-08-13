#!/bin/bash
set -eo pipefail

# 安裝 Codex
# pipefail 不可省略：沒有它時 curl 失敗的退出碼會被末端的 sh 吞掉而回傳 0，
# entrypoint 會把安裝失敗誤判為成功。
curl -fsSL https://chatgpt.com/codex/install.sh | sh