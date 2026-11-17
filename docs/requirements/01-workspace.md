# 01 Workspace 與主機整合

回到 [總覽](README.md)。狀態標記的意義見 [總覽](README.md#需求狀態標記)。

所有命令在執行前都會經過 `kde.sh` 的共同前置流程，依序是：
解析全域旗標 → 定位 workspace（UC-WS-01）→ 處理不需要 workspace 的命令 →
載入 `kde.env` → 補齊預設映像（UC-WS-06）→ 決定當前環境（[UC-ENV-01](02-environment.md#uc-env-01-決定當前環境)）→ 分派命令。

不需要 `kde.env` 就能執行的命令只有：`init`、`version`、`list`、`alias`、`help`、`claude-skill`。

---

### UC-WS-01 定位 workspace

**狀態**：✅ 已確認

> 身為在容器內執行的 AI agent，我想要明確指定 workspace 路徑，以便不論當前目錄在哪，都能操作同一個 workspace。
>
> 身為開發者，我想要在 workspace 的任何子目錄下執行 `kde`，以便不必先切回根目錄。

- **命令**：`kde [-C <path> | --workspace <path>] <command>`，或環境變數 `KDE_PATH`
- **主要流程**（明確指定）：
  1. 使用者以 `-C` 或 `KDE_PATH` 指定路徑。兩者並存時 `-C` 優先。
  2. 系統把 `-C` 的路徑轉成絕對路徑（之後會被寫進容器的 `-v` 與 `--workdir`，相對路徑會讓 Docker 失敗）。
  3. 系統以該路徑為 workspace 根目錄，**不往上搜尋**。
- **替代流程**（未指定）：由 `$PWD` 逐層往上找 `kde.env`，找到為止；走到 `/` 都沒有就退回 `$PWD`。
- **例外流程**：

  | 情況 | 行為 |
  |---|---|
  | `-C` 後面沒有路徑 | stderr 報錯，結束碼 1 |
  | 明確指定的目錄不存在 | stderr「指定的 workspace 目錄不存在」，結束碼 1 |
  | 明確指定的目錄存在但沒有 `kde.env` | stderr「指定的 workspace 沒有 kde.env」，並建議 `kde -C <path> init` |
  | 未指定且找不到 `kde.env` | 「kde.env 不存在，請先執行 kde init 初始化環境」，結束碼 1 |

- **限制**：`-C` 必須寫在子命令之前。
- **設計理由**（程式碼註解）：
  - 區分「目錄不存在」與「不是 workspace」，是因為混成一句會讓打錯路徑的人去找 `kde.env`。
  - 明確指定失敗時不建議裸的 `kde init`，因為容器內的 agent 照做會把模板灌進自己的家目錄。
  - 選 `-C` 而不是 `-w`，是因為 `kde code-server -w` 已經代表「開啟哪個資料夾」，兩者會出現在同一行。
- 出處：`kde.sh:15-79`、`kde.sh:181-191`　測試：`test/test-kde-path-resolution.sh`

---

### UC-WS-02 初始化 workspace

**狀態**：⚠️ 有落差

> 身為開發者，我想要把一個目錄變成 KDE workspace，以便開始建立環境。

- **命令**：`kde init`（`--init` 等效）
- **前置條件**：無。
- **主要流程**：
  1. 建立空的 `kde.env`。
  2. 複製 `templates/init/` 的內容到 workspace（目前只有 `.gitignore`）。
  3. 複製 CLI 的 `docs/` 到 `<workspace>/docs/kde-cli`。
- **結果**：工具映像的預設值不在這一步寫入，而是在第一次執行其他命令時補上（UC-WS-06）。
- **落差**：在全新目錄執行會失敗；重複執行會產生巢狀目錄。見 [GAP-02](09-gaps.md#gap-02)、[GAP-03](09-gaps.md#gap-03)。
- 出處：`kde.sh:140-145`

---

### UC-WS-03 取得 CLI 文件

**狀態**：📄 未文件化

> 身為開發者，我想要把 KDE-CLI 的文件放進 workspace，以便 workspace 裡的 AI agent 讀得到（推定，依 `TODO.md`「產生 AI agent 可以看的文件」）。

- **命令**：`kde docs`
- **前置條件**：workspace 已初始化。
- **主要流程**：複製 CLI 的 `docs/` 到 `<workspace>/docs/kde-cli`，印出「kde-cli 文件已建立」。
- **替代流程**：目標已存在時詢問是否覆蓋，回答不是 `y` 就結束。
- **落差**：覆蓋時實際上是複製進既有目錄，見 [GAP-03](09-gaps.md#gap-03)。`docs/core/` 沒有記載這個命令。
- 出處：`kde.sh:285-296`

---

### UC-WS-04 – 05 版本與說明

**狀態**：✅ 已確認

| ID | 命令 | 行為 | 出處 |
|---|---|---|---|
| UC-WS-04 | `kde version`、`-v`、`--version` | 印出 `KDE_VERSION` | `kde.sh:146-149` |
| UC-WS-05 | `kde`、`kde help`、`-h`、`--help` | 印出頂層說明 | `kde.sh:94-136`、`163-166` |

未知的頂層命令也是印出說明，但會先經過完整的前置流程（需要 `kde.env`），結束碼為 0（`kde.sh:389-391`）。❓ 見 [待確認 Q7](09-gaps.md#待確認事項)。

---

### UC-WS-06 統一工具版本

**狀態**：✅ 已確認

> 身為團隊，我想要把所有工具的映像版本記錄在版控檔裡，以便每個成員用到相同版本。

- **觸發**：任何需要 workspace 的命令。
- **主要流程**：對下列每個變數，若 `kde.env` 沒有設定，就採用內建預設值並**附加寫入 `kde.env`**。

  | 變數 | 預設值 |
  |---|---|
  | `KIND_IMAGE` | `r82wei/kind:v0.27.0` |
  | `K3D_IMAGE` | `r82wei/k3d:v5.8.3` |
  | `KDE_DEPLOY_ENV_IMAGE` | `r82wei/deploy-env:1.0.0` |
  | `NGROK_PROXY_IMAGE` | `r82wei/ngrok-proxy:1.0.0` |
  | `CLOUDFLARE_TUNNEL_PROXY_IMAGE` | `r82wei/cloudflare-tunnel-proxy:1.0.0` |
  | `K8S_UI_DASHBOARD_IMAGE` | `kubernetesui/dashboard:v2.7.0` |
  | `K9S_IMAGE` | `r82wei/k9s:v0.50.18` |
  | `TELEPRESENCE_IMAGE` | `r82wei/telepresence:1.0.6` |
  | `CODE_SERVER_IMAGE` | `docker.io/r82wei/kde-code-server:latest` |
  | `OPENCLAW_IMAGE` | `docker.io/r82wei/kde-openclaw:latest` |

- **未涵蓋**：Headlamp 與 ngrok 官方映像寫死在程式碼裡，不受 `kde.env` 控制，見 [GAP-17](09-gaps.md#gap-17)。
- 出處：`kde.sh:203-243`；`docs/principle.md`「標準化映像管理」

---

### UC-WS-07 除錯模式

**狀態**：✅ 已確認

> 身為 DevOps，我想要看到 CLI 實際執行的每一行指令，以便診斷問題。

- **設定**：`kde.env` 的 `KDE_DEBUG` 設為 `false` 以外的任何值。
- **行為**：載入 `kde.env` 之後開啟 `set -x`。
- 出處：`kde.sh:198-201`；`docs/core/workspace.md`「Debug 模式」

---

### UC-WS-08 建立進入 workspace 的捷徑

**狀態**：✅ 已確認

> 身為開發者，我想要用一個短指令進入某個 workspace 的 tmux session，以便快速切換工作。

- **命令**：`kde alias <name> [path]`
- **前置條件**：主機已安裝 tmux（CLI 不檢查）。不需要 `kde.env`。
- **主要流程**：把 `alias <name>='tmux new-session -A -s <name> -c <path>'` 附加到 `~/.bashrc` 與 `~/.zshrc`（存在的才寫）。未給 `path` 時用當前目錄。
- **例外流程**：沒有參數或 `-h` 顯示說明；參數超過兩個時不做任何事也不報錯。
- 這是唯一修改使用者 shell 設定檔的命令，且重複執行會附加重複的行。
- 出處：`scripts/alias/command.sh`

---

### UC-WS-09 安裝 Claude Code skill

**狀態**：✅ 已確認

> 身為使用 Claude Code 的開發者，我想要讓 Claude 了解 `kde` 的用法，以便它能正確操作我的 workspace。

- **命令**：`kde claude-skill <install|update|status>`
- **前置條件**：不需要 `kde.env`。
- **主要流程**：

  | 動作 | 行為 |
  |---|---|
  | `install`、`update` | 把 CLI 內的 `.claude/skills/kde-usage` 複製到 `~/.claude/skills/`（兩者完全相同） |
  | `status` | 檢查 `~/.claude/skills/kde-usage/SKILL.md` 是否存在，存在時印出其 description |

- **例外流程**：CLI 內找不到 skill 來源目錄時 stderr 報錯，結束碼 1；未知動作顯示說明，結束碼 1。
- **相關**：OpenClaw 容器不走這條路，而是直接掛載 CLI 內的 skill（[UC-DEV-03](07-dev-containers.md#uc-dev-03-啟動-openclaw-gateway)），理由是複製的副本會在 CLI 升級後過期。同樣的過期風險也存在於這個命令安裝的副本。
- 出處：`scripts/claude-skill/command.sh`；`docs/core/dev-tools/claude-skill.md`
