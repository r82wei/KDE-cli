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
assert_true()  { local d="$1"; shift; if "$@" >/dev/null 2>&1; then check "${d}" 0; else check "${d}" 1; fi; }
assert_false() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then check "${d}" 1; else check "${d}" 0; fi; }

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

# --- CLI 自帶 skill 的唯讀掛載 ---
#
# 掛載目標刻意是 ~/.agents/skills 而不是 ~/.openclaw/skills：兩者都是 OpenClaw
# 會掃的全域 skill 根目錄（source 分別為 agents-skills-personal 與
# openclaw-managed），但後者是 OpenClaw 自己管的目錄 —— openclaw skills install
# --global 的安裝目標、update/uninstall 的操作對象。把唯讀掛載點放進那裡，
# 那些指令碰到它就會失敗。
#
# 掛哪些目錄是「掃出來」的而不是寫死 kde-usage：寫死的話，資料夾一改名或日後新增
# 第二個 skill，都會變成「skill 靜默不見」——而唯一的線索是使用者發現 agent 不懂
# kde 指令。掃 */SKILL.md 讓改名與新增都自動生效。
SKILLS_ROOT="${KDE_CLI_PATH}/.claude/skills"
SKILL_SRC="${SKILLS_ROOT}/kde-usage"
SKILL_MOUNT="-v ${SKILL_SRC}:/home/node/.agents/skills/kde-usage:ro"
SKILL_MOUNTPOINT="${KDE_PATH}/.openclaw-home/.agents/skills/kde-usage"

WARN=""
warn_has() { echo "${WARN}" | grep -q -- "$1"; }
assert_warns()  { if warn_has "$2"; then check "$1" 0; else check "$1" 1; fi; }
assert_silent() { if warn_has "$2"; then check "$1" 1; else check "$1" 0; fi; }

# 來源不存在（上面所有斷言都在這個狀態下跑）時不該掛：bind mount 的來源缺席時
# Docker 會自動建立它，於是在主機端的 CLI 安裝目錄裡多出一個空目錄，而 skill
# 依然不存在 —— 把「skill 沒裝到」變成「skill 沒裝到，還汙染了安裝目錄」。
assert_lacks "skill 來源不存在時不掛載" "${SKILL_MOUNT}"

# .openclaw-home 為空代表 home volume 還沒被掛載過。此時掛載點一旦建下去，
# Docker 首次掛載時的「把映像 /home/node 預先複製進來」就整個不會發生
# （預先複製只在目錄為空時觸發），因此這個狀態下刻意不掛也不建目錄。
mkdir -p "${SKILL_SRC}"; touch "${SKILL_SRC}/SKILL.md"
build_openclaw_docker_args
ARGS="${OPENCLAW_DOCKER_ARGS[*]}"
assert_lacks "home 尚未填充時不掛載（不破壞映像 home 的預先複製）" "${SKILL_MOUNT}"
assert_false "home 尚未填充時不建掛載點" test -d "${SKILL_MOUNTPOINT}"
# home 還沒填充是正常的一次性狀態，不是安裝壞掉，不該警告
WARN=$(build_openclaw_docker_args 2>&1 >/dev/null)
assert_silent "home 尚未填充時不警告" "SKILL.md"

# 模擬 home 已被填充過（第一個一次性狀態檢查容器跑完之後的狀態）
touch "${KDE_PATH}/.openclaw-home/.bashrc"
build_openclaw_docker_args
ARGS="${OPENCLAW_DOCKER_ARGS[*]}"
assert_has "掃到的 skill 以唯讀掛進 ~/.agents/skills" "${SKILL_MOUNT}"
# 掛載點必須由主機端先建好：Docker 代建的掛載點屬 root（發生在 entrypoint
# 降權之前），而它落在 .openclaw-home 裡 —— kde openclaw reset 是以主機使用者
# rm -rf 整個 .openclaw-home，遇到 root 所有的中間目錄會刪不掉（實測確認）。
assert_true "掛載點由主機端預先建立（reset 才刪得掉）" test -d "${SKILL_MOUNTPOINT}"
# 不是複製進容器 home：skill 內容講的是 kde 的旗標與流程，跟 CLI 版本強耦合，
# 複製一份就會在 CLI 升級後無聲過期
assert_lacks "不掛進 OpenClaw 自管的 managed skill 目錄" "/home/node/.openclaw/skills"

# 沒有頂層 SKILL.md 的目錄不該掛：.claude/skills 底下還有 kde-usage-workspace
# 這種 skill 開發/eval 資料目錄（716K），掛進去只是讓 OpenClaw 白掃一趟
mkdir -p "${SKILLS_ROOT}/kde-usage-workspace/iteration-1"
# 改名與新增都不該需要改程式碼
mkdir -p "${SKILLS_ROOT}/kde-renamed"; touch "${SKILLS_ROOT}/kde-renamed/SKILL.md"
build_openclaw_docker_args
ARGS="${OPENCLAW_DOCKER_ARGS[*]}"
assert_lacks "沒有頂層 SKILL.md 的目錄不掛載" "kde-usage-workspace"
assert_has "新增的 skill 自動掛載（名稱非寫死）" \
    "-v ${SKILLS_ROOT}/kde-renamed:/home/node/.agents/skills/kde-renamed:ro"
assert_has "多個 skill 並存時原有的仍掛載" "${SKILL_MOUNT}"
assert_true "新增 skill 的掛載點也預先建好" \
    test -d "${KDE_PATH}/.openclaw-home/.agents/skills/kde-renamed"

# 一個 SKILL.md 都掃不到（例如 local-install.sh 不再複製 .claude）時要出聲：
# 靜默失效的症狀是「agent 突然不懂 kde 指令」，那條線索太遠
rm -rf "${SKILLS_ROOT}/kde-usage" "${SKILLS_ROOT}/kde-renamed"
WARN=$(build_openclaw_docker_args 2>&1 >/dev/null)
assert_warns "掃不到任何 SKILL.md 時印警告" "SKILL.md"
build_openclaw_docker_args
ARGS="${OPENCLAW_DOCKER_ARGS[*]}"
assert_lacks "掃不到任何 SKILL.md 時不掛載" ".agents/skills"

rm -rf "${KDE_PATH}"

echo ""
echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
