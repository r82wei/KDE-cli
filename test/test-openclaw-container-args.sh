#!/bin/bash
set -eo pipefail

# 測試 build_openclaw_docker_args 組出的 docker run 參數

echo "===== kde openclaw 容器參數測試 ====="
echo ""

export KDE_PATH="/tmp/kde-test-openclaw"
export KDE_CLI_PATH="/tmp/kde-test-openclaw/cli"

rm -rf "${KDE_PATH}"
mkdir -p "${KDE_PATH}/cli"

source "$(dirname "${BASH_SOURCE[0]}")/../scripts/utils/openclaw.sh"

# stub：stat 固定回傳 docker.sock 的 gid
stat() { echo "999"; }

# stub docker：只記錄呼叫
DOCKER_LOG_FILE="${KDE_PATH}/docker.log"
: > "${DOCKER_LOG_FILE}"
docker() { echo "docker $*" >> "${DOCKER_LOG_FILE}"; return 0; }
logged() { grep -q -- "$1" "${DOCKER_LOG_FILE}"; }
assert_logged() { if logged "$2"; then check "$1" 0; else check "$1" 1; fi; }

TOTAL=0; PASS=0; FAIL=0
check() { # $1=描述 $2=條件結果(0/1)
    TOTAL=$((TOTAL+1))
    if [[ "$2" -eq 0 ]]; then echo "✅ $1"; PASS=$((PASS+1));
    else echo "❌ $1"; FAIL=$((FAIL+1)); fi
}

# 本檔開了 set -e，裸露的失敗 grep 會直接中止腳本，讓失敗變成「後面沒跑」
# 而不是「回報失敗」。所有斷言一律走這兩個 helper。
ARGS=""
has() { echo "${ARGS}" | grep -q -- "$1"; }
assert_has()   { if has "$2"; then check "$1" 0; else check "$1" 1; fi; }
assert_lacks() { if has "$2"; then check "$1" 1; else check "$1" 0; fi; }

# 以固定的 PUID/PGID 產生參數，讓斷言可預測
export PUID=1234
export PGID=5678
build_openclaw_docker_args
ARGS="${OPENCLAW_DOCKER_ARGS[*]}"

assert_has "workspace 以相同路徑掛載" "-v ${KDE_PATH}:${KDE_PATH}"
# 掛整個容器 home，而不是只掛 ~/.openclaw：OpenClaw 官方 docker 指引本身就是
# 「Full home volume」（OPENCLAW_HOME_VOLUME 持久化整個 /home/node），因為狀態
# 散落在 ~/.openclaw 之外的多處 —— .codex、.hermes、.claude、.claude.json、
# .config/openclaw（legacy OAuth 加密金鑰）、.agents、.local/share/claude、.npm、.cache。
# 逐個設環境變數覆寫是追不完的，每新增一個 provider plugin 就要再補一行。
# 用 local driver + o=bind 的 named volume 掛容器 home，而不是直接 bind mount：
# 兩者的內容都落在主機的 ${KDE_PATH}/.openclaw-home，差別在於 named volume 在
# 首次掛載（目錄為空）時，Docker 會把映像裡 /home/node 的內容預先複製進去。
# 直接 bind mount 空目錄則會把映像內容整個遮蔽掉，得自己補 dotfiles。
assert_has "以 named volume 掛容器 home" "-v openclaw-kde-test-openclaw-home:/home/node"
assert_lacks "不直接 bind mount home" "-v ${KDE_PATH}/.openclaw-home:/home/node"
assert_lacks "不再只掛 ~/.openclaw" "-v ${KDE_PATH}/.openclaw:/home/node/.openclaw"
assert_logged "會建立 home volume（create 本身冪等）" "volume create"
assert_logged "volume 以 o=bind 指向 workspace 的 .openclaw-home" "device=${KDE_PATH}/.openclaw-home"
# 實測（見 task-5-report.md Finding 1）確認 OpenClaw 的設定與 auth 密鑰全部落在
# ~/.openclaw/openclaw.json，~/.config/openclaw 從未被寫入，故不再掛載該路徑。
assert_lacks "不再掛載 ~/.config/openclaw（已確認未被使用）" "/home/node/.config/openclaw"
assert_has "kde-cli 以唯讀掛載覆蓋映像內建版本" "-v ${KDE_CLI_PATH}:/usr/local/lib/kde:ro"
assert_has "docker.sock 以唯讀掛載" "-v /var/run/docker.sock:/var/run/docker.sock:ro"
assert_has "帶入 docker.sock 的 gid" "--group-add 999"
assert_has "workdir 為 workspace 根目錄" "--workdir ${KDE_PATH}"
# codex 家目錄：OpenClaw 的 resolveCodexHome() 預設是 ~/.codex，落在掛載範圍外，
# 於 --rm 容器退出時會連同 OAuth 憑證一起消失。用官方支援的 CODEX_HOME 覆寫指回
# 掛載內，讓 codex 側的狀態跟其他狀態一樣留在 workspace，且仍在 reset 的清除範圍內。
# home 整個掛進來之後，~/.codex 本來就在掛載內，不再需要 CODEX_HOME 覆寫
assert_lacks "不需要 CODEX_HOME 覆寫（home 已整個掛載）" "CODEX_HOME"
assert_has "PUID 由環境變數帶入" "-e PUID=1234"
assert_has "PGID 由環境變數帶入" "-e PGID=5678"

# 共用參數不該含 port / 名稱 / restart policy，那些由各 action 自行附加
assert_lacks "共用參數不含 -p" "-p "
assert_lacks "共用參數不含 --restart" "--restart"
assert_lacks "共用參數不含 --name" "--name"

# 未設 PUID/PGID 時取主機的 id -u / id -g
unset PUID PGID
build_openclaw_docker_args
ARGS="${OPENCLAW_DOCKER_ARGS[*]}"
assert_has "未設 PUID 時取主機 id -u" "-e PUID=$(id -u)"
assert_has "未設 PGID 時取主機 id -g" "-e PGID=$(id -g)"

rm -rf "${KDE_PATH}"

echo ""
echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
