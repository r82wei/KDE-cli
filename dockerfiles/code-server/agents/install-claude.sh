#!/bin/bash
set -eo pipefail

# 安裝 Claude
# pipefail 不可省略：沒有它時 curl 失敗的退出碼會被末端的 bash 吞掉而回傳 0，
# entrypoint 會把安裝失敗誤判為成功。
curl -fsSL https://claude.ai/install.sh | bash