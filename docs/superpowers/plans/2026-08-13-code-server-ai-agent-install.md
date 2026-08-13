# code-server 依啟動參數安裝 AI Agent — 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓 `kde code-server --agent claude --agent codex` 在容器啟動時自動安裝指定的 AI coding agent，已裝跳過、失敗不阻擋啟動。

**Architecture:** 掛在 code-server base image 內建的 `/entrypoint.d` hook（不覆寫 ENTRYPOINT）。entrypoint 腳本讀環境變數 `KDE_CODE_SERVER_AI_AGENTS`，依「檔名約定」在 `/usr/local/lib/kde-agents/install-<name>.sh` 找安裝腳本並執行。agent 裝進 `$HOME/.local/bin`（host 持久卷內），因此重啟後仍在。CLI 端新增 `--agent` 旗標組裝該環境變數。

**Tech Stack:** Bash、Docker、code-server base image（`codercom/code-server`）

**設計文件：** `docs/superpowers/specs/2026-08-13-code-server-ai-agent-install-design.md`

## Global Constraints

- 所有腳本使用 `set -eo pipefail`（專案慣例）。**唯一例外**：`10-ai-agents.sh` 刻意不用 `set -e`，並且必須無條件 `exit 0`。
- 程式註解與使用者訊息一律使用繁體中文。
- 函式命名 snake_case；`is_*()` 回傳 "true"/"false" 字串、`get_*()` 取值、`create_*()`/`start_*()`/`stop_*()` 為動作。
- 環境變數命名：外部旋鈕用 `KDE_CODE_SERVER_` 前綴（`KDE_CODE_SERVER_AI_AGENTS`、`KDE_CODE_SERVER_AI_AGENTS_REINSTALL`、`KDE_CODE_SERVER_AGENT_DIR`）；entrypoint 傳給 install 腳本的內部契約**不加前綴**（`AGENT_NAME`、`AGENT_BIN_DIR`、`AGENT_REINSTALL`），以便日後 sandbox 共用同一批 install 腳本。
- 映像內**沒有** `node`、`npm`、`npx`、`unzip`、`rg`。可用：`curl`、`git`、`tar`、`gzip`、`sudo`、`bash`。
- `scripts/code-server/command.sh` 是被 `kde.sh` **source** 進去的，而 `kde.sh` 開了 `set -eo pipefail`。因此呼叫可能回傳非零的函式時必須寫成 `func ... || rc=$?`，不可寫成 `func ...; rc=$?`（後者會直接中止整個 `kde`）。
- 測試腳本放 `test/`，以 `bash test/<name>.sh` 執行，全數通過時最後一行輸出 `🎉 全部通過`，有失敗則 `exit 1`。

---

## File Structure

| 檔案 | 責任 | 動作 |
|---|---|---|
| `dockerfiles/code-server/entrypoint.d/10-ai-agents.sh` | 讀環境變數、找安裝腳本、處理跳過/失敗/PATH。不知道任何 agent 的細節 | 由 `entrypoint.sh` 搬移 + 實作 |
| `dockerfiles/code-server/agents/install-claude.sh` | 只負責裝 claude | 搬移 + 加 `set -eo pipefail` |
| `dockerfiles/code-server/agents/install-codex.sh` | 只負責裝 codex | 搬移 + 加 `set -eo pipefail` |
| `dockerfiles/code-server/Dockerfile` | 把上述兩個目錄 COPY 進映像 | 修改 |
| `scripts/utils/code-server.sh` | `show_code_server_help()`、`parse_code_server_args()`、`start_code_server()` | 修改 |
| `scripts/code-server/command.sh` | 只做「解析 → 問密碼 → 啟動」三件事 | 大幅簡化 |
| `test/test-agent-entrypoint.sh` | 驗證 entrypoint 行為（不真的安裝東西） | 新增 |
| `test/test-install-scripts.sh` | 驗證 install 腳本在 curl 失敗時回傳非零 | 新增 |
| `test/test-code-server-agent-args.sh` | 驗證 `--agent` 解析與 docker 參數組裝 | 新增 |
| `test/test-code-server-mounts.sh` | 既有掛載測試 | 修改（呼叫端補參數） |

---

## Task 1: entrypoint 腳本 `10-ai-agents.sh`

**Files:**
- Create: `dockerfiles/code-server/entrypoint.d/10-ai-agents.sh`（由 `dockerfiles/code-server/entrypoint.sh` git mv 而來）
- Test: `test/test-agent-entrypoint.sh`

**Interfaces:**
- Consumes: 無（本任務不依賴其他任務）
- Produces:
  - 腳本路徑 `dockerfiles/code-server/entrypoint.d/10-ai-agents.sh`（Task 5 的 Dockerfile 會 COPY 它）
  - 讀取的外部變數：`KDE_CODE_SERVER_AI_AGENTS`（逗號分隔字串）、`KDE_CODE_SERVER_AI_AGENTS_REINSTALL`（`true` / 未設定）、`KDE_CODE_SERVER_AGENT_DIR`（預設 `/usr/local/lib/kde-agents`，供測試覆寫）
  - 傳給 install 腳本的契約變數：`AGENT_NAME`、`AGENT_BIN_DIR`、`AGENT_REINSTALL`（Task 2 的 install 腳本可使用）

---

- [ ] **Step 1: 建立目錄並搬移空檔**

```bash
cd /home/maxime/KDE-cli
mkdir -p dockerfiles/code-server/entrypoint.d
git add dockerfiles/code-server/entrypoint.sh
git mv dockerfiles/code-server/entrypoint.sh dockerfiles/code-server/entrypoint.d/10-ai-agents.sh
```

> `entrypoint.sh` 目前是 untracked，所以要先 `git add` 才能 `git mv`。

- [ ] **Step 2: 寫失敗的測試**

建立 `test/test-agent-entrypoint.sh`，內容如下（完整貼上）：

```bash
#!/bin/bash

# 測試 /entrypoint.d/10-ai-agents.sh 的行為
# 以假的 AGENT_DIR 與假的 HOME 執行，不會真的安裝任何東西

echo "===== code-server AI agent entrypoint 測試 ====="
echo ""

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/dockerfiles/code-server/entrypoint.d/10-ai-agents.sh"
TMP_ROOT="/tmp/kde-test-agent-entrypoint"

TOTAL=0; PASS=0; FAIL=0
check() { # $1=描述 $2=條件結果(0/1)
    TOTAL=$((TOTAL+1))
    if [[ "$2" -eq 0 ]]; then echo "✅ $1"; PASS=$((PASS+1));
    else echo "❌ $1"; FAIL=$((FAIL+1)); fi
}

# 建立乾淨的假 HOME 與假 AGENT_DIR
setup() {
    rm -rf "${TMP_ROOT}"
    mkdir -p "${TMP_ROOT}/home" "${TMP_ROOT}/agents"

    # 假的「安裝成功」腳本：在 AGENT_BIN_DIR 造出同名可執行檔，
    # 並在 $HOME/run-log 記一次，供「是否真的執行過」的斷言使用
    cat > "${TMP_ROOT}/agents/install-goodagent.sh" <<'EOS'
#!/bin/bash
set -eo pipefail
echo "goodagent:${AGENT_REINSTALL:-}" >> "${HOME}/run-log"
printf '#!/bin/bash\necho goodagent\n' > "${AGENT_BIN_DIR}/goodagent"
chmod +x "${AGENT_BIN_DIR}/goodagent"
EOS

    # 假的「安裝失敗」腳本
    cat > "${TMP_ROOT}/agents/install-badagent.sh" <<'EOS'
#!/bin/bash
set -eo pipefail
echo "badagent" >> "${HOME}/run-log"
echo "模擬下載失敗" >&2
exit 1
EOS

    chmod +x "${TMP_ROOT}/agents"/*.sh
}

# 以受控環境執行 entrypoint 腳本
# $1=KDE_CODE_SERVER_AI_AGENTS  $2=KDE_CODE_SERVER_AI_AGENTS_REINSTALL(可省略)
run_entrypoint() {
    env -i \
        PATH="/usr/local/bin:/usr/bin:/bin" \
        HOME="${TMP_ROOT}/home" \
        KDE_CODE_SERVER_AGENT_DIR="${TMP_ROOT}/agents" \
        KDE_CODE_SERVER_AI_AGENTS="$1" \
        KDE_CODE_SERVER_AI_AGENTS_REINSTALL="${2:-}" \
        bash "${SCRIPT}" 2>&1
}

# 測試 1：未指定 agent 時完全靜默且 exit 0
setup
out=$(run_entrypoint ""); rc=$?
[[ ${rc} -eq 0 && -z "${out}" ]]
check "未指定 agent 時無輸出且 exit 0" $?

# 測試 2：正常安裝，binary 落在 \$HOME/.local/bin
setup
out=$(run_entrypoint "goodagent"); rc=$?
[[ ${rc} -eq 0 ]] && [[ -x "${TMP_ROOT}/home/.local/bin/goodagent" ]]
check "安裝成功且 binary 位於 \$HOME/.local/bin" $?

# 測試 3：不認識的名稱只警告，仍 exit 0，且列出可用清單
setup
out=$(run_entrypoint "nosuchagent"); rc=$?
[[ ${rc} -eq 0 ]] \
  && echo "${out}" | grep -q "不認識" \
  && echo "${out}" | grep -q "goodagent"
check "不認識的 agent 只警告、列出可用清單、exit 0" $?

# 測試 4：安裝失敗只警告，仍 exit 0
setup
out=$(run_entrypoint "badagent"); rc=$?
[[ ${rc} -eq 0 ]] && echo "${out}" | grep -q "失敗"
check "安裝失敗只警告且 exit 0" $?

# 測試 5：前面的 agent 失敗不影響後面的 agent
setup
out=$(run_entrypoint "badagent,goodagent"); rc=$?
[[ ${rc} -eq 0 ]] && [[ -x "${TMP_ROOT}/home/.local/bin/goodagent" ]]
check "單一 agent 失敗不中斷後續安裝" $?

# 測試 6：第二次執行時跳過（安裝腳本不再被呼叫）
setup
run_entrypoint "goodagent" >/dev/null
out=$(run_entrypoint "goodagent"); rc=$?
cnt=$(grep -c '^goodagent:' "${TMP_ROOT}/home/run-log")
[[ ${rc} -eq 0 ]] && [[ "${cnt}" -eq 1 ]] && echo "${out}" | grep -q "跳過"
check "已安裝時跳過，安裝腳本只被執行一次" $?

# 測試 7：REINSTALL=true 時即使已安裝也重跑安裝腳本
setup
run_entrypoint "goodagent" >/dev/null
run_entrypoint "goodagent" "true" >/dev/null
cnt=$(grep -c '^goodagent:' "${TMP_ROOT}/home/run-log")
[[ "${cnt}" -eq 2 ]]
check "REINSTALL=true 時強制重裝" $?

# 測試 8：AGENT_REINSTALL 契約變數有正確轉譯給安裝腳本
setup
run_entrypoint "goodagent" "true" >/dev/null
grep -q '^goodagent:true$' "${TMP_ROOT}/home/run-log"
check "KDE_CODE_SERVER_AI_AGENTS_REINSTALL 轉譯為 AGENT_REINSTALL" $?

# 測試 9：逗號分隔的空白與空欄位要被忽略
setup
out=$(run_entrypoint " goodagent , ,"); rc=$?
[[ ${rc} -eq 0 ]] && [[ -x "${TMP_ROOT}/home/.local/bin/goodagent" ]] \
  && ! echo "${out}" | grep -q "不認識"
check "去除空白並忽略空欄位" $?

# 測試 10：.bashrc / .profile 的 PATH 區塊冪等（跑兩次只出現一次）
setup
run_entrypoint "goodagent" >/dev/null
run_entrypoint "goodagent" >/dev/null
# 注意：要比對開頭的 guard 標記，不能只比對 'kde-cli agents PATH'
# —— 區塊的開頭與結尾兩行都含那段字，會數成 2
bashrc_cnt=$(grep -c '>>> kde-cli agents PATH >>>' "${TMP_ROOT}/home/.bashrc")
profile_cnt=$(grep -c '>>> kde-cli agents PATH >>>' "${TMP_ROOT}/home/.profile")
[[ "${bashrc_cnt}" -eq 1 && "${profile_cnt}" -eq 1 ]]
check ".bashrc/.profile 的 PATH 區塊冪等" $?

rm -rf "${TMP_ROOT}"

echo ""
echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
```

- [ ] **Step 3: 執行測試確認失敗**

Run: `bash test/test-agent-entrypoint.sh`
Expected: FAIL — 因為 `10-ai-agents.sh` 目前只有 `#!/bin/bash` 與一行註解，10 項全部或大部分失敗，最後一行印 `❌ 有失敗` 且 exit 1

- [ ] **Step 4: 實作 `10-ai-agents.sh`**

把 `dockerfiles/code-server/entrypoint.d/10-ai-agents.sh` 整個檔案內容換成：

```bash
#!/bin/bash

# KDE-CLI：依 KDE_CODE_SERVER_AI_AGENTS 安裝 AI coding agent
#
# 由 code-server base image 的 /usr/bin/entrypoint.sh 透過 /entrypoint.d hook
# 執行，時機在 fixuid 與 DOCKER_USER 改名之後、code-server 啟動之前。
#
# 兩個刻意的設計，改動前請先讀 docs/superpowers/specs/2026-08-13-*：
#   1. 無條件 exit 0：base entrypoint 是 set -eu，任何 agent 安裝失敗都不可
#      阻擋 code-server 啟動。
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
```

- [ ] **Step 5: 執行測試確認通過**

Run: `bash test/test-agent-entrypoint.sh`
Expected: PASS — `總測試數：10  通過：10  失敗：0` 並印 `🎉 全部通過`

- [ ] **Step 6: 語法檢查**

Run: `bash -n dockerfiles/code-server/entrypoint.d/10-ai-agents.sh && echo OK`
Expected: `OK`

- [ ] **Step 7: Commit**

```bash
cd /home/maxime/KDE-cli
chmod +x dockerfiles/code-server/entrypoint.d/10-ai-agents.sh
git add dockerfiles/code-server/entrypoint.d/10-ai-agents.sh test/test-agent-entrypoint.sh
git commit -m "feat(code-server): 新增 /entrypoint.d hook 依 KDE_CODE_SERVER_AI_AGENTS 安裝 agent

以檔名約定(install-<name>.sh)自動發現安裝腳本,已裝跳過、
單一失敗只警告不中斷,無條件 exit 0 確保 code-server 仍會啟動。
新增 test/test-agent-entrypoint.sh(10 項斷言)。"
```

---

## Task 2: install 腳本搬移並修正錯誤傳遞

**Files:**
- Create: `dockerfiles/code-server/agents/install-claude.sh`（由 `dockerfiles/code-server/install-claude.sh` git mv）
- Create: `dockerfiles/code-server/agents/install-codex.sh`（由 `dockerfiles/code-server/install-codex.sh` git mv）
- Test: `test/test-install-scripts.sh`

**Interfaces:**
- Consumes: Task 1 定義的契約變數 `AGENT_NAME` / `AGENT_BIN_DIR` / `AGENT_REINSTALL`（本任務兩支腳本實際上不需要使用它們，因為兩個官方安裝器預設就裝到 `$HOME/.local/bin`；但契約仍成立）
- Produces: `dockerfiles/code-server/agents/` 目錄（Task 5 的 Dockerfile 會 COPY 它）

**背景（為何要改）：** `curl -fsSL <url> | bash` 在沒有 `pipefail` 時，**curl 的失敗退出碼會被 pipeline 末端的 `bash` 蓋掉並回傳 0**。Task 1 的 entrypoint 是靠退出碼判斷成敗的，不加 `pipefail` 會把斷網/404 誤判為安裝成功。

---

- [ ] **Step 1: 搬移兩支腳本**

```bash
cd /home/maxime/KDE-cli
mkdir -p dockerfiles/code-server/agents
git add dockerfiles/code-server/install-claude.sh dockerfiles/code-server/install-codex.sh
git mv dockerfiles/code-server/install-claude.sh dockerfiles/code-server/agents/install-claude.sh
git mv dockerfiles/code-server/install-codex.sh dockerfiles/code-server/agents/install-codex.sh
```

- [ ] **Step 2: 寫失敗的測試**

建立 `test/test-install-scripts.sh`，完整內容：

```bash
#!/bin/bash

# 測試 agents/install-*.sh 的錯誤傳遞
#
# 重點：這些腳本都是 `curl ... | bash` 形式。沒有 set -o pipefail 時，
# curl 失敗（斷網 / 404）的退出碼會被 pipeline 末端的 bash 吞掉而回傳 0，
# 導致 entrypoint 把安裝失敗誤判為成功。本測試以假的 curl 驗證這件事。
#
# 注意：測試完全不連網——PATH 前置一個假的 curl。

echo "===== install 腳本錯誤傳遞測試 ====="
echo ""

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_DIR="${REPO_ROOT}/dockerfiles/code-server/agents"
TMP_ROOT="/tmp/kde-test-install-scripts"

TOTAL=0; PASS=0; FAIL=0
check() { # $1=描述 $2=條件結果(0/1)
    TOTAL=$((TOTAL+1))
    if [[ "$2" -eq 0 ]]; then echo "✅ $1"; PASS=$((PASS+1));
    else echo "❌ $1"; FAIL=$((FAIL+1)); fi
}

# 準備假的 curl：一律失敗且不輸出任何內容（模擬斷網 / 404）
rm -rf "${TMP_ROOT}"
mkdir -p "${TMP_ROOT}/fakebin"
cat > "${TMP_ROOT}/fakebin/curl" <<'EOS'
#!/bin/bash
echo "curl: (6) Could not resolve host" >&2
exit 6
EOS
chmod +x "${TMP_ROOT}/fakebin/curl"

# 逐一驗證每支 install 腳本
for script in "${AGENT_DIR}"/install-*.sh; do
    name=$(basename "${script}")

    # 斷言 1：語法正確
    bash -n "${script}"
    check "${name} 語法正確" $?

    # 斷言 2：有開 pipefail（靜態檢查，讓失敗訊息更好懂）
    grep -qE '^set .*pipefail' "${script}"
    check "${name} 有 set -o pipefail" $?

    # 斷言 3：curl 失敗時腳本必須回傳非零
    if PATH="${TMP_ROOT}/fakebin:${PATH}" bash "${script}" >/dev/null 2>&1; then
        r=1
    else
        r=0
    fi
    check "${name} 在 curl 失敗時回傳非零" $r
done

rm -rf "${TMP_ROOT}"

echo ""
echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
```

- [ ] **Step 3: 執行測試確認失敗**

Run: `bash test/test-install-scripts.sh`
Expected: FAIL — 每支腳本的「有 set -o pipefail」與「curl 失敗時回傳非零」兩項失敗（語法檢查會通過），共 4 項失敗

- [ ] **Step 4: 加上 `set -eo pipefail`**

`dockerfiles/code-server/agents/install-claude.sh` 完整內容改為：

```bash
#!/bin/bash
set -eo pipefail

# 安裝 Claude
# pipefail 不可省略：沒有它時 curl 失敗的退出碼會被末端的 bash 吞掉而回傳 0，
# entrypoint 會把安裝失敗誤判為成功。
curl -fsSL https://claude.ai/install.sh | bash
```

`dockerfiles/code-server/agents/install-codex.sh` 完整內容改為：

```bash
#!/bin/bash
set -eo pipefail

# 安裝 Codex
# pipefail 不可省略：沒有它時 curl 失敗的退出碼會被末端的 sh 吞掉而回傳 0，
# entrypoint 會把安裝失敗誤判為成功。
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

- [ ] **Step 5: 執行測試確認通過**

Run: `bash test/test-install-scripts.sh`
Expected: PASS — `總測試數：6  通過：6  失敗：0` 並印 `🎉 全部通過`

- [ ] **Step 6: Commit**

```bash
cd /home/maxime/KDE-cli
chmod +x dockerfiles/code-server/agents/install-claude.sh dockerfiles/code-server/agents/install-codex.sh
git add dockerfiles/code-server/agents/ test/test-install-scripts.sh
git commit -m "fix(code-server): install 腳本加 set -eo pipefail 並移入 agents/

curl ... | bash 在沒有 pipefail 時,curl 失敗的退出碼會被末端的
bash/sh 吞掉而回傳 0,使 entrypoint 把安裝失敗誤判為成功。
新增 test/test-install-scripts.sh 以假的 curl 驗證錯誤傳遞。"
```

---

## Task 3: 抽出可測試的 `parse_code_server_args()`

**Files:**
- Modify: `scripts/utils/code-server.sh`（新增 `show_code_server_help()` 與 `parse_code_server_args()`，加在檔案開頭 `#!/bin/bash` 之後、`start_code_server()` 之前）
- Modify: `scripts/code-server/command.sh`（整檔改寫）
- Test: `test/test-code-server-agent-args.sh`（本任務先只寫「解析層」的斷言，Task 4 再補「組裝層」）

**Interfaces:**
- Consumes: 無
- Produces: 供 Task 4 與測試使用的全域變數與函式
  - `show_code_server_help()` — 印說明到 stdout，無回傳值
  - `parse_code_server_args "$@"` — 回傳 `0`=成功、`1`=參數錯誤、`2`=已顯示說明應結束；回填以下全域變數：

    | 變數 | 型別 | 預設 |
    |---|---|---|
    | `CODE_SERVER_DAEMON` | 字串 `true`/`false` | `false` |
    | `CODE_SERVER_PORT` | 字串（數字） | `8080` |
    | `CODE_SERVER_NAME` | 字串 | `code-server` |
    | `CODE_SERVER_OPEN_PATH` | 字串 | `""` |
    | `CODE_SERVER_MOUNTS` | 陣列 | `()` |
    | `CODE_SERVER_AGENTS` | 陣列 | `()` |
    | `CODE_SERVER_AGENTS_CSV` | 字串（逗號分隔） | `""` |

**背景：** 目前 `command.sh` 把解析寫在 top-level，且結尾有 `read -p` 會阻塞，無法直接測試。比照 `7077e48`（pod-exec）的作法把解析抽成函式放進 utils。

---

- [ ] **Step 1: 寫失敗的測試**

建立 `test/test-code-server-agent-args.sh`，完整內容：

```bash
#!/bin/bash

# 測試 kde code-server 的參數解析（parse_code_server_args）
# 比照 test/test-pod-exec-args.sh 的模式

echo "===== code-server 參數解析測試 ====="
echo ""

source "$(dirname "${BASH_SOURCE[0]}")/../scripts/utils/code-server.sh"

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

echo "測試 1：未給 --agent"
echo "--------------------"
rc=0; parse_code_server_args -p 9090 || rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "AGENTS 數量為 0" "0" "${#CODE_SERVER_AGENTS[@]}"
assert_eq "AGENTS_CSV 為空" "" "${CODE_SERVER_AGENTS_CSV}"
assert_eq "PORT 正確解析" "9090" "${CODE_SERVER_PORT}"
echo ""

echo "測試 2：單一 --agent"
echo "--------------------"
rc=0; parse_code_server_args --agent claude || rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "AGENTS_CSV" "claude" "${CODE_SERVER_AGENTS_CSV}"
echo ""

echo "測試 3：多次指定 --agent，順序保留"
echo "----------------------------------"
rc=0; parse_code_server_args --agent claude -a codex || rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "AGENTS 數量為 2" "2" "${#CODE_SERVER_AGENTS[@]}"
assert_eq "AGENTS_CSV 順序保留" "claude,codex" "${CODE_SERVER_AGENTS_CSV}"
echo ""

echo "測試 4：與其他旗標混用"
echo "----------------------"
rc=0; parse_code_server_args -d -p 8081 -n cs-x -a claude || rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "DAEMON" "true" "${CODE_SERVER_DAEMON}"
assert_eq "PORT" "8081" "${CODE_SERVER_PORT}"
assert_eq "NAME" "cs-x" "${CODE_SERVER_NAME}"
assert_eq "AGENTS_CSV" "claude" "${CODE_SERVER_AGENTS_CSV}"
echo ""

echo "測試 5：不合法的 agent 名稱"
echo "---------------------------"
rc=0; parse_code_server_args --agent "bad/name" 2>/dev/null || rc=$?
assert_rc "退出碼為 1" 1 "${rc}"
echo ""

echo "測試 6：--agent 缺少值"
echo "----------------------"
rc=0; parse_code_server_args --agent 2>/dev/null || rc=$?
assert_rc "退出碼為 1" 1 "${rc}"
echo ""

echo "測試 7：--help 回傳 2"
echo "---------------------"
rc=0; parse_code_server_args --help >/dev/null 2>&1 || rc=$?
assert_rc "退出碼為 2" 2 "${rc}"
echo ""

echo "測試 8：說明文字含 --agent"
echo "--------------------------"
help_out=$(show_code_server_help 2>&1)
TOTAL=$((TOTAL+1))
if echo "${help_out}" | grep -q -- "--agent"; then
    echo "  ✅ 說明文字含 --agent"; PASS=$((PASS+1))
else
    echo "  ❌ 說明文字未提到 --agent"; FAIL=$((FAIL+1))
fi
echo ""

echo "測試 9：-v 掛載仍正常解析（回歸）"
echo "--------------------------------"
rc=0; parse_code_server_args -v /tmp/a -v /tmp/b || rc=$?
assert_rc "退出碼為 0" 0 "${rc}"
assert_eq "MOUNTS 數量為 2" "2" "${#CODE_SERVER_MOUNTS[@]}"
assert_eq "第一個 MOUNT" "/tmp/a" "${CODE_SERVER_MOUNTS[0]}"
echo ""

echo "測試 10：未知參數回傳 1"
echo "-----------------------"
rc=0; parse_code_server_args --nosuchflag 2>/dev/null >/dev/null || rc=$?
assert_rc "退出碼為 1" 1 "${rc}"
echo ""

echo "===== 測試完成 ====="
echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `bash test/test-code-server-agent-args.sh`
Expected: FAIL — `parse_code_server_args: command not found`，大量斷言失敗，最後 `❌ 有失敗`

- [ ] **Step 3: 在 `scripts/utils/code-server.sh` 加入兩個函式**

在 `scripts/utils/code-server.sh` 檔案最上方 `#!/bin/bash` 之後、`start_code_server()` 之前，插入：

```bash
# 顯示 kde code-server 的使用說明
show_code_server_help() {
    echo "usage: kde code-server [option]"
    echo ""
    echo "example:"
    echo "  -d, --daemon        在背景執行"
    echo "  -p, --port          指定 code-server 的 port (預設為 8080)"
    echo "  -n, --name          指定 code-server 的容器名稱 (預設為 code-server，可用來同時啟動多個實例)"
    echo "  -v, --volume        指定掛載到 container 的目錄或檔案 (可重複指定多次，預設為當前路徑)"
    echo "                      格式 src[:dst[:ro|rw]]，例如 ./aio 或 .claude:/home/coder/.claude:ro"
    echo "  -w, --workdir       指定 code-server 開啟的資料夾 (container 路徑，預設為第一個目錄型掛載，須位於某個掛載底下)"
    echo "  -a, --agent         啟動時安裝指定的 AI agent (可重複指定多次，例如 claude、codex)"
    echo "                      已安裝者會跳過；設 KDE_CODE_SERVER_AI_AGENTS_REINSTALL=true 可強制重裝"
    echo "  -h, --help          顯示此幫助訊息"
}

# 解析 kde code-server 的參數，結果回填到 CODE_SERVER_* 全域變數
# 回傳 0=成功、1=參數錯誤、2=已顯示說明應結束
parse_code_server_args() {
    CODE_SERVER_DAEMON=false
    CODE_SERVER_PORT=8080
    CODE_SERVER_NAME=code-server
    CODE_SERVER_OPEN_PATH=""
    CODE_SERVER_MOUNTS=()
    CODE_SERVER_AGENTS=()
    CODE_SERVER_AGENTS_CSV=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --daemon|-d)
                CODE_SERVER_DAEMON=true
                shift
                ;;
            --port|-p)
                CODE_SERVER_PORT="$2"
                if [[ -z "${CODE_SERVER_PORT}" || ! ${CODE_SERVER_PORT} =~ ^[0-9]+$ ]]; then
                    echo "無效的 port：${CODE_SERVER_PORT}" >&2
                    return 1
                fi
                shift 2
                ;;
            --name|-n)
                CODE_SERVER_NAME="$2"
                if [[ -z "${CODE_SERVER_NAME}" || ! ${CODE_SERVER_NAME} =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
                    echo "無效的名稱：${CODE_SERVER_NAME}" >&2
                    return 1
                fi
                shift 2
                ;;
            --volume|-v)
                if [[ -z "$2" ]]; then
                    echo "無效的掛載路徑" >&2
                    return 1
                fi
                CODE_SERVER_MOUNTS+=("$2")
                shift 2
                ;;
            --workdir|-w)
                CODE_SERVER_OPEN_PATH="$2"
                if [[ -z "${CODE_SERVER_OPEN_PATH}" ]]; then
                    echo "無效的開啟資料夾路徑" >&2
                    return 1
                fi
                shift 2
                ;;
            --agent|-a)
                if [[ -z "$2" || ! "$2" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
                    echo "無效的 agent 名稱：$2" >&2
                    return 1
                fi
                CODE_SERVER_AGENTS+=("$2")
                shift 2
                ;;
            --help|-h)
                show_code_server_help
                return 2
                ;;
            *)
                echo "未知參數：$1" >&2
                show_code_server_help >&2
                return 1
                ;;
        esac
    done

    # 合併為 docker 環境變數用的逗號分隔字串
    local old_ifs="${IFS}"
    IFS=','
    CODE_SERVER_AGENTS_CSV="${CODE_SERVER_AGENTS[*]}"
    IFS="${old_ifs}"

    return 0
}
```

- [ ] **Step 4: 改寫 `scripts/code-server/command.sh`**

整個檔案內容換成：

```bash
#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/code-server.sh

# 注意：本檔是被 kde.sh source 進去的，而 kde.sh 開了 set -e，
# 因此必須用 `|| rc=$?` 承接非零回傳，不可寫成 `parse...; rc=$?`
rc=0
parse_code_server_args "$@" || rc=$?

if [[ ${rc} -eq 2 ]]; then
    exit 0
fi
if [[ ${rc} -ne 0 ]]; then
    exit 1
fi

read -p "請輸入 code-server 的 password: " PASSWORD

start_code_server "${CODE_SERVER_PORT}" "${CODE_SERVER_DAEMON}" "${CODE_SERVER_NAME}" \
                  "${CODE_SERVER_OPEN_PATH}" \
                  "${CODE_SERVER_MOUNTS[@]}"
```

> **本任務刻意還不把 `CODE_SERVER_AGENTS_CSV` 傳給 `start_code_server`。** `start_code_server` 目前只收 4 個位置參數，要到 Task 4 才會新增第 5 個；現在就傳會造成參數位移，讓 `kde code-server` 在兩個任務之間處於壞掉的狀態。本任務只負責「解析出 agent 清單」，Task 4 負責「把它接到 docker run」。

- [ ] **Step 5: 執行測試確認通過**

Run: `bash test/test-code-server-agent-args.sh`
Expected: PASS — `總測試數：22  通過：22  失敗：0` 並印 `🎉 全部通過`

- [ ] **Step 6: 語法檢查**

Run: `bash -n scripts/utils/code-server.sh && bash -n scripts/code-server/command.sh && echo OK`
Expected: `OK`

- [ ] **Step 7: Commit**

```bash
cd /home/maxime/KDE-cli
git add scripts/utils/code-server.sh scripts/code-server/command.sh test/test-code-server-agent-args.sh
git commit -m "refactor(code-server): 抽出可測試的 parse_code_server_args 並新增 --agent

比照 7077e48 對 pod-exec 的作法,把參數解析與說明文字移進 utils,
使其可在不觸發 read -p 的情況下被測試。新增 -a/--agent 旗標
(可重複指定)並合併為 CODE_SERVER_AGENTS_CSV。
新增 test/test-code-server-agent-args.sh(22 項斷言)。"
```

---

## Task 4: `start_code_server` 傳遞 agent 環境變數

**Files:**
- Modify: `scripts/utils/code-server.sh`（`start_code_server()` 的參數列、新增 `AGENT_ARGS`、兩個 `docker run` 分支、daemon 成功訊息）
- Modify: `test/test-code-server-mounts.sh`（22 處呼叫端補參數）
- Modify: `test/test-code-server-agent-args.sh`（追加「組裝層」斷言）

**Interfaces:**
- Consumes: Task 3 產出的 `CODE_SERVER_AGENTS_CSV`
- Produces: `start_code_server <port> <daemon> <name> <workdir> <agents_csv> [mounts...]` — 第 5 個位置參數為 agents CSV（可為空字串）

---

- [ ] **Step 1: 追加組裝層測試（先失敗）**

在 `test/test-code-server-agent-args.sh` 的 `echo "===== 測試完成 ====="` 那行**之前**插入：

```bash
echo "===== docker 參數組裝層 ====="
echo ""

# 組裝層需要 start_code_server 能跑到 docker run，因此準備假環境並 stub docker
export KDE_PATH="/tmp/kde-test-cs-agents"
export KDE_CLI_PATH="/tmp/kde-test-cs-agents/cli"
export CODE_SERVER_IMAGE="code-server:test"
export PASSWORD="testpass"

rm -rf "${KDE_PATH}"
mkdir -p "${KDE_PATH}/cli" "${KDE_PATH}/dir-a"

docker() {
    case "$1" in
        ps)  return 0 ;;
        run) echo "DOCKER_RUN: $*" ;;
    esac
}
stat() { echo "0"; }

assert_contains() { # $1=描述 $2=字串 $3=樣式
    TOTAL=$((TOTAL+1))
    if echo "$2" | grep -q -- "$3"; then
        echo "  ✅ $1"; PASS=$((PASS+1))
    else
        echo "  ❌ $1：輸出中找不到 '$3'"; FAIL=$((FAIL+1))
    fi
}

assert_not_contains() { # $1=描述 $2=字串 $3=樣式
    TOTAL=$((TOTAL+1))
    if echo "$2" | grep -q -- "$3"; then
        echo "  ❌ $1：輸出中不應出現 '$3'"; FAIL=$((FAIL+1))
    else
        echo "  ✅ $1"; PASS=$((PASS+1))
    fi
}

echo "測試 11：空的 agents CSV 不產生環境變數"
echo "---------------------------------------"
unset KDE_CODE_SERVER_AI_AGENTS_REINSTALL
out=$(start_code_server 8080 false cs-a1 "" "" "${KDE_PATH}/dir-a" 2>&1)
assert_not_contains "不含 KDE_CODE_SERVER_AI_AGENTS" "${out}" "KDE_CODE_SERVER_AI_AGENTS"
echo ""

echo "測試 12：非空 agents CSV 產生環境變數"
echo "-------------------------------------"
out=$(start_code_server 8080 false cs-a2 "" "claude,codex" "${KDE_PATH}/dir-a" 2>&1)
assert_contains "含 KDE_CODE_SERVER_AI_AGENTS=claude,codex" "${out}" "KDE_CODE_SERVER_AI_AGENTS=claude,codex"
echo ""

echo "測試 13：REINSTALL 未設定時不透傳"
echo "---------------------------------"
unset KDE_CODE_SERVER_AI_AGENTS_REINSTALL
out=$(start_code_server 8080 false cs-a3 "" "claude" "${KDE_PATH}/dir-a" 2>&1)
assert_not_contains "不含 REINSTALL" "${out}" "KDE_CODE_SERVER_AI_AGENTS_REINSTALL"
echo ""

echo "測試 14：REINSTALL 設定時透傳"
echo "-----------------------------"
export KDE_CODE_SERVER_AI_AGENTS_REINSTALL=true
out=$(start_code_server 8080 false cs-a4 "" "claude" "${KDE_PATH}/dir-a" 2>&1)
assert_contains "含 REINSTALL=true" "${out}" "KDE_CODE_SERVER_AI_AGENTS_REINSTALL=true"
unset KDE_CODE_SERVER_AI_AGENTS_REINSTALL
echo ""

echo "測試 15：daemon 模式也帶上環境變數"
echo "----------------------------------"
out=$(start_code_server 8080 true cs-a5 "" "codex" "${KDE_PATH}/dir-a" 2>&1)
assert_contains "daemon 分支含 KDE_CODE_SERVER_AI_AGENTS=codex" "${out}" "KDE_CODE_SERVER_AI_AGENTS=codex"
assert_contains "daemon 成功訊息列出 agent" "${out}" "AI Agents: codex"
echo ""

echo "測試 16：掛載仍正常（回歸）"
echo "---------------------------"
out=$(start_code_server 8080 false cs-a6 "" "" "${KDE_PATH}/dir-a" 2>&1)
assert_contains "掛載參數正確" "${out}" "-v ${KDE_PATH}/dir-a:${KDE_PATH}/dir-a"
echo ""

rm -rf "${KDE_PATH}"
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `bash test/test-code-server-agent-args.sh`
Expected: FAIL — 測試 11～16 失敗（此時第 5 個參數被 `start_code_server` 當成掛載路徑，會出現「掛載來源不存在」等錯誤），最後 `❌ 有失敗`

- [ ] **Step 3: 修改 `start_code_server()` 的參數列**

在 `scripts/utils/code-server.sh` 中，把 `start_code_server()` 開頭的：

```bash
start_code_server() {
    local PORT=$1
    local DAEMON=$2
    local NAME=${3:-code-server}
    local OPEN_PATH_ARG=$4
    shift 4
    local -a RAW_MOUNTS=("$@")
```

改為：

```bash
start_code_server() {
    local PORT=$1
    local DAEMON=$2
    local NAME=${3:-code-server}
    local OPEN_PATH_ARG=$4
    local AGENTS_CSV=$5
    shift 5
    local -a RAW_MOUNTS=("$@")
```

- [ ] **Step 4: 組裝 agent 環境變數參數**

在 `scripts/utils/code-server.sh` 中，找到這一段（緊接在 `DOCKER_SOCK_GID` 那行之後、`if [[ "${DAEMON}" == "true" ]]` 之前）：

```bash
    local DOCKER_SOCK_GID
    DOCKER_SOCK_GID=$( (stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock 2>/dev/null) ) || true
```

在其後插入：

```bash
    # AI agent 相關環境變數：僅在有值時才附加，避免傳入空變數
    local -a AGENT_ARGS=()
    if [[ -n "${AGENTS_CSV}" ]]; then
        AGENT_ARGS+=(-e "KDE_CODE_SERVER_AI_AGENTS=${AGENTS_CSV}")
    fi
    if [[ -n "${KDE_CODE_SERVER_AI_AGENTS_REINSTALL:-}" ]]; then
        AGENT_ARGS+=(-e "KDE_CODE_SERVER_AI_AGENTS_REINSTALL=${KDE_CODE_SERVER_AI_AGENTS_REINSTALL}")
    fi
```

- [ ] **Step 5: 兩個 docker run 分支都加上 `"${AGENT_ARGS[@]}"`**

在 `scripts/utils/code-server.sh` 的**兩個** `docker run` 指令中，把這一行：

```bash
        -e "DOCKER_USER=$USER" \
```

改為：

```bash
        -e "DOCKER_USER=$USER" \
        "${AGENT_ARGS[@]}" \
```

> 共有兩處（daemon 與非 daemon 分支），兩處都要改。

- [ ] **Step 6: daemon 成功訊息加上 agent 清單**

在 `scripts/utils/code-server.sh` 中，找到：

```bash
        echo "開啟資料夾: ${OPEN_PATH}"
        echo "存取網址: http://localhost:${PORT}"
```

在兩行之間插入：

```bash
        if [[ -n "${AGENTS_CSV}" ]]; then
            echo "AI Agents: ${AGENTS_CSV}"
        fi
```

- [ ] **Step 7: 接上 command.sh 的呼叫端**

`start_code_server` 現在收 5 個位置參數了。在 `scripts/code-server/command.sh` 中，把：

```bash
start_code_server "${CODE_SERVER_PORT}" "${CODE_SERVER_DAEMON}" "${CODE_SERVER_NAME}" \
                  "${CODE_SERVER_OPEN_PATH}" \
                  "${CODE_SERVER_MOUNTS[@]}"
```

改為：

```bash
start_code_server "${CODE_SERVER_PORT}" "${CODE_SERVER_DAEMON}" "${CODE_SERVER_NAME}" \
                  "${CODE_SERVER_OPEN_PATH}" "${CODE_SERVER_AGENTS_CSV}" \
                  "${CODE_SERVER_MOUNTS[@]}"
```

- [ ] **Step 8: 更新既有掛載測試的呼叫端**

`start_code_server` 多了第 5 個參數，`test/test-code-server-mounts.sh` 的 22 處呼叫都要在第 4 個參數之後插入一個空字串：

```bash
cd /home/maxime/KDE-cli
sed -i -E 's/(start_code_server [0-9]+ (true|false) [A-Za-z0-9_.-]+ "[^"]*")/\1 ""/g' test/test-code-server-mounts.sh
```

- [ ] **Step 9: 驗證改寫結果**

Run:
```bash
cd /home/maxime/KDE-cli
echo "總呼叫數: $(grep -c 'start_code_server ' test/test-code-server-mounts.sh)"
echo "已補參數: $(grep -cE 'start_code_server [0-9]+ (true|false) [A-Za-z0-9_.-]+ "[^"]*" ""' test/test-code-server-mounts.sh)"
```
Expected: 兩個數字都是 `22`。若不相等，用 `grep -n 'start_code_server ' test/test-code-server-mounts.sh` 找出漏掉的那幾行手動補上 `""`。

- [ ] **Step 10: 執行全部相關測試**

Run: `bash test/test-code-server-mounts.sh && bash test/test-code-server-agent-args.sh`
Expected: 兩份都印 `🎉 全部通過`。掛載測試 `失敗：0`；參數測試 `總測試數：29  通過：29  失敗：0`

- [ ] **Step 11: 手動確認 CLI 說明可正常顯示**

Run: `bash -n scripts/utils/code-server.sh && KDE_SCRIPTS_PATH=scripts bash -c 'source scripts/utils/code-server.sh && show_code_server_help'`
Expected: 印出說明文字，其中含 `-a, --agent` 那兩行

- [ ] **Step 12: Commit**

```bash
cd /home/maxime/KDE-cli
git add scripts/utils/code-server.sh test/test-code-server-mounts.sh test/test-code-server-agent-args.sh
git commit -m "feat(code-server): start_code_server 傳遞 AI agent 環境變數

新增第 5 個位置參數 agents CSV,非空時才附加
-e KDE_CODE_SERVER_AI_AGENTS;KDE_CODE_SERVER_AI_AGENTS_REINSTALL
同樣僅在有值時透傳。daemon 成功訊息列出已指定的 agent。
既有 test-code-server-mounts.sh 的 22 處呼叫同步補上參數。"
```

---

## Task 5: Dockerfile 與端到端驗證

**Files:**
- Modify: `.dockerignore`（放行兩個新目錄）
- Modify: `dockerfiles/code-server/Dockerfile:26`（在 `USER coder` 之前插入 COPY 與 chmod）

**Interfaces:**
- Consumes: Task 1 的 `entrypoint.d/`、Task 2 的 `agents/`
- Produces: 內含 `/entrypoint.d/10-ai-agents.sh` 與 `/usr/local/lib/kde-agents/install-*.sh` 的映像

**注意：** build context 是 repo 根目錄（見 `build.sh` 的 `docker build -f Dockerfile ... ../..`），因此 COPY 來源要寫完整相對路徑。

**必讀 —— 原始計畫遺漏的前提：** repo 根目錄的 `.dockerignore` 第 5 行是 `dockerfiles`，會把整個 `dockerfiles/` 從 build context 移除。若不先處理，兩行新的 COPY 會以「來源不存在」失敗（不是路徑寫錯，是檔案根本沒送進 builder）。Docker 的 `.dockerignore` 與 `.gitignore` 不同，**支援用 `!` 從已排除的目錄中重新納入子路徑**（後出現的規則勝出），這點已實測確認。

---

- [ ] **Step 1: 放行 `.dockerignore`**

`.dockerignore` 目前內容：

```
# 此檔僅在以 repo 根目錄為 build context 時生效(目前為 kde-code-server image)。
# 這裡只「排除」明顯不需要進 image 的東西,新增要安裝的檔案/目錄不必在此登記。
.git
.gitignore
dockerfiles
examples
test
test.sh
*.md
```

整份換成：

```
# 此檔僅在以 repo 根目錄為 build context 時生效(目前為 kde-code-server image)。
# 這裡只「排除」明顯不需要進 image 的東西。
#
# 例外:dockerfiles/ 整個被排除,但 code-server image 需要把 entrypoint.d/ 與
# agents/ COPY 進映像,所以用 ! 個別放行。Docker 的 .dockerignore 與 .gitignore
# 不同,後出現的規則勝出,可以從已排除的目錄中重新納入子路徑。
# 若日後新增類似「要進 image 的 dockerfiles/ 子目錄」,同樣要在這裡加一行 !。
.git
.gitignore
dockerfiles
!dockerfiles/code-server/entrypoint.d
!dockerfiles/code-server/agents
examples
test
test.sh
*.md
```

- [ ] **Step 2: 修改 Dockerfile**

在 `dockerfiles/code-server/Dockerfile` 中，把最後兩行：

```dockerfile
RUN cd /tmp/kde-src && bash local-install.sh && cd / && rm -rf /tmp/kde-src

USER coder
```

改為：

```dockerfile
RUN cd /tmp/kde-src && bash local-install.sh && cd / && rm -rf /tmp/kde-src

# AI agent 安裝機制：
# - /entrypoint.d 是 code-server base image 內建的啟動 hook(coder/code-server#5177),
#   base entrypoint 會在啟動 code-server 前執行其中所有可執行檔。用它就不必覆寫
#   ENTRYPOINT(內建的 --bind-addr 0.0.0.0:8080 . 等參數不必手動複製)。
# - 新增 agent 只要往 agents/ 丟一支 install-<name>.sh,不需改 entrypoint 邏輯。
COPY dockerfiles/code-server/entrypoint.d/ /entrypoint.d/
COPY dockerfiles/code-server/agents/ /usr/local/lib/kde-agents/
RUN chmod 0755 /entrypoint.d/*.sh /usr/local/lib/kde-agents/*.sh

USER coder
```

- [ ] **Step 3: Build 映像**

Run:
```bash
cd /home/maxime/KDE-cli/dockerfiles/code-server
docker build -f Dockerfile -t kde-code-server:agent-test ../..
```
Expected: build 成功，最後印 `Successfully tagged kde-code-server:agent-test`（或 buildkit 的等價訊息）。
若本機沒有 layer cache，前面的 apt-get 步驟可能要跑數分鐘，屬正常。

- [ ] **Step 4: 驗證檔案有進到映像且可執行**

Run:
```bash
docker run --rm -u "$(id -u):$(id -g)" --entrypoint bash kde-code-server:agent-test -lc \
  'ls -l /entrypoint.d /usr/local/lib/kde-agents && test -x /entrypoint.d/10-ai-agents.sh && echo EXECUTABLE_OK'
```
Expected: 列出 `10-ai-agents.sh`、`install-claude.sh`、`install-codex.sh` 三個檔且權限為 `-rwxr-xr-x`，最後印 `EXECUTABLE_OK`

- [ ] **Step 5: 驗證未指定 agent 時完全靜默**

Run:
```bash
docker run --rm -u "$(id -u):$(id -g)" --entrypoint bash kde-code-server:agent-test -lc \
  '/entrypoint.d/10-ai-agents.sh; echo "rc=$?"'
```
Expected: 只印 `rc=0`，沒有其他輸出

- [ ] **Step 6: 驗證不認識的 agent 只警告且不阻擋**

Run:
```bash
docker run --rm -u "$(id -u):$(id -g)" -e KDE_CODE_SERVER_AI_AGENTS=nosuch \
  --entrypoint bash kde-code-server:agent-test -lc \
  '/entrypoint.d/10-ai-agents.sh; echo "rc=$?"'
```
Expected: 印出 `⚠ 不認識的 AI agent：nosuch`、`可用：claude codex`（順序可能不同），最後 `rc=0`

- [ ] **Step 7: 端到端安裝驗證（需連網）**

Run:
```bash
docker run --rm -u "$(id -u):$(id -g)" -e KDE_CODE_SERVER_AI_AGENTS=claude,codex \
  --entrypoint bash kde-code-server:agent-test -lc \
  '/entrypoint.d/10-ai-agents.sh; echo "rc=$?"; ls -l "$HOME/.local/bin"'
```
Expected: 印出兩個 `→ 安裝 ...` / `✓ ... 安裝完成`，`rc=0`，且 `$HOME/.local/bin` 中出現 `claude` 與 `codex` 兩個可執行檔。

> 若某個 agent 安裝失敗（上游變動、公司網路擋外連），預期看到 `❌ ... 安裝失敗` 但 `rc=0` — 這正是設計要的行為，**不算本任務失敗**。此時請把實際錯誤訊息記錄下來回報，不要為了讓它過而修改 entrypoint 的錯誤處理邏輯。

- [ ] **Step 8: 驗證 PATH 有寫進 shell profile**

Run:
```bash
docker run --rm -u "$(id -u):$(id -g)" -e KDE_CODE_SERVER_AI_AGENTS=claude \
  --entrypoint bash kde-code-server:agent-test -lc \
  '/entrypoint.d/10-ai-agents.sh >/dev/null 2>&1; grep -c ">>> kde-cli agents PATH >>>" "$HOME/.bashrc"'
```
Expected: `1`（比對開頭 guard；區塊開頭與結尾兩行都含 `kde-cli agents PATH`，只比對那段會數成 2）

- [ ] **Step 9: 清理測試映像**

Run: `docker rmi kde-code-server:agent-test`
Expected: 成功移除（若有容器仍在使用會失敗，此時先 `docker ps -a` 清掉）

- [ ] **Step 10: Commit**

```bash
cd /home/maxime/KDE-cli
git add dockerfiles/code-server/Dockerfile
git commit -m "build(code-server): COPY entrypoint.d 與 agents 進映像

/entrypoint.d 是 base image 內建的啟動 hook,不需覆寫 ENTRYPOINT。
新增 agent 只要往 agents/ 丟一支 install-<name>.sh。"
```

---

## Task 6: 文件同步

**Files:**
- Modify: `kde.sh:63`（頂層 code-server 說明行）
- Modify: `docs/core/quick-reference.md`（`kde code-server` 區塊，約 267–305 行）
- Modify: `.claude/skills/kde-usage/references/quick-reference.md`（同上，約 265–303 行）
- Modify: `.claude/skills/kde-usage/SKILL.md`（若其中有 code-server 旗標說明則同步；目前只有一處泛指提及，確認後可不改）

**Interfaces:**
- Consumes: Task 3 的 `--agent` 旗標與 Task 4 的環境變數行為
- Produces: 無（純文件）

**背景：** CLAUDE.md 規定任何影響 `kde` 指令用法的改動，都必須同步 `docs/` 與 `.claude/skills/kde-usage/` 底下的對應文件（**專案內的 skill，不是 `~/.claude/skills/` 的安裝副本**）。

---

- [ ] **Step 1: 更新 `kde.sh` 的頂層說明**

在 `kde.sh` 第 63 行，把：

```
    echo "  code-server [-d] [-p port] [-n name] [-v dir] [-w dir]   啟動 code-server，-d 背景執行，-p 指定 port，-n 指定容器名稱(可同時啟動多個)，-v 指定掛載目錄或檔案，格式 src[:dst[:ro|rw]](可重複指定多次，預設當前路徑)，-w 指定開啟的資料夾"
```

改為：

```
    echo "  code-server [-d] [-p port] [-n name] [-v dir] [-w dir] [-a agent]   啟動 code-server，-d 背景執行，-p 指定 port，-n 指定容器名稱(可同時啟動多個)，-v 指定掛載目錄或檔案，格式 src[:dst[:ro|rw]](可重複指定多次，預設當前路徑)，-w 指定開啟的資料夾，-a 啟動時安裝 AI agent(可重複指定多次)"
```

- [ ] **Step 2: 更新 `docs/core/quick-reference.md`**

在 `docs/core/quick-reference.md` 中找到：

```
# 組合使用
kde code-server -p 9090 -d
```

在這兩行**之前**插入：

```
# 啟動時安裝 AI agent（-a 可重複指定多次，目前支援 claude、codex）
kde code-server -a claude
kde code-server --agent claude --agent codex
# 已安裝的 agent 會跳過；agent 裝在容器的 ~/.local/bin，隨 code-server 設定目錄持久保存
# 安裝失敗只會警告，不會阻擋 code-server 啟動
# 強制重裝：
KDE_CODE_SERVER_AI_AGENTS_REINSTALL=true kde code-server -a claude

```

- [ ] **Step 3: 更新 skill 的 quick-reference**

在 `.claude/skills/kde-usage/references/quick-reference.md` 中找到同樣的：

```
# 組合使用
kde code-server -p 9090 -d
```

在其之前插入與 Step 2 **完全相同**的那段內容。

- [ ] **Step 4: 檢查 SKILL.md 是否需要更動**

Run: `grep -n 'code-server' .claude/skills/kde-usage/SKILL.md`
Expected: 只有第 8 行的觸發條件泛指提及 `code-server`，沒有旗標清單。
- 若輸出**只有**第 8 行 → 不需修改，跳到 Step 5。
- 若出現任何列出 `-d` / `-p` / `-v` 旗標的區塊 → 在該處補上 `-a, --agent` 一行，格式比照既有旗標。

- [ ] **Step 5: 驗證三份文件一致**

Run:
```bash
cd /home/maxime/KDE-cli
for f in docs/core/quick-reference.md .claude/skills/kde-usage/references/quick-reference.md; do
  echo "=== $f: $(grep -c 'kde code-server -a claude' "$f") ==="
done
grep -c '\-a agent' kde.sh
```
Expected: 兩份 quick-reference 各印 `1`，`kde.sh` 印 `1`

- [ ] **Step 6: 跑一次全部測試作為最終確認**

Run:
```bash
cd /home/maxime/KDE-cli
for t in test/test-agent-entrypoint.sh test/test-install-scripts.sh \
         test/test-code-server-agent-args.sh test/test-code-server-mounts.sh \
         test/test-pipeline-args.sh test/test-allow-failure.sh test/test-only-manual.sh \
         test/test-pod-exec-args.sh; do
  echo "===== $t ====="
  bash "$t" || echo "!!! FAILED: $t"
done
```
Expected: 每份都印 `🎉 全部通過`，沒有任何 `!!! FAILED` 行

- [ ] **Step 7: Commit**

```bash
cd /home/maxime/KDE-cli
git add kde.sh docs/core/quick-reference.md .claude/skills/kde-usage/
git commit -m "docs: 同步 code-server --agent 說明

依 CLAUDE.md 規則同步 kde.sh 頂層說明、docs/core/quick-reference.md
與專案內的 kde-usage skill。"
```

---

## 完成檢查清單

- [ ] `bash test/test-agent-entrypoint.sh` → 10/10 通過
- [ ] `bash test/test-install-scripts.sh` → 6/6 通過
- [ ] `bash test/test-code-server-agent-args.sh` → 29/29 通過
- [ ] `bash test/test-code-server-mounts.sh` → 全數通過（回歸未壞）
- [ ] `docker build` 成功，映像內三個腳本存在且可執行
- [ ] 容器內實際跑 `/entrypoint.d/10-ai-agents.sh` 能裝出 `claude` 與 `codex`
- [ ] `kde code-server -h` 顯示 `-a, --agent` 說明
- [ ] 三份文件（`kde.sh`、`docs/`、專案內 skill）已同步
