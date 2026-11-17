# 07 開發容器：code-server 與 OpenClaw

回到 [總覽](README.md)。

這兩個命令各自啟動一個**長時間運行的容器**，讓人或 AI agent 在裡面工作，並且在容器內也能使用 `kde`。
它們是 CLI 中最新的部分（2026-07 之後），程式碼註解對設計理由的記錄也最完整。

兩者共同的條件：

| 條件 | 目的 |
|---|---|
| 把主機的 CLI 安裝目錄以**唯讀**掛到容器的 `/usr/local/lib/kde` | 容器內的 `kde` 永遠與主機同版本，不會過期 |
| 掛入 `docker.sock`（唯讀）並加入其群組 | 容器內的 `kde` 能操作主機的 Docker（DooD） |
| 以主機使用者的 uid:gid 執行 | 產生的檔案在主機上屬於使用者 |

因為掛載綁定的是目錄的 inode，重裝 CLI 時不能刪掉再重建安裝目錄，見 [CON-04](08-non-functional.md#con-04-重裝不得破壞運行中的容器)。

---

## code-server

### UC-DEV-01 啟動瀏覽器版的編輯器

**狀態**：⚠️ 有落差

> 身為開發者，我想要用瀏覽器開啟一個已經接好 workspace 與 `kde` 的 VS Code，以便在任何裝置上開發。
>
> 身為開發者，我想要同時開多個各自只看得到特定專案的實例，以便隔離不同的工作。

- **命令**：`kde code-server [選項]`

  | 選項 | 意義 | 預設 |
  |---|---|---|
  | `-p`、`--port` | 主機 port | 8080 |
  | `-d`、`--daemon` | 背景執行，並設為 `--restart unless-stopped` | 前景 |
  | `-n`、`--name` | 容器名稱，用來區分多個實例 | `code-server` |
  | `-v`、`--volume` | 掛載，格式 `src[:dst[:ro\|rw]]`，可重複 | 當前目錄 |
  | `-w`、`--workdir` | 開啟的資料夾（容器內路徑） | 第一個目錄型掛載 |
  | `-a`、`--agent` | 啟動時安裝的 AI agent，可重複（見 UC-DEV-02） | 無 |

- **主要流程**：
  1. 解析並驗證選項。
  2. **互動詢問密碼**。
  3. 解析每個掛載：來源轉成絕對路徑；沒給 `dst` 時容器內路徑等於主機路徑；同一個 `dst` 只掛一次。
  4. 決定開啟的資料夾，並確認它位於某個目錄型掛載之下。
  5. 啟動容器。每個實例的設定存在 `<workspace>/.code-server/<name>/`（掛為容器的 home）。
- **例外流程**（都會中止，不啟動容器）：

  | 情況 | 訊息重點 |
  |---|---|
  | port 不是數字、名稱或 agent 名稱含不允許的字元 | 「無效的…」 |
  | 掛載來源不存在，或不是檔案或目錄 | 「掛載來源不存在」 |
  | 掛載格式錯誤（欄位過多、結尾多餘冒號、`dst` 為空或不是絕對路徑、選項不是 `ro` / `rw`） | 指出錯誤並附正確格式 |
  | 只掛了檔案而沒給 `-w` | 「沒有可開啟的目錄型掛載」 |
  | 開啟的資料夾不在任何掛載底下 | 「必須位於其中一個目錄型掛載底下」 |
  | 同名容器已存在 | 提示先移除或用 `-n` 換名稱 |

- **落差**：密碼只能互動輸入，沒有旗標或環境變數的替代方式，見 [GAP-20](09-gaps.md#gap-20)。
- 出處：`scripts/code-server/command.sh`、`scripts/utils/code-server.sh`；設計文件 `docs/superpowers/specs/2026-07-13-code-server-multi-mount-design.md`
- 測試：`test/test-code-server-mounts.sh`、`test/test-code-server-agent-args.sh`

---

### UC-DEV-02 在 code-server 裡預裝 AI agent

**狀態**：✅ 已確認

> 身為開發者，我想要 code-server 啟動時就裝好我要用的 AI agent CLI，以便打開就能用。

- **觸發**：`kde code-server -a <agent>`（目前支援 `claude`、`codex`）。
- **主要流程**：agent 清單以 `KDE_CODE_SERVER_AI_AGENTS` 傳入容器，由容器的 entrypoint 逐一安裝到使用者的 home。
- **規則**：
  - 已安裝的會跳過；設 `KDE_CODE_SERVER_AI_AGENTS_REINSTALL=true` 強制重裝。
  - **安裝失敗只警告，不阻擋 code-server 啟動**，一個 agent 失敗也不影響其他 agent。
  - 安裝腳本必須正確回報下載失敗（`curl … | bash` 的失敗不得被吞掉）。
- 出處：`code-server.sh:231-238`、`dockerfiles/code-server/entrypoint.d/10-ai-agents.sh`；設計文件 `docs/superpowers/specs/2026-08-13-code-server-ai-agent-install-design.md`
- 測試：`test/test-agent-entrypoint.sh`、`test/test-install-scripts.sh`

---

## OpenClaw

`kde openclaw <動作>` 以容器執行 OpenClaw agent 的 gateway。一個 workspace 對應一個 gateway 容器，
名稱由 workspace 目錄名推導（`openclaw-<目錄名>`）。

**狀態的位置**：容器本身可隨時丟棄，所有狀態都在 workspace 下、且不進版控：

| 路徑 | 內容 |
|---|---|
| `.openclaw-home/` | 容器的整個 home（設定、憑證、agent 資料） |
| `.openclaw-backups/` | 備份檔 |
| `.openclaw-image` | 本機的映像釘選 |

**所有動作的共同前置**：確認映像可用（本機有就不拉，沒有才嘗試 pull；都失敗時明確指出是映像問題與設定來源）。

### UC-DEV-03 啟動 OpenClaw gateway

**狀態**：✅ 已確認

> 身為開發者，我想要在 workspace 旁常駐一個 AI agent，並讓它一啟動就能操作 `kde`，以便把環境操作交給它。

- **命令**：`kde openclaw run [-p <port>]`（port 預設 18789，也可用環境變數 `OPENCLAW_PORT`）
- **前置條件**：已完成初始化（UC-DEV-04）；同名容器不存在。
- **主要流程**：
  1. 確認已初始化（在一次性容器中詢問 OpenClaw 的 `gateway.mode` 是否為 `local`）。
  2. 讀取認證模式，決定是否讓 gateway 綁定到可由主機連入的位址。
  3. 以背景、`--restart unless-stopped` 啟動容器。workspace 以相同絕對路徑掛入，並帶入 `KDE_PATH`。CLI 內的 skill 以唯讀掛進 agent 會掃描的位置。
  4. **健康檢查**：等待數秒後確認容器仍在運行且未曾重啟過。
  5. 印出網址、首次連線方式、查看日誌與停止的指令。
- **例外流程**：

  | 情況 | 行為 |
  |---|---|
  | 同名容器已存在 | 提示先 `kde openclaw stop` |
  | 尚未初始化 | 提示先 `kde openclaw onboard` |
  | 讀不到設定（映像取不到） | 只報映像的錯誤，**不**建議去 onboard |
  | 健康檢查失敗 | 印出容器最後 50 行日誌，失敗 |
  | 認證模式為 `none` | 仍會啟動，但明說 dashboard 從主機連不到，並指示如何啟用認證 |

- **設計理由**（程式碼註解，皆為實際踩過的問題）：
  - 帶入 `KDE_PATH` 是因為 agent 的工作目錄是它自己的家，在那裡執行 `kde` 會被引導去 `kde init` 而把模板灌進家目錄。
  - skill 用掛載而不是複製，是因為 skill 內容與 CLI 版本強耦合，複製的副本會過期而沒有人知道。
  - 健康檢查同時看重啟次數，是因為設定錯誤的容器會不斷重啟，抽查時可能剛好是運行中。
- 出處：`scripts/utils/openclaw.sh:284-403`、`516-598`
- 測試：`test/test-openclaw-lifecycle.sh`、`test/test-openclaw-container-args.sh`、`test/test-openclaw-kde-wrapper.sh`

---

### UC-DEV-04 初始化 OpenClaw

**狀態**：✅ 已確認

> 身為開發者，我想要透過精靈完成 OpenClaw 的首次設定，以便之後能啟動 gateway。

- **命令**：`kde openclaw onboard [-f]`
- **主要流程**：在一次性的互動容器中執行 OpenClaw 的初始化精靈，結束後驗證 `gateway.mode` 為 `local`。
- **替代流程**：已初始化時先警告「重跑會覆寫現有設定」並要求確認；`-f` 略過確認。
- **例外流程**：精靈結束後仍未初始化（例如被中斷）→ 失敗；同名的 onboard 容器已存在 → 提示先移除。
- **規則**：第一個 agent 的名稱固定為 `main`，精靈不會詢問（取其他名稱會導致之後聊天時認證失敗）。
- 不需要 gateway 已啟動，否則「未初始化不能啟動」與「要先啟動才能初始化」會形成死結。
- 出處：`openclaw.sh:462-514`

---

### UC-DEV-05 – 09 日常操作

**狀態**：✅ 已確認

| ID | 命令 | 行為 |
|---|---|---|
| UC-DEV-05 | `kde openclaw stop` | 停止並移除容器。容器不存在時不算錯誤（冪等）。停止或移除失敗時指示手動處理方式 |
| UC-DEV-06 | `kde openclaw restart [-p <port>]` | 先 stop 再 run。**未指定 port 時沿用現有容器的 port**，不會悄悄退回預設值；明確給的 `-p` 優先。stop 失敗就不繼續 |
| UC-DEV-07 | `kde openclaw tui` | 互動進入 OpenClaw 的 TUI。容器需在運行 |
| UC-DEV-08 | `kde openclaw exec [<cmd>]` | 不帶指令：進入容器的 bash。帶指令（位置參數或 `--command`）：不配置 TTY 執行，指令原封不動交給 `bash -c`。兩種寫法只能擇一；含空白的指令要用引號包成一個參數 |
| UC-DEV-09 | `kde openclaw log [-f] [--tail <n>]` | 顯示最後 100 行（或指定行數），預設不跟隨。**容器存在即可**，已經 crash 退出的也看得到。跟隨模式下用 Ctrl-C 離開視為正常結束 |

- `-f` 在 `log` 是「跟隨」，在其他動作是「略過確認」；長旗標 `--follow`、`--force` 沒有歧義。
- `tui`、`exec` 以容器內的一般使用者身分執行，不是 root。
- 出處：`openclaw.sh:600-679`、`779-843`　測試：`test/test-openclaw-args.sh`、`test/test-openclaw-lifecycle.sh`

---

### UC-DEV-10 取得連線憑證

**狀態**：✅ 已確認

> 身為腳本作者，我想要用管線取得 gateway 的 token，以便自動化連線設定。
>
> 身為開發者，我想要讓新的瀏覽器連上 dashboard，以便用圖形介面操作 agent。

| 命令 | 行為 |
|---|---|
| `kde openclaw token` | stdout **只**輸出 token 本身，所有提示與錯誤走 stderr。gateway 沒在運行也能取得。讀不到時區分「認證已停用所以沒有 token」與「尚未初始化」 |
| `kde openclaw dashboard [--json]` | 產生一條**一次性**的 owner 配對連結（約 10 分鐘失效，只綁定第一個打開它的瀏覽器）。網址中的 port 會改寫成容器實際對外的 port。`--json` 輸出原始 JSON。容器需在運行 |

- 出處：`openclaw.sh:681-777`

---

### UC-DEV-11 升級、降級與備份

**狀態**：✅ 已確認

> 身為開發者，我想要升級 OpenClaw 而不怕資料損壞，並且在新版有問題時能退回，以便安心跟上新版本。

- **升級** `kde openclaw upgrade [-p <port>]`：
  1. 拉取 `kde.env` 指定的映像。**拉取失敗就中止，不動容器**。
  2. 映像沒有變 → 印出「已是最新版本」，**不重啟**。
  3. 映像變了 → 解除映像釘選（若有）。容器未運行就到此為止，不順便啟動。
  4. 容器運行中 → 停止 → **備份**（記錄的是被換掉的舊版）→ 以新映像啟動，沿用原本的 port。
- **降級** `kde openclaw downgrade [<編號>] [--list] [-f]`：
  1. 列出可用備份（由舊到新，含版本、時間、大小）。`--list` 只列出就結束。
  2. 取得要還原的編號（參數或互動詢問）；編號無效時報錯而不猜測。
  3. 要求確認（`-f` 略過）。
  4. 停止容器 → **先備份現況** → 以選定的備份覆蓋 `.openclaw-home` → 把映像釘選為該備份對應的版本 → 啟動。
- **手動備份** `kde openclaw backup [-f]`：容器運行中會先說明將短暫中斷並要求確認，然後停止 → 備份 → 啟動回來。容器沒在運行時直接備份，不詢問也不啟動。
- **規則**：
  - **備份一律在容器停止後進行**，否則資料庫的快照可能不一致、還原不回來。
  - 備份保留最新 3 份（`OPENCLAW_BACKUP_KEEP` 可調），超過的由舊而新刪除。
  - 降級**不修改 `kde.env`**（版控檔），而是寫入本機的 `.openclaw-image`。釘選生效時每次都在 stderr 說明來源檔與解除方式。
  - `upgrade` 不受釘選影響，並在成功換版後解除釘選；`upgrade` 與 `downgrade` 因此對稱。
  - 「有沒有新版」以映像 ID 判斷，不解析 `docker pull` 的輸出文字。
- 出處：`openclaw.sh:845-1241`；`docs/core/dev-tools/openclaw.md`
- 測試：`test/test-openclaw-backup.sh`、`test/test-openclaw-image-tags.sh`

---

### UC-DEV-12 重設 OpenClaw

**狀態**：✅ 已確認

> 身為開發者，我想要清掉 OpenClaw 的所有狀態重新開始，以便排除設定損壞的問題。

- **命令**：`kde openclaw reset [-f]`
- **主要流程**：要求確認（明說會刪除設定與認證密鑰）→ 刪除 `.openclaw-home/` 與對應的 Docker volume。
- **例外流程**：容器運行中時**拒絕**並提示先 stop；目錄不存在時視為無需重設，正常結束。
- 備份（`.openclaw-backups/`）不會被刪除。
- 出處：`openclaw.sh:1243-1274`
