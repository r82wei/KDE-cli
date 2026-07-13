# code-server 多重掛載 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓 `kde code-server -v` 可重複指定多個掛載目標，且每個目標可以是目錄或單一檔案。

**Architecture:** `command.sh` 把重複的 `-v` 累積成 bash 陣列，以 `"$@"` 傳給 `start_code_server`；後者前 4 個位置參數為 `(PORT DAEMON NAME OPEN_PATH)`，其餘為掛載清單，經解析/驗證/去重後展開為多個 docker `-v host:host` 參數。

**Tech Stack:** 純 Bash，Docker（DooD）。測試用 stub `docker`/`stat` 函式攔截 `docker run` 參數再 grep 驗證（沿用 `test/test-proj-exec-volumes.sh` 慣例）。

## Global Constraints

- 所有 script 使用 `set -eo pipefail`。
- 函式命名 snake_case；使用者訊息與註解用繁體中文。
- 沿用「host 路徑 = container 路徑」掛載慣例（`-v "${p}:${p}"`）。
- 既有用法（無參數、`-v <dir>`、`-v <dir> -w <dir>`）行為不得改變。
- 依 CLAUDE.md：任何影響 `kde` 用法的改動須同步 `docs/core/quick-reference.md`、`.claude/skills/kde-usage/SKILL.md`、`.claude/skills/kde-usage/references/quick-reference.md`。

---

## File Structure

- `scripts/utils/code-server.sh` — `start_code_server` 改為多重掛載（核心邏輯）。
- `scripts/code-server/command.sh` — `-v` parser 累積成陣列、`--help` 更新、呼叫慣例更新。
- `test/test-code-server-mounts.sh` — 新增，驅動 `start_code_server` 驗證多重掛載行為。
- `docs/core/quick-reference.md`、`.claude/skills/kde-usage/references/quick-reference.md`、`.claude/skills/kde-usage/SKILL.md` — 文件同步。

---

## Task 1: `start_code_server` 多重掛載核心邏輯

**Files:**
- Create: `test/test-code-server-mounts.sh`
- Modify: `scripts/utils/code-server.sh:3-76` (改寫 `start_code_server`)

**Interfaces:**
- Produces: `start_code_server PORT DAEMON NAME OPEN_PATH [MOUNT...]`
  - `PORT` (string 數字)、`DAEMON` ("true"/其他)、`NAME` (容器名，預設 `code-server`)、`OPEN_PATH` (開啟資料夾，可空字串表示自動挑選)、其餘不定長度為掛載目標。
  - 依賴環境變數：`PASSWORD`、`KDE_PATH`、`KDE_CLI_PATH`、`CODE_SERVER_IMAGE`、`USER`。
- Consumes: 無（是最底層函式）。

- [ ] **Step 1: 寫失敗測試**

Create `test/test-code-server-mounts.sh`:

```bash
#!/bin/bash
set -eo pipefail

# 測試 start_code_server 的多重掛載行為

echo "===== kde code-server 多重掛載測試 ====="
echo ""

export KDE_PATH="/tmp/kde-test-codeserver"
export KDE_CLI_PATH="/tmp/kde-test-codeserver/cli"
export CODE_SERVER_IMAGE="code-server:test"
export PASSWORD="testpass"

rm -rf "${KDE_PATH}"
mkdir -p "${KDE_PATH}/cli"

# 準備掛載目標：兩個目錄 + 一個檔案
mkdir -p "${KDE_PATH}/dir-a" "${KDE_PATH}/dir-b"
touch "${KDE_PATH}/file-c.conf"

source "$(dirname "${BASH_SOURCE[0]}")/../scripts/utils/code-server.sh"

# stub：攔截 docker run，ps 回傳空（無同名容器），stat 回傳固定 gid
docker() {
    case "$1" in
        ps)  return 0 ;;
        run) echo "DOCKER_RUN: $*" ;;
    esac
}
stat() { echo "0"; }

TOTAL=0; PASS=0; FAIL=0
check() { # $1=描述 $2=條件結果(0/1)
    TOTAL=$((TOTAL+1))
    if [[ "$2" -eq 0 ]]; then echo "✅ $1"; PASS=$((PASS+1));
    else echo "❌ $1"; FAIL=$((FAIL+1)); fi
}

# 測試 1：多個目錄 -v 都展開為 host:host
out=$(start_code_server 8080 false cs-1 "" "${KDE_PATH}/dir-a" "${KDE_PATH}/dir-b" 2>&1)
echo "$out" | grep -q -- "-v ${KDE_PATH}/dir-a:${KDE_PATH}/dir-a" \
  && echo "$out" | grep -q -- "-v ${KDE_PATH}/dir-b:${KDE_PATH}/dir-b"
check "多個目錄掛載都展開為 host:host" $?

# 測試 2：檔案也能掛載
out=$(start_code_server 8080 false cs-2 "${KDE_PATH}/dir-a" "${KDE_PATH}/dir-a" "${KDE_PATH}/file-c.conf" 2>&1)
echo "$out" | grep -q -- "-v ${KDE_PATH}/file-c.conf:${KDE_PATH}/file-c.conf"
check "單一檔案可掛載" $?

# 測試 3：未給 workdir 時預設第一個目錄型掛載（跳過檔案）
out=$(start_code_server 8080 false cs-3 "" "${KDE_PATH}/file-c.conf" "${KDE_PATH}/dir-b" 2>&1)
echo "$out" | grep -q -- "--workdir ${KDE_PATH}/dir-b"
check "預設 workdir 為第一個目錄型掛載" $?

# 測試 4：不存在的掛載目標報錯 return 1
if start_code_server 8080 false cs-4 "" "${KDE_PATH}/nope" >/dev/null 2>&1; then r=1; else r=0; fi
check "不存在的掛載目標報錯" $r

# 測試 5：重複路徑去重（只出現一次）
out=$(start_code_server 8080 false cs-5 "" "${KDE_PATH}/dir-a" "${KDE_PATH}/dir-a" 2>&1)
cnt=$(echo "$out" | grep -o -- "-v ${KDE_PATH}/dir-a:${KDE_PATH}/dir-a" | wc -l)
[[ "$cnt" -eq 1 ]]
check "重複掛載路徑去重" $?

# 測試 6：全部為檔案且未給 workdir 時報錯
if start_code_server 8080 false cs-6 "" "${KDE_PATH}/file-c.conf" >/dev/null 2>&1; then r=1; else r=0; fi
check "全為檔案且無 workdir 時報錯" $r

rm -rf "${KDE_PATH}"

echo ""
echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `bash test/test-code-server-mounts.sh`
Expected: FAIL — 現行 `start_code_server` 的第 4 參數是 `MOUNT_PATH`、第 5 是 `OPEN_PATH`，無法處理多個掛載，測試 1/2/5 等會失敗。

- [ ] **Step 3: 改寫 `start_code_server`**

將 `scripts/utils/code-server.sh` 第 3–76 行的 `start_code_server` 整段替換為：

```bash
start_code_server() {
    local PORT=$1
    local DAEMON=$2
    local NAME=${3:-code-server}
    local OPEN_PATH_ARG=$4
    shift 4
    local -a RAW_MOUNTS=("$@")

    # 無掛載目標時預設當前路徑
    if [[ ${#RAW_MOUNTS[@]} -eq 0 ]]; then
        RAW_MOUNTS=("$PWD")
    fi

    # 解析、驗證、去重
    local -a MOUNTS=()       # 全部掛載目標（絕對路徑）
    local -a DIR_MOUNTS=()   # 其中的目錄型掛載
    local m abs
    for m in "${RAW_MOUNTS[@]}"; do
        abs=$(readlink -f "$m")
        if [[ ! -e "$abs" ]]; then
            echo "❌ 掛載目標不存在：$m"
            return 1
        fi
        if [[ ! -d "$abs" && ! -f "$abs" ]]; then
            echo "❌ 掛載目標必須是目錄或檔案：$m"
            return 1
        fi
        # 去重（相同絕對路徑只掛一次）
        if [[ " ${MOUNTS[*]} " == *" $abs "* ]]; then
            continue
        fi
        MOUNTS+=("$abs")
        if [[ -d "$abs" ]]; then
            DIR_MOUNTS+=("$abs")
        fi
    done

    # 決定開啟資料夾（workdir）
    local OPEN_PATH
    if [[ -n "$OPEN_PATH_ARG" ]]; then
        OPEN_PATH=$(readlink -f "$OPEN_PATH_ARG")
        if [[ ! -d "$OPEN_PATH" ]]; then
            echo "❌ 開啟資料夾不存在或不是目錄：${OPEN_PATH}"
            return 1
        fi
    else
        if [[ ${#DIR_MOUNTS[@]} -eq 0 ]]; then
            echo "❌ 沒有可開啟的目錄型掛載，請用 -w/--workdir 明確指定開啟資料夾"
            return 1
        fi
        OPEN_PATH=${DIR_MOUNTS[0]}
    fi

    # 開啟資料夾必須位於任一目錄型掛載底下，否則 container 內看不到
    local under=false d
    for d in "${DIR_MOUNTS[@]}"; do
        if [[ "$OPEN_PATH" == "$d" || "$OPEN_PATH" == "$d"/* ]]; then
            under=true
            break
        fi
    done
    if [[ "$under" != "true" ]]; then
        echo "❌ 開啟資料夾 (${OPEN_PATH}) 必須位於其中一個目錄型掛載底下"
        return 1
    fi

    # 檢查同名容器是否已存在
    if docker ps -a --format '{{.Names}}' | grep -qx "${NAME}"; then
        echo "❌ 容器名稱 ${NAME} 已存在，請先停止/移除，或用 -n 指定其他名稱"
        echo "   docker rm -f ${NAME}"
        return 1
    fi

    local CONFIG_DIR=${KDE_PATH}/.code-server/${NAME}
    mkdir -p ${CONFIG_DIR}

    # 組出掛載參數（每個目標 host 路徑 = container 路徑）
    local -a MOUNT_ARGS=()
    for m in "${MOUNTS[@]}"; do
        MOUNT_ARGS+=(-v "${m}:${m}")
    done

    local DOCKER_SOCK_GID
    DOCKER_SOCK_GID=$( (stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock 2>/dev/null) )

    if [[ "${DAEMON}" == "true" ]]; then
        docker run -it -d \
        --name ${NAME} \
        --workdir ${OPEN_PATH} \
        --group-add ${DOCKER_SOCK_GID} \
        -p ${PORT}:8080 \
        -e "PASSWORD=${PASSWORD}" \
        -v "${CONFIG_DIR}:/home/coder" \
        "${MOUNT_ARGS[@]}" \
        -v "${KDE_CLI_PATH}:/usr/local/lib/kde:ro" \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -u "$(id -u):$(id -g)" \
        -e "DOCKER_USER=$USER" \
        ${CODE_SERVER_IMAGE} \
        ${OPEN_PATH}

        echo "✓ code-server 已在背景啟動 (${NAME})"
        echo "掛載目標:"
        for m in "${MOUNTS[@]}"; do echo "  - ${m}"; done
        echo "開啟資料夾: ${OPEN_PATH}"
        echo "存取網址: http://localhost:${PORT}"
        echo "停止服務: docker stop ${NAME}"
    else
        docker run -it --rm \
        --name ${NAME} \
        --workdir ${OPEN_PATH} \
        --group-add ${DOCKER_SOCK_GID} \
        -p ${PORT}:8080 \
        -e "PASSWORD=${PASSWORD}" \
        -v "${CONFIG_DIR}:/home/coder" \
        "${MOUNT_ARGS[@]}" \
        -v "${KDE_CLI_PATH}:/usr/local/lib/kde:ro" \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -u "$(id -u):$(id -g)" \
        -e "DOCKER_USER=$USER" \
        ${CODE_SERVER_IMAGE} \
        ${OPEN_PATH}
    fi
}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `bash test/test-code-server-mounts.sh`
Expected: PASS — `🎉 全部通過`，6 個測試全數通過。

- [ ] **Step 5: Commit**

```bash
git add scripts/utils/code-server.sh test/test-code-server-mounts.sh
git commit -m "feat(code-server): start_code_server 支援多重掛載(目錄/檔案)"
```

---

## Task 2: `command.sh` 累積 `-v` 陣列並更新說明

**Files:**
- Modify: `scripts/code-server/command.sh:11-22`（help 與變數初始化）、`:47-54`（`-v` 分支）、`:75-76`（呼叫）

**Interfaces:**
- Consumes: `start_code_server PORT DAEMON NAME OPEN_PATH [MOUNT...]`（Task 1 產出）。

- [ ] **Step 1: 更新 `--help` 的 `-v` 說明**

在 `scripts/code-server/command.sh`，將這一行：

```bash
    echo "  -v, --volume        指定掛載到 container 的目錄 (預設為當前路徑)"
```

替換為：

```bash
    echo "  -v, --volume        指定掛載到 container 的目錄或檔案 (可重複指定多次，預設為當前路徑)"
```

- [ ] **Step 2: 變數初始化改為陣列**

將：

```bash
DAEMON=false
PORT=8080
NAME=code-server
MOUNT_PATH=""
OPEN_PATH=""
```

替換為：

```bash
DAEMON=false
PORT=8080
NAME=code-server
MOUNT_PATHS=()
OPEN_PATH=""
```

- [ ] **Step 3: `-v` 分支改為 append**

將：

```bash
        --volume|-v)
            MOUNT_PATH="$2"
            if [[ -z "${MOUNT_PATH}" ]]; then
                echo "無效的掛載路徑：${MOUNT_PATH}"
                exit 1
            fi
            shift 2
            ;;
```

替換為：

```bash
        --volume|-v)
            if [[ -z "$2" ]]; then
                echo "無效的掛載路徑"
                exit 1
            fi
            MOUNT_PATHS+=("$2")
            shift 2
            ;;
```

- [ ] **Step 4: 更新呼叫慣例**

將最後一行：

```bash
start_code_server ${PORT} ${DAEMON} ${NAME} "${MOUNT_PATH}" "${OPEN_PATH}"
```

替換為：

```bash
start_code_server "${PORT}" "${DAEMON}" "${NAME}" "${OPEN_PATH}" "${MOUNT_PATHS[@]}"
```

- [ ] **Step 5: 手動驗證 help 與 parser**

Run: `bash -n scripts/code-server/command.sh && echo "語法 OK"`
Expected: `語法 OK`

Run: `KDE_SCRIPTS_PATH=./scripts bash scripts/code-server/command.sh --help`
Expected: 印出 usage，且 `-v, --volume` 那行含「可重複指定多次」「目錄或檔案」。

- [ ] **Step 6: Commit**

```bash
git add scripts/code-server/command.sh
git commit -m "feat(code-server): -v 可重複指定多個掛載目標"
```

---

## Task 3: 文件同步

**Files:**
- Modify: `docs/core/quick-reference.md:280-282`
- Modify: `.claude/skills/kde-usage/references/quick-reference.md:278-280`
- Modify: `.claude/skills/kde-usage/SKILL.md`（若含 code-server `-v` 說明段落）

**Interfaces:** 無（純文件）。

- [ ] **Step 1: 更新 `docs/core/quick-reference.md`**

將：

```bash
# 指定掛載目錄（預設當前路徑）與開啟的資料夾（預設同掛載目錄）
kde code-server -v <mount_dir>
kde code-server -v <mount_dir> -w <open_dir>
```

替換為：

```bash
# 指定掛載目錄/檔案（預設當前路徑）與開啟的資料夾（預設第一個目錄型掛載）
kde code-server -v <mount_dir>
kde code-server -v <mount_dir> -w <open_dir>

# -v 可重複指定多次，掛載多個資料夾或單一檔案
kde code-server -v ~/proj-a -v ~/proj-b -v ~/.gitconfig
# 未指定 -w 時開啟第一個「目錄型」掛載（此例為 ~/proj-a）
```

- [ ] **Step 2: 更新 skill 的 quick-reference（內容須與 Step 1 一致）**

將 `.claude/skills/kde-usage/references/quick-reference.md` 的：

```bash
# 指定掛載目錄（預設當前路徑）與開啟的資料夾（預設同掛載目錄）
kde code-server -v <mount_dir>
kde code-server -v <mount_dir> -w <open_dir>
```

替換為：

```bash
# 指定掛載目錄/檔案（預設當前路徑）與開啟的資料夾（預設第一個目錄型掛載）
kde code-server -v <mount_dir>
kde code-server -v <mount_dir> -w <open_dir>

# -v 可重複指定多次，掛載多個資料夾或單一檔案
kde code-server -v ~/proj-a -v ~/proj-b -v ~/.gitconfig
# 未指定 -w 時開啟第一個「目錄型」掛載（此例為 ~/proj-a）
```

- [ ] **Step 3: 檢查並更新 SKILL.md**

Run: `grep -n "\-v\|--volume\|掛載" .claude/skills/kde-usage/SKILL.md`
若有描述 code-server `-v` 只接受單一目錄的段落，改為「`-v` 可重複指定，掛載多個目錄或單一檔案；未指定 `-w` 時開啟第一個目錄型掛載」。若 SKILL.md 未提及 code-server `-v` 細節，則不需改動（在 commit 訊息註明）。

- [ ] **Step 4: Commit**

```bash
git add docs/core/quick-reference.md .claude/skills/kde-usage/
git commit -m "docs: 同步 code-server -v 多重掛載說明"
```

---

## Self-Review

- **Spec coverage:**
  - 重複 `-v` → Task 2 Step 3。✓
  - 目錄/檔案皆可 → Task 1 Step 3（驗證 `-d || -f`）、測試 2。✓
  - host=container 慣例 → Task 1 `MOUNT_ARGS`。✓
  - 單一 workdir、預設第一個目錄型 → Task 1（`DIR_MOUNTS[0]`）、測試 3。✓
  - 全為檔案且無 workdir 報錯 → Task 1、測試 6。✓
  - 去重 → Task 1、測試 5。✓
  - workdir 須在任一目錄型掛載下 → Task 1（`under` 檢查）。✓
  - 無 `-v` 預設 `$PWD` → Task 1（`RAW_MOUNTS=("$PWD")`）。✓
  - 文件同步三處 → Task 3。✓
- **Placeholder scan:** 無 TBD/TODO；SKILL.md 為條件式改動並附判斷指令，非 placeholder。✓
- **Type consistency:** 呼叫慣例 `PORT DAEMON NAME OPEN_PATH [MOUNT...]` 在 Task 1（Produces）與 Task 2 Step 4（呼叫）一致。✓
