# 03 專案與專案集合

回到 [總覽](README.md)。

專案命令的形式是 `kde project <動作> <project> [選項]`，`project` 可寫成 `proj`、`namespace`、`ns`。
所有專案命令都作用於**當前環境**。

共通行為：需要專案名稱而沒給時，多數動作會列出選單讓使用者選（`check_project_name`）。
這對沒有 TTY 的呼叫端是阻塞點，見 [NFR-02](08-non-functional.md#nfr-02-非互動可操作性)。

Pipeline 相關的動作（`pipeline`、`deploy`、`undeploy`、`redeploy`）在 [04](04-pipeline.md)。

---

### UC-PRJ-01 建立專案

**狀態**：⚠️ 有落差

> 身為開發者，我想要在環境裡建立一個專案骨架，以便開始寫建置與部署腳本。

- **命令**：`kde project create [project]`
- **主要流程**：
  1. 未給名稱時詢問。專案已存在則報錯結束。
  2. 建立專案目錄。
  3. 詢問是否從 Git 遠端抓程式碼。是：詢問 repo 網址與分支（預設 `main`）並 clone 到專案目錄下。否：記錄 `GIT_REPO_URL=./<project>` 並建立同名的空目錄。
  4. 詢問開發映像（`DEVELOP_IMAGE`）與部署映像（`DEPLOY_IMAGE`，預設為 `KDE_DEPLOY_ENV_IMAGE`）。
  5. 寫入 `project.env`：repo、映像、Helm 的四個目錄變數（指到專案內的 `.helm/`）、預設的 `build,deploy` 兩階段 pipeline。
  6. 建立空的、可執行的 `build.sh` 與 `deploy.sh`。
- **約定**：`GIT_REPO_URL` 以 `./` 開頭代表本機專案，之後的 `pull` 會略過它。
- **落差**：不會建立 K8s namespace，但程式碼註解與 `TODO.md` 都說會，見 [GAP-05](09-gaps.md#gap-05)。四個提問都沒有非互動的替代方式。
- 出處：`scripts/utils/project.sh:113-160`

---

### UC-PRJ-02 從 Git 取得專案

**狀態**：✅ 已確認

> 身為團隊成員，我想要從 Git 取得同事定義好的專案（含 pipeline 設定），以便直接部署。

- **命令**：`kde project fetch <project> <git url> <branch>`
- **主要流程**：
  1. 把「專案設定 repo」clone 到 `namespaces/<project>/`（含 submodule）。
  2. 依其中 `project.env` 的 `GIT_REPO_URL` 與 `GIT_REPO_BRANCH`，取得應用程式的原始碼 repo（即 UC-PRJ-03）。
- **例外流程**：缺網址或分支時顯示用法，結束碼 1。目標目錄已存在時詢問是否刪除，回答不是 `y` 就中止。
- 這裡有兩層 repo：專案設定（`project.env` 與 pipeline 腳本）是一個 repo，應用程式原始碼是另一個。
- 出處：`scripts/project/command.sh:91-99`、`project.sh:162-170`

---

### UC-PRJ-03 更新專案原始碼

**狀態**：✅ 已確認

> 身為開發者，我想要把專案的原始碼更新到設定的分支，以便部署最新版本。

- **命令**：`kde project pull [project] [-f|--force]`
- **主要流程**：讀取 `project.env` → repo 目錄不存在就 clone，存在就 `fetch`、`checkout`、`pull` 設定的分支。
- **替代流程**：
  - `--force`：先刪除 repo 目錄再重新 clone（會丟失本機修改）。
  - 未給專案名稱：列出選單。
  - 本機專案（`GIT_REPO_URL` 以 `./` 開頭）：印出無法 pull 的訊息，正常結束。
- **例外流程**：

  | 情況 | 行為 |
  |---|---|
  | 專案或 `project.env` 不存在 | 報錯，結束碼 1 |
  | repo 有未提交的修改 | 「請先提交或 stash」，列出修改，失敗 |
  | 目錄不是 git repo | 報錯，失敗 |

- 拒絕在有未提交修改時 pull，是保護使用者工作成果的明確設計。
- 出處：`project.sh:172-208`、`256-294`

---

### UC-PRJ-04 – 07 簡單動作

| ID | 命令 | 行為 | 狀態 | 出處 |
|---|---|---|---|---|
| UC-PRJ-04 | `kde project list`、`ls` | 列出當前環境 `namespaces/` 下的目錄 | ✅ | `command.sh:77-80` |
| UC-PRJ-05 | `kde project link [project]` | 詢問一個主機目錄，在專案目錄下建立指向它的 symlink。用於把別處的原始碼納入專案 | ✅ | `project.sh:297-309` |
| UC-PRJ-06 | `kde project pod [project]` | 列出專案 namespace 的 pod 名稱，一行一個 | ✅ | `command.sh:219-227` |
| UC-PRJ-07 | `kde project ingress [project]` | 詢問 domain → 選 service 與 port → 建立 class 為 `nginx` 的 Ingress，名稱為 `<domain 的 . 換成 ->-ingress` | ✅ | `command.sh:311-324` |

---

### UC-PRJ-08 刪除專案

**狀態**：❓ 待確認

> 身為開發者，我想要移除一個專案，以便清理環境。

- **命令**：`kde project remove [project]`、`rm`
- **主要流程**：環境運行中就先解除部署（[UC-PIPE-06](04-pipeline.md#uc-pipe-06-解除部署)）→ 刪除專案目錄（含原始碼）。
- **注意**：沒有確認提示，見 [Q2](09-gaps.md#待確認事項)。
- 出處：`project.sh:359-368`

---

### UC-PRJ-09 進入專案的工作容器

**狀態**：✅ 已確認

> 身為開發者，我想要進入一個裝好專案所需工具的容器，以便不在主機安裝任何語言或工具就能開發。
>
> 身為 AI agent，我想要在該容器裡執行單一指令並取得輸出，以便不依賴 TTY。

- **命令**：`kde project exec [project] [develop|deploy] [port] [-v host:container]… [--command <script>]`
  - `develop`（預設，可寫 `dev`）用 `DEVELOP_IMAGE`，並先 `cd` 進原始碼目錄。
  - `deploy`（可寫 `dep`）用 `DEPLOY_IMAGE`，停在專案目錄。
  - 參數順序不拘，以內容辨識：純數字是 port，`develop` / `deploy` 是類型。
- **容器的共同條件**（所有專案容器與 pipeline stage 都一樣）：

  | 條件 | 目的 |
  |---|---|
  | 以主機使用者的 uid:gid 執行，並掛入 `/etc/passwd`、`/etc/group` | 容器產生的檔案在主機上屬於使用者本人 |
  | 專案目錄以**相同的絕對路徑**掛入並設為工作目錄 | 容器內外路徑一致（DooD 的必要條件，見 [CON-02](08-non-functional.md#con-02-容器內外路徑一致)） |
  | 接上環境的 Docker 網路，掛入 kubeconfig | 容器內可直接 `kubectl` 操作該環境 |
  | 掛入 `docker.sock`（唯讀）並加入其群組 | 容器內可以 build 映像 |
  | 載入 `project.env`（經 `envsubst` 展開）與專案的 `.env` | 專案設定即環境變數 |
  | 掛入所有 `KDE_MOUNT_*` 定義的路徑 | 讓專案宣告額外需要的檔案（如 `~/.ssh`） |

- **替代流程**：
  - `port`：把該 port 對應到主機同號 port。
  - `-v`：可重複，轉成 `KDE_MOUNT_CLI_<n>` 併入上述掛載機制。
  - `--command`：不配置 TTY，執行指令後結束。此模式另外掛入 `~/.docker` 與 `~/.netrc`（見 [GAP-08](09-gaps.md#gap-08)）。
- **例外流程**：`-v` 或 `--command` 缺少值時 stderr 報錯，結束碼 1；專案不存在時列出可用專案後結束碼 1。
- 出處：`command.sh:261-310`、`project.sh:370-402`、`k8s.sh:349-533`
- 測試：`test/test-proj-exec-volumes.sh`、`test/test-exec-integration.sh`

---

### UC-PRJ-10 查看 pod 日誌

**狀態**：✅ 已確認

> 身為開發者，我想要追蹤專案 pod 的日誌，以便確認 hot reload 是否生效或診斷錯誤。

- **命令**：`kde project tail [project] [pod] [行數] [--no-tty]`
- **主要流程**：顯示最後 100 行（或指定行數）並**持續跟隨**。
- **替代流程**：
  - 未給 pod：只有一個 pod 時自動選它，多個時列出選單。
  - `--no-tty`：只取快照、**不跟隨**，供非互動環境使用。
- **例外流程**：`--no-tty` 而沒給 pod 時 stderr 報錯，結束碼 1；namespace 沒有 pod 時報錯，結束碼 1。
- 出處：`command.sh:185-218`、`k8s.sh:864-889`

---

### UC-PRJ-11 進入 pod

**狀態**：✅ 已確認

> 身為開發者，我想要進入運行中的 pod，以便在實際執行環境裡檢查狀態。

- **命令**：`kde project pod-exec [project] [pod] [--command <script>]`
- **主要流程**：在 pod 內開啟 `bash`，沒有 `bash` 就退回 `sh`。
- **替代流程**：未給 pod 時互動選擇。`--command` 以非互動方式執行指令並串流輸出。
- **例外流程**：`--command` 沒給 pod 時報錯（非互動模式不能跳選單）；`--command` 缺值時報錯。
- `-h` / `--help` 可出現在任何位置。
- 出處：`command.sh:228-256`、`project.sh:15-47`　測試：`test/test-pod-exec-args.sh`

---

## 專案集合

`kde projects <動作>`（可寫 `projs`）操作的是整個 `namespaces/` 目錄。
用途是讓團隊把「一個環境的所有專案設定」放在同一個 repo 裡一次取得。

| ID | 命令 | 行為 | 狀態 | 出處 |
|---|---|---|---|---|
| UC-PRJ-12 | `kde projects fetch <git url> <branch>` | 把 repo clone 成當前環境的 `namespaces/`，再逐一詢問是否取得每個專案的原始碼。`namespaces/` 已有內容時先詢問是否刪除。當前環境不存在時詢問名稱並建立 | ✅ | `scripts/projects/command.sh:31-44`、`projects.sh` |
| UC-PRJ-13 | `kde projects pull` | 對每個專案詢問「是否要下載 git repo」，回答 `y` 的才執行 UC-PRJ-03 | ✅ | `projects.sh:34-43` |
| UC-PRJ-14 | `kde projects link` | 詢問一個主機目錄並建立 symlink | ⚠️ [GAP-25](09-gaps.md#gap-25) | `projects.sh:64-73` |
| UC-PRJ-15 | `kde projects exec` | 進入部署容器，掛載並停在整個 `namespaces/`，用於跨專案操作 | 📄 help 沒列 | `command.sh:57-61`、`k8s.sh:331-347` |

UC-PRJ-16（保留編號）：`TODO.md` 列有「從現有的 project 開新分支環境（git worktree）」，尚未實作。
