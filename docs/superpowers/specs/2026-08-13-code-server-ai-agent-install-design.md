# code-server 依啟動參數安裝 AI Agent — 設計文件

日期：2026-08-13
狀態：待核准

## 背景

`kde code-server` 啟動的容器是開發者的主要工作環境，需要在裡面使用 AI coding agent（Claude Code、Codex 等）。把所有 agent 都 bake 進映像會讓映像變大、且無法讓使用者依情境選擇；因此改為**啟動時依參數決定安裝哪些 agent**。

### 現況驗證結果（實測 `r82wei/kde-code-server`）

以下事實決定了整個設計，實作時不可推翻：

| 項目 | 實測結果 |
|---|---|
| Image ENTRYPOINT | `["/usr/bin/entrypoint.sh","--bind-addr","0.0.0.0:8080","."]`，CMD 為 null |
| 內建啟動 hook | 有。`ENTRYPOINTD=/entrypoint.d`，base entrypoint 會 `find "${ENTRYPOINTD}" -type f -executable -exec {} \;` 再 `exec dumb-init /usr/bin/code-server "$@"`（coder/code-server#5177） |
| base entrypoint shell 選項 | `set -eu` |
| `/entrypoint.d` 目錄 | **映像中不存在**，需自行建立 |
| node / npm | **無**。只有 code-server 自帶的 `/usr/lib/code-server/lib/node`（不在 PATH），沒有 `npm`/`npx` |
| sudo | 可用（`/etc/sudoers.d/nopasswd` 內含 `coder ALL=(ALL) NOPASSWD:ALL`） |
| 可用工具 | `curl`、`git`、`tar`、`gzip` 有；`unzip`、`rg` 無 |
| PATH | `/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games`（**不含 `~/.local/bin`**） |
| HOME | `/home/coder` |
| `/home/coder` | 被 `-v "${KDE_PATH}/.code-server/${NAME}:/home/coder"` 蓋掉 → **host 持久卷**，重啟後內容仍在 |
| 執行身分 | `docker run -u "$(id -u):$(id -g)"`；`/home/coder` 由 host 端使用者建立，可寫 |

## 目標

- `docker run` 時以環境變數 `KDE_AI_AGENTS` 指定要安裝的 agent（逗號分隔，可多個）。
- `kde code-server --agent <name>` 可重複指定，組裝成該環境變數傳入。
- 已安裝者跳過，可用 `KDE_AI_AGENTS_REINSTALL=true` 強制重裝。
- 單一 agent 安裝失敗只警告，不阻擋 code-server 啟動。
- 新增第三、第四個 agent 時**不需修改 entrypoint 邏輯**，只需新增一支安裝腳本。

## 非目標（YAGNI）

- 不支援版本鎖定語法（`claude@1.2.3`）。
- 不支援 argv 旗標形式（`image --agent x`）；只用環境變數。
- 不做 `KDE_AI_AGENTS_STRICT`（失敗即退出）模式。
- 不覆寫映像的 ENTRYPOINT。
- 不處理 agent 的登入 / 認證（使用者自行在容器內完成；credential 隨 `/home/coder` 持久卷保存）。

## 架構

### 檔案配置

```
dockerfiles/code-server/
├── Dockerfile
├── entrypoint.d/
│   └── 10-ai-agents.sh          → /entrypoint.d/10-ai-agents.sh
└── agents/
    ├── install-claude-code.sh   → /usr/local/lib/kde-agents/install-claude-code.sh
    └── install-codex.sh         → /usr/local/lib/kde-agents/install-codex.sh
```

現有的 `dockerfiles/code-server/entrypoint.sh`、`install-claude-code.sh`、`install-codex.sh` 三個空檔搬移至上述位置（`entrypoint.sh` → `entrypoint.d/10-ai-agents.sh`）。

Dockerfile 於 `USER coder` 之前加入：

```dockerfile
COPY dockerfiles/code-server/entrypoint.d/ /entrypoint.d/
COPY dockerfiles/code-server/agents/ /usr/local/lib/kde-agents/
RUN chmod 0755 /entrypoint.d/*.sh /usr/local/lib/kde-agents/*.sh
```

> 注意：build context 是 repo 根目錄（見 `build.sh`），故 COPY 來源需寫完整相對路徑。

### 為何用 `/entrypoint.d` 而非自訂 ENTRYPOINT

映像的 ENTRYPOINT 已內建 `--bind-addr 0.0.0.0:8080 .` 三個參數，並在 `exec` 前處理 `fixuid` 與 `DOCKER_USER` 改名。自行包一層必須正確複製這些內建參數，且上游一改就會失效。使用官方 `/entrypoint.d` hook 可完全避免。

代價：hook 腳本是被 `find -exec` 以獨立程序執行，**其環境變數無法傳遞給 code-server**，因此 PATH 必須透過 shell profile 處理（見下節）。

## 行為規格

### `10-ai-agents.sh`

執行時機：`fixuid` 與 `DOCKER_USER` 改名之後、code-server 啟動之前（安裝過程會阻塞啟動）。

```
1. 讀 KDE_AI_AGENTS；未設定或為空 → 直接 exit 0（完全靜默）
2. export PATH="$HOME/.local/bin:$PATH"     # 僅供本程序偵測用
3. 確保 $HOME/.local/bin 存在
4. 冪等寫入 PATH 到 $HOME/.bashrc 與 $HOME/.profile（見「PATH 傳遞」）
5. 以 IFS=, 切分 KDE_AI_AGENTS，逐一處理（去除前後空白、忽略空欄位）
     a. SCRIPT=/usr/local/lib/kde-agents/install-<name>.sh
     b. SCRIPT 不存在 → 記為 unknown，印出可用清單，continue
     c. KDE_AI_AGENTS_REINSTALL != true 且 command -v <name> 成功 → 記為 skipped，continue
     d. 執行 bash "$SCRIPT"；成功記為 installed，失敗記為 failed（僅印訊息，不中斷）
6. 印出彙總（installed / skipped / unknown / failed 各一行）
7. exit 0（無條件）
```

**`exit 0` 是硬性要求。** base entrypoint 為 `set -eu`，且 `find -exec` 的行為在不同實作下對非零退出的處理不一致；無條件 `exit 0` 是唯一能保證「安裝失敗仍啟動 code-server」的作法。腳本本身**不使用** `set -e`，以免中途安裝失敗直接中止後續 agent。

### 命名約定

- 安裝腳本檔名：`install-<name>.sh`
- **`<name>` 同時是安裝後的可執行檔名**，作為 `command -v` 偵測依據。
  - `claude-code` → binary `claude-code`；若上游安裝器產生的是 `claude`，安裝腳本負責在 `$AGENT_BIN_DIR` 建立 `claude-code` symlink 指向它（兩個名稱都可用）。
- 可用清單由 `ls /usr/local/lib/kde-agents/install-*.sh` 動態產生，entrypoint 不硬編任何 agent 名稱。

### 安裝腳本契約

entrypoint 呼叫時提供：

| 變數 | 內容 |
|---|---|
| `AGENT_NAME` | agent 名稱（= 檔名中的 `<name>`） |
| `AGENT_BIN_DIR` | `$HOME/.local/bin`（已建立） |
| `KDE_AI_AGENTS_REINSTALL` | `true` / 未設定 |

腳本責任：
- 使用 `set -eo pipefail`（符合專案慣例），成功 `exit 0`、失敗非零。
- 只寫入 `$AGENT_BIN_DIR` 與 `$HOME` 底下；**不使用 sudo**、不寫 `/usr/local`（該處位於映像層，`docker rm` 後即失效，會使快取失效）。
- 不得依賴 `npm`（映像無 node/npm），改用原生安裝器或 GitHub release tarball。
- 不得依賴 `unzip`（映像無此工具）；`tar`/`gzip`/`curl`/`git` 可用。
- 下載 URL 於實作時**實際驗證後**才寫入，不憑記憶填寫。

### 安裝位置與 PATH 傳遞

安裝目標為 `$HOME/.local/bin`（= `/home/coder/.local/bin`），位於 host 持久卷內，因此重啟或重建容器後仍在，快取才有意義。

`$HOME/.local/bin` 不在預設 PATH，且 hook 腳本的 export 無法傳給 code-server，故：

- 冪等地在 `$HOME/.bashrc` 與 `$HOME/.profile` 各追加一段（以 guard 字串 `# >>> kde-cli agents PATH >>>` 判斷是否已存在）：
  ```sh
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
  export PATH
  ```
- 兩檔在持久卷中可能不存在（空目錄蓋掉映像的 `/home/coder`），腳本需能自建。
- code-server 整合終端機啟動 bash 時會 source `.bashrc`，即可看到 agent。

### CLI：`kde code-server --agent`

`scripts/code-server/command.sh`：
- 新增 `--agent` / `-a`，可重複指定，累積進 `AGENTS=()`。
- 值驗證：`^[a-zA-Z0-9][a-zA-Z0-9_.-]*$`（與 `--name` 同一套規則），不合法即報錯退出。
- `show_help` 新增說明行。

`scripts/utils/code-server.sh` 的 `start_code_server()`：
- 新增參數接收 agent 清單，以 `IFS=,` 合併為字串。
- **僅在非空時**附加 `-e KDE_AI_AGENTS=...`，使用 `${AGENTS_ENV:+-e "KDE_AI_AGENTS=${AGENTS_ENV}"}` 避免傳入空變數。
- 同步透傳 `KDE_AI_AGENTS_REINSTALL`（同樣僅在非空時附加），使用者以環境變數控制，不新增旗標。
- daemon 與非 daemon 兩個 `docker run` 分支都要加。
- daemon 分支的成功訊息追加一行「AI Agents: xxx」（有指定時才印）。

> `start_code_server` 目前的參數是位置式且尾端吃 `"$@"` 作為掛載清單，新增參數需插在 `shift 4` 之前並改為 `shift 5`；`test/test-code-server-mounts.sh` 的呼叫端要同步更新。

## 錯誤處理

| 情境 | 行為 |
|---|---|
| `KDE_AI_AGENTS` 未設定 / 空 | 靜默結束，無任何輸出 |
| 名稱不認識 | ⚠ 警告 + 列出可用 agent，繼續處理下一個 |
| 已安裝且未指定重裝 | ✓ 訊息，跳過 |
| 安裝腳本非零退出（網路不通、下載失敗） | ❌ 警告，繼續處理下一個 |
| 全部失敗 | 仍 `exit 0`，code-server 正常啟動 |
| CLI 給了不合法的 `--agent` 值 | CLI 端即報錯退出，不啟動容器 |

## 測試

沿用 `test/test-code-server-mounts.sh` 的模式（設 `CODE_SERVER_IMAGE=code-server:test`、stub 掉 `docker`，不實際啟動容器）。

**`test/test-code-server-agent-args.sh`** — CLI 與 docker 組裝層

`scripts/code-server/command.sh` 目前把參數解析寫在 top-level，且結尾有 `read -p` 會阻塞，無法直接測試。比照上一個 commit（`7077e48` 對 pod-exec 的作法）先把解析抽成可測試函式 `parse_code_server_args()`，回填 `DAEMON`/`PORT`/`NAME`/`MOUNT_PATHS`/`OPEN_PATH`/`AGENTS`，`read -p` 與 `start_code_server` 留在 top-level。

測試項目：
- 解析層：未給 `--agent` → `AGENTS` 為空；多次指定 → 陣列順序保留；不合法名稱 → 非零退出並印錯誤；`--agent` 缺值 → 報錯
- 組裝層（source `code-server.sh`、stub `docker`，同 mounts 測試）：
  - 空 agent 清單 → docker 指令中不含 `KDE_AI_AGENTS`
  - `claude-code,codex` → 含 `-e KDE_AI_AGENTS=claude-code,codex`
  - `KDE_AI_AGENTS_REINSTALL=true` → 透傳；未設定 → 不出現

**`test/test-agent-entrypoint.sh`** — entrypoint 層
- 以臨時目錄假造 `AGENT_DIR`（放假的 `install-foo.sh`）與 `HOME`
- 空 `KDE_AI_AGENTS` → exit 0 且無輸出
- 未知名稱 → 警告訊息含可用清單，exit 0
- 假腳本回傳 1 → 標記 failed，exit 0，且後續 agent 仍被處理
- binary 已存在 → 標記 skipped、不執行安裝腳本
- `KDE_AI_AGENTS_REINSTALL=true` → 即使已存在仍執行安裝腳本
- 重複執行兩次 → `.bashrc` 中的 PATH 區塊只出現一次（冪等）

為了可測試，`10-ai-agents.sh` 需允許以環境變數覆寫 `AGENT_DIR`（預設 `/usr/local/lib/kde-agents`），與 `pod-exec` 的可測試參數解析同一手法。

## 文件更新

依 CLAUDE.md 規則，同步：
- `docs/core/quick-reference.md` — `kde code-server` 旗標表
- `.claude/skills/kde-usage/SKILL.md`
- `.claude/skills/kde-usage/references/quick-reference.md`

（本次不涉及 pipeline 行為，`docs/core/cicd-pipeline.md` 不需改。）

## 實作順序

1. 搬移空檔到 `entrypoint.d/` 與 `agents/`，寫 `10-ai-agents.sh` 與 `test/test-agent-entrypoint.sh`
2. 驗證上游安裝方式後撰寫兩支 `install-*.sh`
3. Dockerfile 加 COPY / chmod
4. CLI `--agent` + `test/test-code-server-agent-args.sh`
5. 文件與 skill 同步
6. 實際 build 映像跑一次端到端驗證（首次安裝、二次跳過、未知名稱、斷網失敗）
