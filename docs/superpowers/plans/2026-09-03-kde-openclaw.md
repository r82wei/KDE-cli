# kde openclaw 子命令 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增 `kde openclaw` 子命令，以容器承載 OpenClaw agent，容器內可直接操作 `kde` CLI，所有狀態留在 workspace 的 `.openclaw/`。

**Architecture:** 沿用 `kde code-server` 的兩層結構——`scripts/openclaw/command.sh` 只做參數解析與 action 分派，`scripts/utils/openclaw.sh` 承載全部邏輯並可被測試 source。三種容器（狀態檢查、onboard、gateway）共用同一個 `build_openclaw_docker_args()` 產出的掛載參數。映像改以官方 `ghcr.io/openclaw/openclaw` 為 base，疊加 kde-cli、docker CLI 與一支處理 PUID/PGID 的 entrypoint。

**Tech Stack:** Bash（`set -eo pipefail`）、Docker（DooD）、官方 OpenClaw 映像、`setpriv`（util-linux）。

**Spec:** `docs/superpowers/specs/2026-09-03-kde-openclaw-design.md`

## Global Constraints

- 程式碼註解與使用者訊息一律使用**繁體中文**（CLAUDE.md 的 Bash 慣例）。
- `kde.sh` 與 `scripts/` 底下所有檔案在 `set -eo pipefail` 下執行；`dockerfiles/` 的 build/release helper 不開。
- 被 `kde.sh` source 的檔案中，任何可能回傳非零的呼叫都必須用 `|| rc=$?` 承接，不可寫成 `cmd; rc=$?`。
- 函式命名：`is_*()` 回傳字串 `"true"`/`"false"`（不是退出碼）；`get_*()` 回傳值；`create_*()`/`start_*()`/`stop_*()` 為動作。
- 容器內 OpenClaw 使用者固定為 `node`，home 固定 `/home/node`（官方映像既定），只有 uid/gid 隨 `PUID`/`PGID` 變動。
- gateway 容器內部 port 恆為 `18789`；`-p` 只改主機側。
- 主機側 port 預設值 `18789`，**不寫入 `kde.env`**。
- `OPENCLAW_IMAGE` 預設值 `docker.io/r82wei/kde-openclaw:latest`，**要寫入 `kde.env`**。
- 容器名稱：`openclaw-<workspace 目錄名>`；onboard 容器為 `openclaw-<workspace 目錄名>-onboard`；狀態檢查容器不具名。
- 測試一律以 stub 掉 `docker` 的方式進行，不得真的啟動容器。
- 測試檔放 `test/`，執行方式 `bash test/<name>.sh`，自行印出通過/失敗統計並在失敗時 `exit 1`。
- **有開 `set -e` 的測試檔，斷言一律要包在 `if` 裡**（本計畫用 `assert_true` / `assert_false` / `assert_has` / `assert_lacks` 這類 helper）。裸露的 `grep -q ...` 或 `[[ ... ]]` 失敗時會直接中止整個腳本，結果是「後面的測試沒跑」而不是「回報失敗」——實測過，這會讓真正的迴歸被無聲吞掉。`test-openclaw-args.sh` 與 `test-openclaw-entrypoint.sh` 沒有開 `set -e`，故沿用既有的 `cmd; check "..." $?` 寫法即可。

---

### Task 1: 參數解析與容器命名

建立 `scripts/utils/openclaw.sh` 的骨架：說明文字、參數解析、容器名稱推導。這是後續所有任務的基礎。

**Files:**
- Create: `scripts/utils/openclaw.sh`
- Test: `test/test-openclaw-args.sh`

**Interfaces:**
- Consumes: 全域變數 `KDE_PATH`（由 `kde.sh:16-22` 設定，workspace 根目錄絕對路徑）
- Produces:
  - 常數 `OPENCLAW_PORT_DEFAULT=18789`、`OPENCLAW_CONTAINER_HOME=/home/node`
  - `show_openclaw_help()` → 印出說明，無回傳值
  - `parse_openclaw_args "$@"` → 回傳 `0`=成功 / `1`=參數錯誤 / `2`=已顯示說明應結束；回填全域變數 `OPENCLAW_ACTION`（`run|onboard|stop|exec|reset`）、`OPENCLAW_PORT`（數字字串）、`OPENCLAW_FORCE`（`true`/`false`）、`OPENCLAW_SHELL`（`true`/`false`）、`OPENCLAW_COMMAND`（字串，空字串代表未指定）
  - `get_openclaw_container_name()` → echo 容器名稱字串

- [ ] **Step 1: 寫下失敗的測試**

建立 `test/test-openclaw-args.sh`：

```bash
#!/bin/bash

# 測試 kde openclaw 的參數解析（parse_openclaw_args）與容器命名
# 比照 test/test-code-server-agent-args.sh 的模式

echo "===== kde openclaw 參數解析測試 ====="
echo ""

source "$(dirname "${BASH_SOURCE[0]}")/../scripts/utils/openclaw.sh"

TOTAL=0; PASS=0; FAIL=0

assert_eq() { # $1=描述 $2=預期 $3=實際
    TOTAL=$((TOTAL+1))
    if [[ "$3" == "$2" ]]; then
        echo "  ✅ $1：'$3'"; PASS=$((PASS+1))
    else
        echo "  ❌ $1：預期 '$2'，實際 '$3'"; FAIL=$((FAIL+1))
    fi
}

assert_rc() { # $1=描述 $2=預期退出碼 $3=實際退出碼
    TOTAL=$((TOTAL+1))
    if [[ "$3" == "$2" ]]; then
        echo "  ✅ $1：退出碼 $3"; PASS=$((PASS+1))
    else
        echo "  ❌ $1：預期退出碼 $2，實際 $3"; FAIL=$((FAIL+1))
    fi
}

echo "測試 1：五個 action 都能解析"
echo "--------------------"
for a in run onboard stop exec reset; do
    rc=0; parse_openclaw_args "${a}" >/dev/null 2>&1 || rc=$?
    assert_rc "action ${a} 退出碼為 0" 0 "${rc}"
    assert_eq "action ${a} 正確回填" "${a}" "${OPENCLAW_ACTION}"
done
echo ""

echo "測試 2：預設值"
echo "--------------------"
unset OPENCLAW_PORT
rc=0; parse_openclaw_args run || rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "PORT 預設為 18789" "18789" "${OPENCLAW_PORT}"
assert_eq "FORCE 預設為 false" "false" "${OPENCLAW_FORCE}"
assert_eq "SHELL 預設為 false" "false" "${OPENCLAW_SHELL}"
assert_eq "COMMAND 預設為空" "" "${OPENCLAW_COMMAND}"
echo ""

echo "測試 3：-p 覆寫 port"
echo "--------------------"
unset OPENCLAW_PORT
rc=0; parse_openclaw_args run -p 19000 || rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "PORT 為 19000" "19000" "${OPENCLAW_PORT}"

unset OPENCLAW_PORT
rc=0; parse_openclaw_args run --port 19001 || rc=$?
assert_eq "--port 長旗標同樣有效" "19001" "${OPENCLAW_PORT}"
echo ""

echo "測試 4：環境變數 OPENCLAW_PORT 生效，且 -p 優先"
echo "--------------------"
export OPENCLAW_PORT=20000
rc=0; parse_openclaw_args run || rc=$?
assert_eq "環境變數被採用" "20000" "${OPENCLAW_PORT}"

export OPENCLAW_PORT=20000
rc=0; parse_openclaw_args run -p 21000 || rc=$?
assert_eq "-p 優先於環境變數" "21000" "${OPENCLAW_PORT}"
unset OPENCLAW_PORT
echo ""

echo "測試 5：-p 非數字報錯"
echo "--------------------"
rc=0; parse_openclaw_args run -p abc >/dev/null 2>&1 || rc=$?
assert_rc "非數字 port 退出碼為 1" 1 "${rc}"

rc=0; parse_openclaw_args run -p >/dev/null 2>&1 || rc=$?
assert_rc "缺少 port 值退出碼為 1" 1 "${rc}"
echo ""

echo "測試 6：-f / -s / --command"
echo "--------------------"
rc=0; parse_openclaw_args reset -f || rc=$?
assert_eq "-f 設定 FORCE" "true" "${OPENCLAW_FORCE}"

rc=0; parse_openclaw_args reset --force || rc=$?
assert_eq "--force 設定 FORCE" "true" "${OPENCLAW_FORCE}"

rc=0; parse_openclaw_args exec -s || rc=$?
assert_eq "-s 設定 SHELL" "true" "${OPENCLAW_SHELL}"

rc=0; parse_openclaw_args exec --command "echo hi" || rc=$?
assert_eq "--command 正確回填" "echo hi" "${OPENCLAW_COMMAND}"
echo ""

echo "測試 7：-s 與 --command 互斥"
echo "--------------------"
rc=0; parse_openclaw_args exec -s --command "echo hi" >/dev/null 2>&1 || rc=$?
assert_rc "-s 與 --command 併用退出碼為 1" 1 "${rc}"
echo ""

echo "測試 8：說明與未知輸入"
echo "--------------------"
rc=0; parse_openclaw_args -h >/dev/null 2>&1 || rc=$?
assert_rc "-h 退出碼為 2" 2 "${rc}"

rc=0; parse_openclaw_args >/dev/null 2>&1 || rc=$?
assert_rc "無參數退出碼為 2" 2 "${rc}"

rc=0; parse_openclaw_args bogus >/dev/null 2>&1 || rc=$?
assert_rc "未知 action 退出碼為 1" 1 "${rc}"

rc=0; parse_openclaw_args run --bogus >/dev/null 2>&1 || rc=$?
assert_rc "未知旗標退出碼為 1" 1 "${rc}"
echo ""

echo "測試 9：容器名稱由 KDE_PATH 推導並清洗"
echo "--------------------"
KDE_PATH="/tmp/my-workspace" assert_eq "一般名稱" "openclaw-my-workspace" "$(KDE_PATH=/tmp/my-workspace get_openclaw_container_name)"
assert_eq "含空白的目錄名被清洗" "openclaw-my-ws" "$(KDE_PATH='/tmp/my ws' get_openclaw_container_name)"
assert_eq "含特殊字元的目錄名被清洗" "openclaw-a-b-c" "$(KDE_PATH='/tmp/a@b#c' get_openclaw_container_name)"
assert_eq "底線與點保留" "openclaw-a_b.c" "$(KDE_PATH='/tmp/a_b.c' get_openclaw_container_name)"
echo ""

echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `bash test/test-openclaw-args.sh`
Expected: FAIL — `scripts/utils/openclaw.sh: No such file or directory`

- [ ] **Step 3: 寫最小實作**

建立 `scripts/utils/openclaw.sh`：

```bash
#!/bin/bash

# kde openclaw 子命令的實作邏輯。
#
# 注意：本檔會被 scripts/openclaw/command.sh source，而該檔又被 kde.sh source，
# kde.sh 開了 set -eo pipefail，因此所有可能回傳非零的呼叫都必須用 `|| rc=$?`
# 或包在 if 條件中承接，不可裸呼叫。

# gateway 對外發布 port 的內建預設值。
# 刻意不寫進 kde.env：kde.env 是版控檔案，會隨 workspace 同步到每個人的機器上，
# 而 port 是每台開發機各自的環境條件，同步只會互相干擾。
OPENCLAW_PORT_DEFAULT=18789

# 容器內 OpenClaw 使用者的 home。官方映像的使用者是 node（uid 1000），
# 只有 uid/gid 會隨 PUID/PGID 變動，路徑本身固定。
OPENCLAW_CONTAINER_HOME=/home/node

# 顯示 kde openclaw 的使用說明
show_openclaw_help() {
    echo "usage: kde openclaw <action> [option]"
    echo ""
    echo "action:"
    echo "  run     [-p port]               背景常駐啟動 OpenClaw gateway"
    echo "  onboard [-f]                    執行初始化精靈 (一次性互動容器，不需 gateway 已啟動)"
    echo "  stop                            停止並移除 gateway 容器"
    echo "  exec    [-s] [--command <cmd>]  預設互動執行 openclaw；-s 進 bash；--command 非互動執行指令"
    echo "  reset   [-f]                    刪除 workspace 的 .openclaw (容器運行中則拒絕)"
    echo ""
    echo "option:"
    echo "  -p, --port      gateway 對外發布的 port (預設 ${OPENCLAW_PORT_DEFAULT}，亦可用環境變數 OPENCLAW_PORT)"
    echo "  -f, --force     略過確認提示"
    echo "  -s, --shell     exec 時進入 bash 而非 openclaw"
    echo "      --command   exec 時執行指定指令 (不配置 TTY)"
    echo "  -h, --help      顯示此幫助訊息"
}

# 解析 kde openclaw 的參數，結果回填到 OPENCLAW_* 全域變數
# 回傳 0=成功、1=參數錯誤、2=已顯示說明應結束
parse_openclaw_args() {
    OPENCLAW_ACTION=""
    # 環境變數有值就沿用，否則套用內建預設；-p 會在下面覆寫
    OPENCLAW_PORT="${OPENCLAW_PORT:-${OPENCLAW_PORT_DEFAULT}}"
    OPENCLAW_FORCE=false
    OPENCLAW_SHELL=false
    OPENCLAW_COMMAND=""

    if [[ $# -eq 0 ]]; then
        show_openclaw_help
        return 2
    fi

    case "$1" in
        -h|--help)
            show_openclaw_help
            return 2
            ;;
        run|onboard|stop|exec|reset)
            OPENCLAW_ACTION="$1"
            shift
            ;;
        *)
            echo "未知的 action：$1" >&2
            show_openclaw_help >&2
            return 1
            ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --port|-p)
                OPENCLAW_PORT="$2"
                if [[ -z "${OPENCLAW_PORT}" || ! ${OPENCLAW_PORT} =~ ^[0-9]+$ ]]; then
                    echo "無效的 port：$2" >&2
                    return 1
                fi
                shift 2
                ;;
            --force|-f)
                OPENCLAW_FORCE=true
                shift
                ;;
            --shell|-s)
                OPENCLAW_SHELL=true
                shift
                ;;
            --command)
                if [[ -z "$2" ]]; then
                    echo "錯誤：--command 需要一個指令參數" >&2
                    return 1
                fi
                OPENCLAW_COMMAND="$2"
                shift 2
                ;;
            --help|-h)
                show_openclaw_help
                return 2
                ;;
            *)
                echo "未知參數：$1" >&2
                show_openclaw_help >&2
                return 1
                ;;
        esac
    done

    # 一個需要 TTY、一個刻意不配置 TTY，無法同時成立
    # (與 scripts/utils/pipeline.sh 的 --shell + --no-tty 互斥同理)
    if [[ "${OPENCLAW_SHELL}" == "true" && -n "${OPENCLAW_COMMAND}" ]]; then
        echo "❌ 錯誤：-s/--shell 不能與 --command 一起使用 (一個需要 TTY，一個不需要)" >&2
        return 1
    fi

    return 0
}

# 由 KDE_PATH 的 basename 推導容器名稱
# 非 [a-zA-Z0-9_.-] 的字元一律換成 -，避免目錄名含空白時 docker run --name 失敗
get_openclaw_container_name() {
    local ws
    ws=$(basename "${KDE_PATH}")
    ws=$(echo "${ws}" | sed 's/[^a-zA-Z0-9_.-]/-/g')
    echo "openclaw-${ws}"
}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `bash test/test-openclaw-args.sh`
Expected: PASS —「🎉 全部通過」

- [ ] **Step 5: Commit**

```bash
git add scripts/utils/openclaw.sh test/test-openclaw-args.sh
git commit -m "feat(openclaw): 新增參數解析與容器命名"
```

---

### Task 2: 容器參數組裝

實作三種容器共用的 `docker run` 參數。這是唯一一處定義掛載的地方，避免三份複製漂移。

**Files:**
- Modify: `scripts/utils/openclaw.sh`（在 Task 1 的內容之後追加）
- Test: `test/test-openclaw-container-args.sh`

**Interfaces:**
- Consumes: `KDE_PATH`、`KDE_CLI_PATH`（`kde.sh:8` 設定，kde-cli 安裝根目錄）、`OPENCLAW_CONTAINER_HOME`（Task 1）
- Produces: `build_openclaw_docker_args()` → 回填全域陣列 `OPENCLAW_DOCKER_ARGS`（bash 陣列無法用回傳值傳遞，故用全域）

- [ ] **Step 1: 寫下失敗的測試**

建立 `test/test-openclaw-container-args.sh`：

```bash
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
assert_has ".openclaw 掛到容器 home" "-v ${KDE_PATH}/.openclaw:/home/node/.openclaw"
assert_has "auth 密鑰目錄掛到 ~/.config/openclaw" "-v ${KDE_PATH}/.openclaw/.config/openclaw:/home/node/.config/openclaw"
assert_has "kde-cli 以唯讀掛載覆蓋映像內建版本" "-v ${KDE_CLI_PATH}:/usr/local/lib/kde:ro"
assert_has "docker.sock 以唯讀掛載" "-v /var/run/docker.sock:/var/run/docker.sock:ro"
assert_has "帶入 docker.sock 的 gid" "--group-add 999"
assert_has "workdir 為 workspace 根目錄" "--workdir ${KDE_PATH}"
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
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `bash test/test-openclaw-container-args.sh`
Expected: FAIL — `build_openclaw_docker_args: command not found`

- [ ] **Step 3: 寫最小實作**

在 `scripts/utils/openclaw.sh` 末端追加：

```bash
# 組出三種容器（狀態檢查、onboard、gateway）共用的 docker run 參數。
# bash 陣列無法用回傳值傳遞，結果放在全域陣列 OPENCLAW_DOCKER_ARGS。
#
# 只放三者都需要的東西：掛載、身分、工作目錄。
# port、-d/-it、--name、--restart 由各 action 自行附加。
build_openclaw_docker_args() {
    # docker.sock 的 gid，用來 --group-add 讓容器內能操作 Docker。
    # 取法與 scripts/utils/code-server.sh 一致：Linux 用 stat -c，macOS 退回 stat -f。
    local sock_gid
    sock_gid=$( (stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock 2>/dev/null) ) || true

    local puid="${PUID:-$(id -u)}"
    local pgid="${PGID:-$(id -g)}"

    OPENCLAW_DOCKER_ARGS=(
        --workdir "${KDE_PATH}"
        -e "PUID=${puid}"
        -e "PGID=${pgid}"
        # workspace 以相同絕對路徑掛入，容器內外路徑一致
        -v "${KDE_PATH}:${KDE_PATH}"
        # .openclaw 同時出現在 workspace 路徑下與容器 home，是刻意的雙重掛載：
        # 讓 OpenClaw 讀 $HOME/.openclaw 時直接落在 workspace 裡
        -v "${KDE_PATH}/.openclaw:${OPENCLAW_CONTAINER_HOME}/.openclaw"
        # auth 密鑰另放 ~/.config/openclaw，收在 .openclaw 底下讓 reset 一次清乾淨
        -v "${KDE_PATH}/.openclaw/.config/openclaw:${OPENCLAW_CONTAINER_HOME}/.config/openclaw"
        -v "${KDE_CLI_PATH}:/usr/local/lib/kde:ro"
        -v /var/run/docker.sock:/var/run/docker.sock:ro
    )

    if [[ -n "${sock_gid}" ]]; then
        OPENCLAW_DOCKER_ARGS+=(--group-add "${sock_gid}")
    fi
}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `bash test/test-openclaw-container-args.sh`
Expected: PASS —「🎉 全部通過」

- [ ] **Step 5: 確認 Task 1 的測試沒被弄壞**

Run: `bash test/test-openclaw-args.sh`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add scripts/utils/openclaw.sh test/test-openclaw-container-args.sh
git commit -m "feat(openclaw): 組裝三種容器共用的 docker run 參數"
```

---

### Task 3: 生命週期實作

實作五個 action 的行為與所有前置檢查。這是功能的主體。

**Files:**
- Modify: `scripts/utils/openclaw.sh`（追加）
- Test: `test/test-openclaw-lifecycle.sh`

**Interfaces:**
- Consumes: Task 1 的 `get_openclaw_container_name()`、`OPENCLAW_ACTION`/`OPENCLAW_PORT`/`OPENCLAW_FORCE`/`OPENCLAW_SHELL`/`OPENCLAW_COMMAND`；Task 2 的 `build_openclaw_docker_args()` 與 `OPENCLAW_DOCKER_ARGS`；全域 `OPENCLAW_IMAGE`（Task 4 由 `kde.sh` 設定）
- Produces:
  - `is_openclaw_container_exist()` → echo `"true"`/`"false"`
  - `is_openclaw_container_running()` → echo `"true"`/`"false"`
  - `is_openclaw_onboarded()` → echo `"true"`/`"false"`
  - `onboard_openclaw()` → 回傳 0/1
  - `run_openclaw_gateway()` → 回傳 0/1
  - `exec_openclaw()` → 回傳 0/1
  - `stop_openclaw()` → 回傳 0
  - `reset_openclaw()` → 回傳 0/1

- [ ] **Step 1: 寫下失敗的測試**

建立 `test/test-openclaw-lifecycle.sh`：

```bash
#!/bin/bash
set -eo pipefail

# 測試 kde openclaw 各 action 的前置檢查與組出的 docker 指令
# 以 shell 函式 stub 掉 docker，不會真的啟動容器

echo "===== kde openclaw 生命週期測試 ====="
echo ""

export KDE_PATH="/tmp/kde-test-openclaw-lc"
export KDE_CLI_PATH="/tmp/kde-test-openclaw-lc/cli"
export OPENCLAW_IMAGE="kde-openclaw:test"

rm -rf "${KDE_PATH}"
mkdir -p "${KDE_PATH}/cli"

source "$(dirname "${BASH_SOURCE[0]}")/../scripts/utils/openclaw.sh"

stat() { echo "999"; }

# 健康檢查的等待秒數在測試中歸零，避免每個 run 測試都空等
export OPENCLAW_HEALTH_WAIT=0

# 可調整的 stub 狀態
STUB_EXISTING=""      # docker ps -a 回傳的容器名
STUB_RUNNING=""       # docker ps 回傳的容器名
STUB_MODE=""          # openclaw config get gateway.mode 的輸出
STUB_MODE_AFTER=""    # onboard 跑完之後 config get 改為回傳這個值（空字串代表不變）
STUB_INSPECT="true"   # docker inspect -f '{{.State.Running}}' 的輸出

# docker 呼叫記錄一定要寫進「檔案」而不是變數：
# is_openclaw_onboarded 是用 mode=$(docker run ...) 取值的，stub 對變數的
# 累加發生在該命令替換的子 shell 裡，回到父 shell 就消失了。
DOCKER_LOG_FILE="${KDE_PATH}/docker.log"
: > "${DOCKER_LOG_FILE}"

docker() {
    echo "docker $*" >> "${DOCKER_LOG_FILE}"
    case "$1" in
        ps)
            if [[ "$*" == *"-a"* ]]; then
                [[ -n "${STUB_EXISTING}" ]] && echo "${STUB_EXISTING}"
            else
                [[ -n "${STUB_RUNNING}" ]] && echo "${STUB_RUNNING}"
            fi
            return 0
            ;;
        run)
            # 狀態檢查容器：印出 gateway.mode
            if [[ "$*" == *"config get gateway.mode"* ]]; then
                echo "${STUB_MODE}"
            fi
            # onboard 容器跑完後切換 mode，模擬精靈寫入設定
            if [[ "$*" == *"onboard --mode local"* && -n "${STUB_MODE_AFTER}" ]]; then
                STUB_MODE="${STUB_MODE_AFTER}"
            fi
            return 0
            ;;
        inspect) echo "${STUB_INSPECT}"; return 0 ;;
        *) return 0 ;;
    esac
}

TOTAL=0; PASS=0; FAIL=0
check() { # $1=描述 $2=條件結果(0/1)
    TOTAL=$((TOTAL+1))
    if [[ "$2" -eq 0 ]]; then echo "✅ $1"; PASS=$((PASS+1));
    else echo "❌ $1"; FAIL=$((FAIL+1)); fi
}

# 本檔開了 set -e，裸露的失敗指令（grep、[[ ]]）會直接中止腳本，
# 讓失敗變成「後面測試沒跑」而不是「回報失敗」。所有斷言一律走這兩個
# helper，它們把待測條件放進 if 裡，永遠回傳 0。
assert_true()  { local d="$1"; shift; if "$@" >/dev/null 2>&1; then check "$d" 0; else check "$d" 1; fi; }
assert_false() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then check "$d" 1; else check "$d" 0; fi; }

logged()  { grep -q -- "$1" "${DOCKER_LOG_FILE}"; }   # docker 呼叫記錄中有某段字串
out_has() { echo "${OUT}" | grep -q -- "$1"; }        # 上一次擷取的輸出中有某段字串
onboarded_is() { [[ "$(is_openclaw_onboarded)" == "$1" ]]; }

reset_stub() {
    STUB_EXISTING=""; STUB_RUNNING=""; STUB_MODE=""; STUB_MODE_AFTER=""
    STUB_INSPECT="true"; : > "${DOCKER_LOG_FILE}"; OUT=""
    OPENCLAW_FORCE=false; OPENCLAW_SHELL=false; OPENCLAW_COMMAND=""
    OPENCLAW_PORT=18789
}

NAME="openclaw-kde-test-openclaw-lc"

echo "--- is_openclaw_onboarded ---"
reset_stub; STUB_MODE="local"
assert_true "gateway.mode 為 local 時回傳 true" onboarded_is true

reset_stub; STUB_MODE="remote"
assert_true "gateway.mode 非 local 時回傳 false" onboarded_is false

reset_stub; STUB_MODE=""
assert_true "gateway.mode 為空時回傳 false" onboarded_is false

reset_stub; STUB_MODE="  local  "
assert_true "輸出含空白時仍能判斷" onboarded_is true

reset_stub; STUB_MODE="local"
is_openclaw_onboarded >/dev/null
assert_true  "狀態檢查以一次性容器執行" logged "--rm"
assert_true  "狀態檢查查詢 gateway.mode" logged "config get gateway.mode"
assert_false "狀態檢查容器不具名" logged "--name"
echo ""

echo "--- run ---"
reset_stub; STUB_EXISTING="${NAME}"; STUB_MODE="local"
assert_false "同名容器已存在時 run 報錯" run_openclaw_gateway

reset_stub; STUB_MODE="remote"
assert_false "未初始化時 run 報錯" run_openclaw_gateway

reset_stub; STUB_MODE="remote"
OUT=$(run_openclaw_gateway 2>&1 || true)
assert_true  "未初始化的錯誤訊息指向 onboard" out_has "kde openclaw onboard"
assert_false "run 不自動代跑 onboarding" logged "onboard --mode local"

reset_stub; STUB_MODE="local"
run_openclaw_gateway >/dev/null 2>&1
assert_true "已初始化時以背景模式啟動" logged "-d --name ${NAME}"
assert_true "帶 restart policy" logged "--restart unless-stopped"
assert_true "發布預設 port" logged "-p 18789:18789"
assert_true "容器內 port 固定為 18789" logged "openclaw gateway run --port 18789"

reset_stub; STUB_MODE="local"; OPENCLAW_PORT=19000
run_openclaw_gateway >/dev/null 2>&1
assert_true "-p 只改主機側 port" logged "-p 19000:18789"
assert_true "-p 不影響容器內 port" logged "openclaw gateway run --port 18789"

reset_stub; STUB_MODE="local"; STUB_INSPECT="false"
assert_false "健康檢查失敗時 run 回報失敗" run_openclaw_gateway
assert_true  "健康檢查失敗時印出容器日誌" logged "logs --tail 50"
echo ""

echo "--- onboard ---"
reset_stub; STUB_EXISTING="${NAME}-onboard"
assert_false "同名 onboard 容器已存在時報錯" onboard_openclaw

reset_stub; STUB_MODE=""; STUB_MODE_AFTER="local"
onboard_openclaw >/dev/null 2>&1
assert_true  "onboard 以互動一次性容器執行" logged "-it --rm --name ${NAME}-onboard"
assert_true  "onboard 指令帶 --mode local" logged "openclaw onboard --mode local"
assert_false "onboard 容器不發布 port" logged "-p "

reset_stub; STUB_MODE=""; STUB_MODE_AFTER=""
assert_false "精靈結束後 mode 仍非 local 時報錯" onboard_openclaw

reset_stub; STUB_MODE="local"; STUB_MODE_AFTER="local"; OPENCLAW_FORCE=true
onboard_openclaw >/dev/null 2>&1
assert_true "已初始化時 -f 直接重跑不詢問" logged "onboard --mode local"
echo ""

echo "--- exec ---"
reset_stub; STUB_RUNNING=""
assert_false "容器未運行時 exec 報錯" exec_openclaw

reset_stub; STUB_RUNNING=""
OUT=$(exec_openclaw 2>&1 || true)
assert_true "exec 的錯誤訊息指向 run" out_has "kde openclaw run"

reset_stub; STUB_RUNNING="${NAME}"
exec_openclaw >/dev/null 2>&1
assert_true "預設互動執行 openclaw" logged "exec -it ${NAME} openclaw"

reset_stub; STUB_RUNNING="${NAME}"; OPENCLAW_SHELL=true
exec_openclaw >/dev/null 2>&1
assert_true "-s 進入 bash" logged "exec -it ${NAME} bash"

reset_stub; STUB_RUNNING="${NAME}"; OPENCLAW_COMMAND="openclaw gateway auth-token"
exec_openclaw >/dev/null 2>&1
assert_true  "--command 執行指定指令" logged "exec ${NAME} bash -c openclaw gateway auth-token"
assert_false "--command 不配置 TTY" logged "exec -it"
echo ""

echo "--- stop ---"
reset_stub; STUB_EXISTING=""
assert_true "容器不存在時 stop 仍回傳 0（冪等）" stop_openclaw

reset_stub; STUB_EXISTING="${NAME}"
stop_openclaw >/dev/null 2>&1
assert_true "stop 會停止容器" logged "stop ${NAME}"
assert_true "stop 會移除容器" logged "rm ${NAME}"
echo ""

echo "--- reset ---"
reset_stub; STUB_RUNNING="${NAME}"; mkdir -p "${KDE_PATH}/.openclaw"
assert_false "容器運行中時 reset 拒絕" reset_openclaw
assert_true  "拒絕時未刪除任何東西" test -d "${KDE_PATH}/.openclaw"

reset_stub; STUB_RUNNING=""; OPENCLAW_FORCE=true
mkdir -p "${KDE_PATH}/.openclaw/workspace"
reset_openclaw >/dev/null 2>&1
assert_false "-f 時直接刪除 .openclaw" test -d "${KDE_PATH}/.openclaw"

reset_stub; STUB_RUNNING=""; OPENCLAW_FORCE=true
assert_true ".openclaw 不存在時 reset 回傳 0" reset_openclaw
echo ""

rm -rf "${KDE_PATH}"

echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `bash test/test-openclaw-lifecycle.sh`
Expected: FAIL — `is_openclaw_onboarded: command not found`

- [ ] **Step 3: 寫最小實作**

在 `scripts/utils/openclaw.sh` 末端追加：

```bash
# 容器是否存在（含已停止者）
is_openclaw_container_exist() {
    if docker ps -a --format '{{.Names}}' | grep -qx "$(get_openclaw_container_name)"; then
        echo "true"
    else
        echo "false"
    fi
}

# 容器是否正在運行
is_openclaw_container_running() {
    if docker ps --format '{{.Names}}' | grep -qx "$(get_openclaw_container_name)"; then
        echo "true"
    else
        echo "false"
    fi
}

# OpenClaw 是否已完成初始化。
#
# 判斷方式是在一次性容器內問 OpenClaw 自己「gateway.mode 是什麼」，
# 而不是看 .openclaw 目錄存不存在或是否為空。理由：
#   1. bind mount 會讓 Docker 自動建立不存在的 host 目錄，跑過任何一次 action
#      之後目錄必然存在，「存在與否」完全沒有鑑別力。
#   2. 目錄非空也不代表可用——onboarding 中途 Ctrl-C 會留下半成品 config，
#      gateway run 依然會拒絕啟動。
# gateway.mode=local 正是 openclaw gateway run 唯一在意的條件。
is_openclaw_onboarded() {
    build_openclaw_docker_args
    local mode
    mode=$(docker run --rm "${OPENCLAW_DOCKER_ARGS[@]}" "${OPENCLAW_IMAGE}" \
             openclaw config get gateway.mode 2>/dev/null | tr -d '[:space:]') || true
    if [[ "${mode}" == "local" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# 執行初始化精靈。走一次性互動容器，不依賴 gateway 已在運行——
# 未初始化時 gateway run 會拒絕啟動，若要求使用者先 run 就會變成死結。
onboard_openclaw() {
    local name onboard_name
    name=$(get_openclaw_container_name)
    onboard_name="${name}-onboard"

    if docker ps -a --format '{{.Names}}' | grep -qx "${onboard_name}"; then
        echo "❌ 容器 ${onboard_name} 已存在，請先移除：docker rm -f ${onboard_name}"
        return 1
    fi

    if [[ "$(is_openclaw_onboarded)" == "true" && "${OPENCLAW_FORCE}" != "true" ]]; then
        echo "⚠️  OpenClaw 已初始化，重跑精靈會覆寫現有設定"
        read -p "確定要繼續嗎？(y/n) " answer
        if [[ "${answer}" != "y" ]]; then
            echo "已取消"
            return 0
        fi
    fi

    build_openclaw_docker_args
    # 精靈被 Ctrl-C 中斷會回傳非零，不當成錯誤：下面統一以 gateway.mode 驗證結果
    docker run -it --rm --name "${onboard_name}" \
        "${OPENCLAW_DOCKER_ARGS[@]}" \
        "${OPENCLAW_IMAGE}" \
        openclaw onboard --mode local || true

    if [[ "$(is_openclaw_onboarded)" != "true" ]]; then
        echo "❌ 初始化未完成 (gateway.mode 仍不是 local)"
        return 1
    fi

    echo "✓ OpenClaw 初始化完成，可執行：kde openclaw run"
}

# 背景常駐啟動 gateway
run_openclaw_gateway() {
    local name
    name=$(get_openclaw_container_name)

    if [[ "$(is_openclaw_container_exist)" == "true" ]]; then
        echo "❌ 容器 ${name} 已存在，請先停止：kde openclaw stop"
        return 1
    fi

    if [[ "$(is_openclaw_onboarded)" != "true" ]]; then
        echo "❌ OpenClaw 尚未初始化 (gateway.mode 不是 local)"
        echo "   請先執行：kde openclaw onboard"
        return 1
    fi

    build_openclaw_docker_args
    docker run -d --name "${name}" \
        --restart unless-stopped \
        -p "${OPENCLAW_PORT}:18789" \
        "${OPENCLAW_DOCKER_ARGS[@]}" \
        "${OPENCLAW_IMAGE}" \
        openclaw gateway run --port 18789

    # 健康檢查：gateway 設定不完整時容器會立刻退出，背景模式下使用者看不到，
    # 因此這裡主動確認並把日誌吐出來，而不是回報成功。
    # 等待秒數開放覆寫，是為了讓測試不必空等。
    sleep "${OPENCLAW_HEALTH_WAIT:-3}"
    local state
    state=$(docker inspect -f '{{.State.Running}}' "${name}" 2>/dev/null) || true
    if [[ "${state}" != "true" ]]; then
        echo "❌ gateway 啟動失敗，以下為容器日誌："
        docker logs --tail 50 "${name}" || true
        return 1
    fi

    echo "✓ openclaw gateway 已在背景啟動 (${name})"
    echo "存取網址: http://localhost:${OPENCLAW_PORT}"
    echo "查看日誌: docker logs -f ${name}"
    echo "取得 token: kde openclaw exec --command \"openclaw gateway auth-token\""
    echo "停止服務: kde openclaw stop"
}

# 進入容器。預設直接跑 openclaw——這個容器存在的理由就是跑 OpenClaw agent，
# 讓最常見的操作不需要旗標；要純 shell 用 -s。
exec_openclaw() {
    local name
    name=$(get_openclaw_container_name)

    if [[ "$(is_openclaw_container_running)" != "true" ]]; then
        echo "❌ 容器 ${name} 未在運行，請先執行：kde openclaw run"
        return 1
    fi

    if [[ -n "${OPENCLAW_COMMAND}" ]]; then
        docker exec "${name}" bash -c "${OPENCLAW_COMMAND}"
    elif [[ "${OPENCLAW_SHELL}" == "true" ]]; then
        docker exec -it "${name}" bash
    else
        docker exec -it "${name}" openclaw
    fi
}

# 停止並移除容器。容器本身是可拋棄的，狀態全在 workspace 的 .openclaw 裡。
stop_openclaw() {
    local name
    name=$(get_openclaw_container_name)

    if [[ "$(is_openclaw_container_exist)" != "true" ]]; then
        echo "容器 ${name} 不存在，無需停止"
        return 0
    fi

    docker stop "${name}" >/dev/null
    docker rm "${name}" >/dev/null
    echo "✓ 已停止並移除容器 ${name}"
}

# 刪除 workspace 的 .openclaw（含 auth 密鑰）
reset_openclaw() {
    local name openclaw_dir
    name=$(get_openclaw_container_name)
    openclaw_dir="${KDE_PATH}/.openclaw"

    # 不在容器運行中抽掉設定，避免產生難以診斷的半死狀態
    if [[ "$(is_openclaw_container_running)" == "true" ]]; then
        echo "❌ 容器 ${name} 仍在運行，請先執行：kde openclaw stop"
        return 1
    fi

    if [[ ! -d "${openclaw_dir}" ]]; then
        echo "${openclaw_dir} 不存在，無需重設"
        return 0
    fi

    if [[ "${OPENCLAW_FORCE}" != "true" ]]; then
        echo "⚠️  將刪除 ${openclaw_dir} (含 OpenClaw 設定與 auth 密鑰)"
        read -p "確定要繼續嗎？(y/n) " answer
        if [[ "${answer}" != "y" ]]; then
            echo "已取消"
            return 0
        fi
    fi

    rm -rf "${openclaw_dir}"
    echo "✓ 已刪除 ${openclaw_dir}"
}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `bash test/test-openclaw-lifecycle.sh`
Expected: PASS —「🎉 全部通過」

- [ ] **Step 5: 執行前兩支測試確認沒被弄壞**

Run: `bash test/test-openclaw-args.sh && bash test/test-openclaw-container-args.sh`
Expected: 兩支都 PASS

- [ ] **Step 6: Commit**

```bash
git add scripts/utils/openclaw.sh test/test-openclaw-lifecycle.sh
git commit -m "feat(openclaw): 實作 run/onboard/stop/exec/reset 生命週期"
```

---

### Task 4: CLI 接線

把 utils 接到 `kde` 指令上：新增 `command.sh` 薄路由、`kde.sh` 的 `OPENCLAW_IMAGE` 預設值與 case 分支。

**Files:**
- Create: `scripts/openclaw/command.sh`
- Modify: `kde.sh`（`show_help()` 內約第 63 行後、預設 image 區塊約第 165-168 行後、主 case 區塊約第 304-307 行後）

**Interfaces:**
- Consumes: Task 1-3 的所有函式與 `OPENCLAW_*` 全域變數
- Produces: `kde openclaw <action>` 可執行；全域 `OPENCLAW_IMAGE` 由 `kde.sh` 設定

- [ ] **Step 1: 建立 command.sh**

建立 `scripts/openclaw/command.sh`：

```bash
#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/openclaw.sh

# 注意：本檔是被 kde.sh source 進去的，而 kde.sh 開了 set -e，
# 因此必須用 `|| rc=$?` 承接非零回傳，不可寫成 `parse...; rc=$?`
rc=0
parse_openclaw_args "$@" || rc=$?

if [[ ${rc} -eq 2 ]]; then
    exit 0
fi
if [[ ${rc} -ne 0 ]]; then
    exit 1
fi

case "${OPENCLAW_ACTION}" in
    run)
        run_openclaw_gateway
        ;;
    onboard)
        onboard_openclaw
        ;;
    stop)
        stop_openclaw
        ;;
    exec)
        exec_openclaw
        ;;
    reset)
        reset_openclaw
        ;;
esac
```

- [ ] **Step 2: 在 kde.sh 加入 OPENCLAW_IMAGE 預設值**

在 `kde.sh` 的 `CODE_SERVER_IMAGE` 區塊（約第 165-168 行）之後插入：

```bash
if [[ -z ${OPENCLAW_IMAGE} ]]; then
    export OPENCLAW_IMAGE=docker.io/r82wei/kde-openclaw:latest
    echo "OPENCLAW_IMAGE=${OPENCLAW_IMAGE}" >> ${KDE_ENV_FILE}
fi
```

**不要**在此處加 `OPENCLAW_PORT`——port 刻意不寫進版控的 `kde.env`（見 spec 的「環境變數」一節）。

- [ ] **Step 3: 在 kde.sh 加入 case 路由**

在主 case 區塊的 `code-server)` 分支（約第 304-307 行）之後插入：

```bash
    openclaw)
        shift  # 移除 "openclaw" 指令
        source ${KDE_SCRIPTS_PATH}/openclaw/command.sh
        ;;
```

- [ ] **Step 4: 在 kde.sh 的 show_help() 加入一行摘要**

在 `code-server` 那一行（約第 63 行）之後插入：

```bash
    echo "  openclaw <run|onboard|stop|exec|reset>              以容器啟動 OpenClaw agent，可在容器內使用 kde CLI (可以使用 kde openclaw -h 查看詳細說明)"
```

- [ ] **Step 5: 驗證說明可正常顯示**

Run: `bash kde.sh openclaw -h`
Expected: 印出 Task 1 的 `show_openclaw_help()` 內容（action 與 option 兩段），退出碼 0

Run: `bash kde.sh -h | grep openclaw`
Expected: 顯示 Step 4 加入的那行摘要

- [ ] **Step 6: 驗證未知 action 會報錯**

Run: `bash kde.sh openclaw bogus; echo "rc=$?"`
Expected: 印出「未知的 action：bogus」與說明，`rc=1`

- [ ] **Step 7: 執行三支測試確認沒被弄壞**

Run: `bash test/test-openclaw-args.sh && bash test/test-openclaw-container-args.sh && bash test/test-openclaw-lifecycle.sh`
Expected: 三支都 PASS

- [ ] **Step 8: Commit**

```bash
git add scripts/openclaw/command.sh kde.sh
git commit -m "feat(openclaw): 接上 kde CLI 路由與 OPENCLAW_IMAGE 預設值"
```

---

### Task 5: 映像改寫與 entrypoint

改寫 `dockerfiles/kde-openclaw/`：base 換成官方 OpenClaw 映像，疊加 kde-cli 與 docker CLI，新增處理 PUID/PGID 的 entrypoint。現有 Dockerfile 是壞的（`FROM ubuntu:24.04` 但沒有 `curl`），本任務一併修好。

**Files:**
- Modify: `dockerfiles/kde-openclaw/Dockerfile`（整份改寫）
- Create: `dockerfiles/kde-openclaw/entrypoint.sh`
- Modify: `dockerfiles/kde-openclaw/build.sh`
- Modify: `dockerfiles/kde-openclaw/release.sh`
- Test: `test/test-openclaw-entrypoint.sh`

**Interfaces:**
- Consumes: `local-install.sh`（repo 根目錄，安裝 kde-cli 的唯一真實來源）
- Produces: 映像 `r82wei/kde-openclaw:<tag>`，其 entrypoint 接受 `PUID`/`PGID` 環境變數與 `OPENCLAW_HOME_DIR`（測試用覆寫，預設 `/home/node`）

- [ ] **Step 1: 寫下 entrypoint 的失敗測試**

建立 `test/test-openclaw-entrypoint.sh`：

```bash
#!/bin/bash

# 測試 dockerfiles/kde-openclaw/entrypoint.sh 的 PUID/PGID 行為
# 以假的 PATH 攔截 groupmod/usermod/chown/setpriv，不會真的改動任何使用者

echo "===== kde-openclaw entrypoint 測試 ====="
echo ""

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/dockerfiles/kde-openclaw/entrypoint.sh"
TMP_ROOT="/tmp/kde-test-openclaw-entrypoint"

TOTAL=0; PASS=0; FAIL=0
check() { # $1=描述 $2=條件結果(0/1)
    TOTAL=$((TOTAL+1))
    if [[ "$2" -eq 0 ]]; then echo "✅ $1"; PASS=$((PASS+1));
    else echo "❌ $1"; FAIL=$((FAIL+1)); fi
}

# 建立假的 PATH：groupmod / usermod / chown / setpriv 只記錄呼叫參數
setup() {
    rm -rf "${TMP_ROOT}"
    mkdir -p "${TMP_ROOT}/bin" "${TMP_ROOT}/home"
    local b
    for b in groupmod usermod chown setpriv; do
        cat > "${TMP_ROOT}/bin/${b}" <<EOS
#!/bin/bash
echo "${b} \$*" >> "${TMP_ROOT}/calls.log"
EOS
        chmod +x "${TMP_ROOT}/bin/${b}"
    done
}

run_entrypoint() { # $@ = 環境變數指定方式由呼叫端 export
    PATH="${TMP_ROOT}/bin:${PATH}" OPENCLAW_HOME_DIR="${TMP_ROOT}/home" \
        bash "${SCRIPT}" openclaw gateway run >/dev/null 2>&1
}

echo "測試 1：PUID/PGID 皆為 1000 時不重映射"
setup
PUID=1000 PGID=1000 run_entrypoint
grep -q "usermod" "${TMP_ROOT}/calls.log" && r=1 || r=0
check "未呼叫 usermod" $r
grep -q "groupmod" "${TMP_ROOT}/calls.log" && r=1 || r=0
check "未呼叫 groupmod" $r
echo ""

echo "測試 2：未設 PUID/PGID 時視為 1000"
setup
run_entrypoint
grep -q "usermod" "${TMP_ROOT}/calls.log" && r=1 || r=0
check "未呼叫 usermod" $r
echo ""

echo "測試 3：PUID 非 1000 時重映射"
setup
PUID=1234 PGID=1000 run_entrypoint
grep -q "usermod -u 1234 node" "${TMP_ROOT}/calls.log"
check "以正確參數呼叫 usermod" $?
grep -q "groupmod" "${TMP_ROOT}/calls.log" && r=1 || r=0
check "PGID 仍為 1000 時不呼叫 groupmod" $r
echo ""

echo "測試 4：PGID 非 1000 時重映射"
setup
PUID=1000 PGID=5678 run_entrypoint
grep -q "groupmod -g 5678 node" "${TMP_ROOT}/calls.log"
check "以正確參數呼叫 groupmod" $?
echo ""

echo "測試 5：chown 只碰 home 與兩個狀態目錄，不遞迴 workspace"
setup
PUID=1234 PGID=5678 run_entrypoint
grep -q "chown 1234:5678 ${TMP_ROOT}/home ${TMP_ROOT}/home/.openclaw ${TMP_ROOT}/home/.config/openclaw" "${TMP_ROOT}/calls.log"
check "chown 目標為 home 與兩個狀態目錄" $?
grep -qE "chown.* -R" "${TMP_ROOT}/calls.log" && r=1 || r=0
check "未使用遞迴 chown" $r
echo ""

echo "測試 6：以 setpriv 降權並把原指令接下去"
setup
PUID=1234 PGID=5678 run_entrypoint
grep -q "setpriv --reuid 1234 --regid 5678 --init-groups --inh-caps=-all openclaw gateway run" "${TMP_ROOT}/calls.log"
check "setpriv 參數與轉交的指令皆正確" $?
echo ""

echo "測試 7：狀態目錄會被建立"
setup
PUID=1000 PGID=1000 run_entrypoint
[[ -d "${TMP_ROOT}/home/.openclaw" && -d "${TMP_ROOT}/home/.config/openclaw" ]]
check "建立 .openclaw 與 .config/openclaw" $?
echo ""

rm -rf "${TMP_ROOT}"

echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `bash test/test-openclaw-entrypoint.sh`
Expected: FAIL — 找不到 `dockerfiles/kde-openclaw/entrypoint.sh`

- [ ] **Step 3: 寫 entrypoint.sh**

建立 `dockerfiles/kde-openclaw/entrypoint.sh`：

```bash
#!/bin/bash

# kde-openclaw 容器的 entrypoint，以 root 進入、降權後把控制權交給實際指令。
#
# 刻意使用 set -e：這裡每一步（使用者重映射、目錄建立、chown）失敗都代表
# 容器之後必然會出權限問題，繼續執行只會把錯誤延後到更難診斷的地方。
# 這與 dockerfiles/code-server/entrypoint.d/10-ai-agents.sh 的取捨相反——
# 那支是「單一 agent 安裝失敗不該擋住 code-server 啟動」，這支沒有那種餘裕。
set -e

# 官方 OpenClaw 映像的使用者是 node，uid/gid 皆為 1000
PUID=${PUID:-1000}
PGID=${PGID:-1000}

# 容器內 home。正式執行時固定為 /home/node，開放覆寫是為了讓測試不需要 root。
OPENCLAW_HOME_DIR=${OPENCLAW_HOME_DIR:-/home/node}

# 只在 uid/gid 與映像內建值不同時才重映射，多數情況（主機使用者也是 1000）完全不動
if [[ "${PGID}" != "1000" ]]; then
    groupmod -g "${PGID}" node
fi
if [[ "${PUID}" != "1000" ]]; then
    usermod -u "${PUID}" node
fi

mkdir -p "${OPENCLAW_HOME_DIR}/.openclaw" "${OPENCLAW_HOME_DIR}/.config/openclaw"

# 只 chown home 與 OpenClaw 的兩個狀態目錄。
# 絕不遞迴 chown 掛進來的 workspace：那可能很大，而且會改動主機端檔案的擁有者。
chown "${PUID}:${PGID}" \
    "${OPENCLAW_HOME_DIR}" \
    "${OPENCLAW_HOME_DIR}/.openclaw" \
    "${OPENCLAW_HOME_DIR}/.config/openclaw"

# 用 setpriv 而非 gosu/sudo：util-linux 內建、零額外套件，
# 且 exec 取代自身，降權後的行程直接成為 tini 的子行程並承接訊號。
exec setpriv --reuid "${PUID}" --regid "${PGID}" --init-groups --inh-caps=-all "$@"
```

- [ ] **Step 4: 執行測試確認通過**

Run: `bash test/test-openclaw-entrypoint.sh`
Expected: PASS —「🎉 全部通過」

- [ ] **Step 5: Commit entrypoint**

```bash
chmod +x dockerfiles/kde-openclaw/entrypoint.sh
git add dockerfiles/kde-openclaw/entrypoint.sh test/test-openclaw-entrypoint.sh
git commit -m "feat(kde-openclaw): 新增處理 PUID/PGID 的 entrypoint"
```

- [ ] **Step 6: 確認官方映像的 tini 絕對路徑**

Run: `docker pull ghcr.io/openclaw/openclaw:latest && docker inspect -f '{{json .Config.Entrypoint}}' ghcr.io/openclaw/openclaw:latest`
Expected: 輸出中含 tini 的絕對路徑（預期為 `/usr/bin/tini`）。**若不是 `/usr/bin/tini`，Step 7 的 `ENTRYPOINT` 要改用實際路徑。**

- [ ] **Step 7: 改寫 Dockerfile**

以下列內容整份覆蓋 `dockerfiles/kde-openclaw/Dockerfile`（`tini` 路徑用 Step 6 確認到的實際值）：

```dockerfile
# OPENCLAW_VERSION 是官方映像的 tag，升級 OpenClaw 等於換 tag。
ARG OPENCLAW_VERSION=latest
FROM ghcr.io/openclaw/openclaw:${OPENCLAW_VERSION}

USER root

# kde-cli 在容器內執行時需要的外部指令：
#   docker   - DooD，kde 的核心
#   git      - kde proj fetch/pull 直接在本機執行
#   envsubst - 渲染 kind/k3d config 模板 (gettext-base)
# kubectl 與 helm 不需要:那些都是丟進 deploy-env 容器裡跑的。
RUN apt-get update && apt-get install -y --no-install-recommends \
      git gettext-base ca-certificates docker.io \
 && rm -rf /var/lib/apt/lists/*

# 安裝 kde-cli:把 build context(repo 根目錄)整包複製進來,交給 local-install.sh 安裝。
# 要裝哪些東西完全由 local-install.sh 決定(唯一真實來源),Dockerfile 不需跟著改。
# 執行時 kde openclaw 會用 volume 把主機端的 kde-cli 蓋上來,確保版本一致。
COPY . /tmp/kde-src/
RUN cd /tmp/kde-src && bash local-install.sh && cd / && rm -rf /tmp/kde-src

# build context 是 repo 根目錄,故 COPY 來源要寫完整相對路徑
COPY dockerfiles/kde-openclaw/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 保留官方的 tini 當 PID 1,entrypoint 接在它後面,docker stop 的 SIGTERM 才傳得到
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
```

- [ ] **Step 8: 更新 build.sh 的 OPENCLAW_VERSION 語意**

以下列內容整份覆蓋 `dockerfiles/kde-openclaw/build.sh`：

```bash
#!/bin/bash

# 本機建置 kde-openclaw 映像,只建目前主機架構並 --load 進本機 docker。
# 多架構(amd64 + arm64)由 release.sh 負責。
#
# OPENCLAW_VERSION 是官方 OpenClaw 映像的 tag(latest / slim / 2026.2.26 等),
# 升級 OpenClaw 只需要改這個值。

KDE_CLI_VERSION=$(git rev-parse --short HEAD)
TARGET_ARCH=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/)
OPENCLAW_VERSION=${OPENCLAW_VERSION:-latest}

echo "Build r82wei/kde-openclaw:${KDE_CLI_VERSION}-${OPENCLAW_VERSION} ..."

docker buildx build --load --no-cache \
    --platform linux/${TARGET_ARCH} \
    -f Dockerfile \
    --build-arg OPENCLAW_VERSION=${OPENCLAW_VERSION} \
    -t r82wei/kde-openclaw:${KDE_CLI_VERSION}-${OPENCLAW_VERSION} \
    -t r82wei/kde-openclaw:latest \
    ../..
```

- [ ] **Step 9: 更新 release.sh 的 OPENCLAW_VERSION 語意**

以下列內容整份覆蓋 `dockerfiles/kde-openclaw/release.sh`：

```bash
#!/bin/bash

# 發布 kde-openclaw 映像:同時建 linux/amd64 與 linux/arm64 並推上 registry。
#
# 前置需求:buildx builder 要支援多平台(docker-container driver),在 amd64 主機上建 arm64
# 還需要 QEMU:docker run --privileged --rm tonistiigi/binfmt --install all
#
# OPENCLAW_VERSION 是官方 OpenClaw 映像的 tag,升級 OpenClaw 只需要改這個值。

KDE_CLI_VERSION=$(git rev-parse --short HEAD)
OPENCLAW_VERSION=${OPENCLAW_VERSION:-latest}
PLATFORMS=linux/amd64,linux/arm64

echo "Release r82wei/kde-openclaw:${KDE_CLI_VERSION}-${OPENCLAW_VERSION} (${PLATFORMS}) ..."

# build context 必須是 repo 根目錄:Dockerfile 會 COPY . /tmp/kde-src/ 再跑 local-install.sh
docker buildx build --no-cache --platform ${PLATFORMS} --push \
    -f Dockerfile \
    --build-arg OPENCLAW_VERSION=${OPENCLAW_VERSION} \
    -t r82wei/kde-openclaw:${KDE_CLI_VERSION}-${OPENCLAW_VERSION} \
    ../..

docker buildx build --platform ${PLATFORMS} --push \
    -f Dockerfile \
    --build-arg OPENCLAW_VERSION=${OPENCLAW_VERSION} \
    -t r82wei/kde-openclaw:latest \
    ../..
```

- [ ] **Step 10: 實際建置映像**

Run: `cd dockerfiles/kde-openclaw && bash build.sh`
Expected: 建置成功。**若 `apt-get install docker.io` 失敗**（spec 的未知數 2），改用 Docker 官方 apt repo 或改裝 `docker-ce-cli`，並把採用的做法寫進 Dockerfile 註解。

- [ ] **Step 11: 驗證容器內工具齊備**

Run:
```bash
docker run --rm --entrypoint bash r82wei/kde-openclaw:latest -c \
  'for b in docker git envsubst openclaw kde setpriv; do printf "%-10s " "$b"; command -v $b || echo "(missing)"; done'
```
Expected: 六個都有路徑，沒有 `(missing)`

- [ ] **Step 12: 驗證 auth 密鑰路徑（spec 的未知數 1）**

Run:
```bash
docker run --rm --entrypoint bash r82wei/kde-openclaw:latest -c \
  'openclaw onboard --help 2>&1 | head -40; echo "---XDG---"; echo "${XDG_CONFIG_HOME:-<unset>}"'
```
Expected: 確認 auth 密鑰確實落在 `~/.config/openclaw`。**若實際是遵循 `XDG_CONFIG_HOME`**，回到 `scripts/utils/openclaw.sh` 的 `build_openclaw_docker_args()`，把該掛載改成 `-e XDG_CONFIG_HOME=${OPENCLAW_CONTAINER_HOME}/.openclaw/.config`，並同步更新 `test/test-openclaw-container-args.sh` 對應的斷言與 spec 的未知數 1。

- [ ] **Step 13: 驗證 PUID/PGID 在真實容器內生效**

Run:
```bash
docker run --rm -e PUID=1234 -e PGID=5678 --entrypoint /usr/local/bin/entrypoint.sh \
  r82wei/kde-openclaw:latest id
```
Expected: 輸出 `uid=1234 ... gid=5678 ...`

- [ ] **Step 14: 執行全部四支測試**

Run: `for t in test/test-openclaw-*.sh; do bash "$t" || exit 1; done`
Expected: 四支都 PASS

- [ ] **Step 15: Commit**

```bash
git add dockerfiles/kde-openclaw/
git commit -m "build(kde-openclaw): 改以官方 OpenClaw 映像為 base 並疊加 kde-cli"
```

---

### Task 6: 文件同步

依 CLAUDE.md 的「Updating Documentation」規則更新全部相關文件。`kde.sh` 的 `show_help()` 已在 Task 4 完成。

**Files:**
- Create: `docs/core/dev-tools/openclaw.md`
- Modify: `docs/core/quick-reference.md`
- Modify: `.claude/skills/kde-usage/references/quick-reference.md`
- Modify: `.claude/skills/kde-usage/SKILL.md`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: Task 1-5 的最終 CLI 介面與行為
- Produces: 無程式介面

- [ ] **Step 1: 建立 dev-tools 逐旗標參考**

先讀 `docs/core/dev-tools/code-server.md` 了解既有格式，再建立 `docs/core/dev-tools/openclaw.md`，內容須涵蓋：

- 概述：以容器承載 OpenClaw agent，容器內可直接使用 `kde` CLI（DooD），狀態全在 workspace 的 `.openclaw/`
- 五個 action 各自一節：`run`、`onboard`、`stop`、`exec`、`reset`，每節含用途、旗標、範例、前置條件與失敗訊息
- 旗標表：`-p/--port`、`-f/--force`、`-s/--shell`、`--command`、`-h/--help`，標明各 action 吃哪些
- port 說明：主機側預設 `18789`，容器內固定 `18789`；優先序 `-p` > 環境變數 `OPENCLAW_PORT` > 內建預設；**不寫入 `kde.env`** 及其理由（每台機器環境不同，不該隨版控同步）
- dashboard 說明：與 gateway 共用同一 port，開 `http://localhost:<port>` 即可；存取需 token，用 `kde openclaw exec --command "openclaw gateway auth-token"` 取得
- 掛載說明：workspace 以相同絕對路徑掛入；`.openclaw` 同時掛到容器 home
- `PUID`/`PGID`：預設取主機 `id -u`/`id -g`，可用環境變數覆寫
- 典型流程：`kde openclaw onboard` → `kde openclaw run` → `kde openclaw exec` → `kde openclaw stop`
- 疑難排解：`run` 說未初始化 → 跑 `onboard`；`exec` 說容器未運行 → 跑 `run`；`reset` 被拒絕 → 先 `stop`

- [ ] **Step 2: 更新兩份 quick-reference**

在 `docs/core/quick-reference.md` 與 `.claude/skills/kde-usage/references/quick-reference.md` 的開發工具區塊，比照 `code-server` 條目的格式各加入 `kde openclaw` 的五個 action 與常用旗標。

- [ ] **Step 3: diff 兩份 quick-reference 確認同步**

Run: `diff docs/core/quick-reference.md .claude/skills/kde-usage/references/quick-reference.md`
Expected: 差異僅限於本次改動之前就已存在的部分；新增的 openclaw 段落在兩邊必須一致。若發現既有漂移，只修正 openclaw 相關段落，不順手改其他區塊。

- [ ] **Step 4: 更新 SKILL.md**

在 `.claude/skills/kde-usage/SKILL.md` 加入 openclaw 的操作指引：何時使用、五個 action 的順序關係（`onboard` 必須先於 `run`）、以及「容器未運行時 `exec` 會失敗，要先 `run`」這類 Claude 常會踩到的前置條件。

- [ ] **Step 5: 更新 CLAUDE.md**

兩處：

1. Testing 一節的測試表格新增一列：

```markdown
| openclaw | `test-openclaw-args.sh`, `test-openclaw-container-args.sh`, `test-openclaw-lifecycle.sh`, `test-openclaw-entrypoint.sh` |
```

2. Code Layout 一節，在 `scripts/utils/` 那一行之後補上：

```markdown
- `scripts/utils/openclaw.sh` - `kde openclaw` 的容器生命週期邏輯（三種容器共用一組掛載參數）
```

- [ ] **Step 6: 全量測試**

Run:
```bash
export KDE_SCRIPTS_PATH="$PWD/scripts"
for t in test/test-*.sh; do bash "$t" || echo "FAILED: $t"; done
```
Expected: 沒有任何 `FAILED:` 輸出

- [ ] **Step 7: Commit**

```bash
git add docs/ .claude/ CLAUDE.md
git commit -m "docs: 同步 kde openclaw 的文件與 skill"
```

---

## 完成後的驗收

四支測試全過，且下列手動流程可跑通（需要真實的 OpenClaw 憑證，故不納入自動測試）：

```bash
kde openclaw run        # 應報錯並提示先 onboard
kde openclaw onboard    # 走完精靈
kde openclaw run        # 應成功並印出存取網址
kde openclaw exec --command "openclaw gateway auth-token"   # 應印出 token
kde openclaw exec -s    # 進 bash，在裡面跑 `kde ls` 確認 DooD 可用
kde openclaw exec       # 進 openclaw TUI
kde openclaw stop
kde openclaw reset      # 應要求 y/n 確認
```

---

## 實作後修訂

本計畫按上述任務逐一執行完成，但實作過程中發現若干與計畫原文不符之處。計畫本文保留為歷史紀錄不重寫，實際偏離之處條列如下（詳細實測過程見 `.superpowers/sdd/2026-09-03-kde-openclaw/task-5-report.md`，結論已同步進 `docs/superpowers/specs/2026-09-03-kde-openclaw-design.md` 的「實作期驗證結果」一節）：

- **移除 `~/.config/openclaw` 掛載**：計畫（含 spec）原本規劃 `.openclaw/.config/openclaw` 額外掛到容器的 `~/.config/openclaw` 存放 auth 密鑰。實測以假金鑰經 `openclaw config set` 與 `openclaw onboard --non-interactive` 兩條獨立路徑驗證，密鑰只會寫進 `~/.openclaw/openclaw.json`，`~/.config/openclaw` 從未被寫入。已從 `build_openclaw_docker_args()`、entrypoint.sh 的 `mkdir`/`chown`、以及對應測試斷言中移除該掛載。最終共用掛載從 5 個減為 4 個。
- **entrypoint.sh 新增 `export HOME`**：計畫未預期 `setpriv` 降權後 `$HOME` 不會跟著更新。實測發現走真正的 ENTRYPOINT 鏈路時，即使 uid/gid 已正確降到 `node`，`$HOME` 仍是 `/root`，導致 OpenClaw 寫入路徑錯誤且出現權限錯誤。修正為在 `exec setpriv ...` 之前明確 `export HOME="${OPENCLAW_HOME_DIR}"`。
- **`tini -s`**：計畫的 `ENTRYPOINT` 原文只有 `["/usr/bin/tini", "--", ...]`，未帶 `-s`。實測確認官方映像自己的 `ENTRYPOINT` 是 `["tini","-s","--"]`，故補回 `-s`（subreaper），對齊官方選擇。
- **`.dockerignore` 放行**：repo 根目錄 `.dockerignore` 整個排除 `dockerfiles`，計畫未提及需要放行新檔案。實作時比照既有 `!dockerfiles/code-server/...` 慣例，新增 `!dockerfiles/kde-openclaw/entrypoint.sh` 讓 `COPY` 能取到該檔。
- **`stop`/`run` 的裸 `docker` 呼叫改為 `if` 包覆**：計畫程式碼草稿中 `run_openclaw_gateway()` 的 `docker run -d ...` 與 `stop_openclaw()` 的 `docker stop`/`docker rm` 是裸呼叫（無 `if`/`|| rc=$?` 承接）。由於這些檔案在 `kde.sh` 的 `set -eo pipefail` 下執行，裸呼叫失敗會直接中止腳本、跳過收尾的錯誤訊息與清理。最終實作把它們改成 `if ! docker ...; then ...; fi` 的形式，失敗時能印出本專案的錯誤訊息（例如 `stop` 失敗時提示手動 `docker rm -f <name>`）再回傳，而不是被 `set -e` 直接中止。
