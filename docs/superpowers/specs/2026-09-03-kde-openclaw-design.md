# kde openclaw 子命令 — 設計文件

日期：2026-09-03
狀態：待核准

## 背景

需要一個以容器承載的 OpenClaw agent 環境，讓 agent 能在隔離的容器內操作 `kde` CLI 管理 K8s 開發環境，同時把所有狀態留在 workspace 裡（可版控、可重設、可隨 workspace 搬移）。

`dockerfiles/kde-openclaw/` 已存在但尚未接上 CLI，且目前的 Dockerfile 是壞的（見下）。本設計新增 `kde openclaw` 子命令，並改寫該映像。

### 現況驗證結果

以下事實為實測或官方文件查證所得，決定了整個設計，實作時不可推翻。

**`ubuntu:24.04` 基底實測**（`docker run --rm ubuntu:24.04`）：

| 項目 | 結果 |
|---|---|
| `curl` | **不存在** |
| `node` | **不存在** |
| `sudo` | **不存在** |
| `su` | `/usr/bin/su` |
| `setpriv` | `/usr/bin/setpriv`（util-linux 內建） |
| uid/gid 1000 | 已被佔用：`ubuntu:x:1000:1000:Ubuntu:/home/ubuntu:/bin/bash` |

→ 現有 `dockerfiles/kde-openclaw/Dockerfile`（`FROM ubuntu:24.04` + `RUN curl -fsSL https://openclaw.ai/install.sh | bash`）**無法建置**：沒有 curl。

**OpenClaw 官方文件查證**：

| 項目 | 結果 | 來源 |
|---|---|---|
| 官方映像 | `ghcr.io/openclaw/openclaw`（亦有 `openclaw/openclaw`） | docs.openclaw.ai/install/docker |
| 官方映像 base | `node:24-bookworm-slim` | 同上 |
| 官方映像執行身分 | 非 root 的 `node`，uid 1000；**不支援 PUID/PGID** | 同上 |
| 官方映像 PID 1 | `tini` | 同上 |
| 官方映像是否含 docker CLI | **否** | 同上 |
| 映像變體 | `latest`/`main`（完整）、`slim`、`-browser`（含 Chromium + Xvfb） | 同上 |
| 狀態目錄 | `~/.openclaw`（容器內 `/home/node/.openclaw`），workspace 在 `~/.openclaw/workspace` | 同上 |
| auth 密鑰目錄 | 官方文件敘述為 `~/.config/openclaw`（與 `~/.openclaw` 分離），**但實測證明錯誤**——見文末「實作期驗證結果」，密鑰實際落在 `~/.openclaw/openclaw.json` | 同上，已實測推翻 |
| gateway port | 預設 `18789`，**單一多工 port**：WebSocket RPC、HTTP API、plugin routes、Control UI（dashboard）全部共用 | docs.openclaw.ai/gateway、/web/dashboard |
| dashboard 是否獨立 port | **否**，掛在 gateway 的 `/`，是同一個行程 | docs.openclaw.ai/web/dashboard |
| 容器內 bind 模式 | 預設 `loopback`，但**容器環境下有效值為 `auto` → `0.0.0.0`**，port forward 直接可用 | docs.openclaw.ai/gateway |
| gateway 常駐指令 | `openclaw gateway run`，前景執行，吃 `--port` / `--bind` / `--auth` | docs.openclaw.ai/cli/gateway |
| `gateway run` 首次執行行為 | **不會自動 onboarding**。`~/.openclaw/openclaw.json` 沒有 `gateway.mode=local` 時**拒絕啟動** | docs.openclaw.ai/gateway/troubleshooting |
| 裸 `openclaw` 首次執行行為 | **會**依 config 狀態自動路由：config 缺失或無 authored settings → 啟動 guided onboarding；config 存在但驗證失敗 → 啟動 classic onboarding 並導向 `openclaw doctor`；config 有效 → 開啟 agent TUI | docs.openclaw.ai/cli/openclaw |
| 初始化指令 | `openclaw onboard --mode local` 會寫入 `gateway.mode=local` | docs.openclaw.ai/cli/onboard |
| 逃生門 | `openclaw gateway run --allow-unconfigured` 繞過檢查，但不寫入/修復設定 | 同上 |
| 查詢初始化狀態 | `openclaw config get gateway.mode` —— 直接讀 `gateway run` 唯一在意的值，輕量、可無 TTY 執行 | docs.openclaw.ai/cli |
| `openclaw status` | 只報 channel / session 診斷，**不報 onboarding 狀態**，不適合用於初始化檢查 | docs.openclaw.ai/cli/status |
| `openclaw doctor` | 健康檢查 + 自動修復，但偏重且部分檢查需 gateway 已在跑，不適合用於初始化檢查 | docs.openclaw.ai/gateway/doctor |
| 取得 auth token | `openclaw gateway auth-token` | docs.openclaw.ai/cli/gateway |
| 狀態/設定路徑覆寫 | `OPENCLAW_HOME`、`OPENCLAW_STATE_DIR`、`OPENCLAW_CONFIG_PATH` | docs.openclaw.ai/start/getting-started |

**kde CLI 在容器內執行所需的外部指令**（掃描 `kde.sh` 與 `scripts/`）：

| 指令 | 是否需要 | 理由 |
|---|---|---|
| `docker` | **需要** | 101 處呼叫，DooD 的核心 |
| `git` | **需要** | `kde proj fetch` / `pull` 直接在本機執行（`scripts/utils/project.sh:256,287-289`） |
| `envsubst` | **需要** | 渲染 config 模板（gettext-base） |
| `kubectl` | 不需要 | 都在 deploy-env 容器內執行（`scripts/utils/environment/k8s.sh:255-261`） |
| `helm` | 不需要 | 同上 |
| `tmux` | 不需要 | 僅 `kde alias` 使用 |

## 目標

- 新增 `kde openclaw <action>`，action 為 `run` / `onboard` / `stop` / `exec` / `reset`。
- 容器內可直接使用 `kde` CLI 操作宿主的 Docker（DooD）。
- workspace 以**相同絕對路徑**掛入容器，路徑在容器內外一致。
- OpenClaw 的狀態與密鑰全部落在 workspace 的 `.openclaw/`，可隨 workspace 搬移、可一次清除。
- 支援 `PUID`/`PGID` 對齊容器內外使用者，避免掛載檔案的權限問題。
- `run` 前先檢查初始化狀態，未初始化時明確告知並指向 `kde openclaw onboard`，不隱式改變 `run` 的行為。

## 非目標（YAGNI）

- 不做 `install` action（映像由 `kde.env` 的 `OPENCLAW_IMAGE` 決定，需要更新時使用者自行 `docker pull`）。
- 不支援 `-n` 自訂容器名稱（名稱由 workspace 自動推導）。
- 不支援多個 gateway 實例並存於同一 workspace。
- 不做 `--dashboard-port`（dashboard 與 gateway 共用同一 port）。
- 不把 port 寫進版控的 `kde.env`（見「環境變數」一節）。
- 不在容器內安裝 `sudo`。
- 不抽通用的「dev 容器生命週期」工具層給未來其他工具共用。
- 不處理 OpenClaw 的 model provider 憑證與 channel 設定（由 onboarding 精靈負責）。
- `run` 不自動代跑 onboarding：偵測到未初始化就停下來報錯，由使用者明確執行 `kde openclaw onboard`。理由是 `run` 的心智模型是「背景啟動服務」，讓它偶爾變成一個佔住終端機的互動精靈會違反預期。

## CLI 介面

```
kde openclaw <action> [options]

run    [-p port]              背景常駐啟動 gateway（openclaw gateway run）
onboard [-f|--force]          一次性互動容器跑初始化精靈（不需 gateway 已在運行）
stop                          停止並移除容器
exec   [-s] [--command <cmd>] 預設互動執行 openclaw；-s 進 bash；--command 無 TTY 執行後結束
reset  [-f|--force]           刪除 workspace 的 .openclaw（容器運行中則拒絕）
-h, --help                    顯示說明
```

### action 語意

| action | 行為 | 前置檢查失敗時 |
|---|---|---|
| `run` | 檢查初始化狀態 → `docker run -d` 啟動 gateway → 健康檢查 | 同名容器已存在 → 提示 `kde openclaw stop`；未初始化 → 提示 `kde openclaw onboard`。皆 `exit 1` |
| `onboard` | 一次性互動容器跑 `openclaw onboard --mode local`，結束後驗證是否成功寫入設定；已初始化時要 y/n 確認覆寫（`-f` 跳過） | 同名 onboard 容器已存在 → 報錯，`exit 1` |
| `stop` | `docker stop` 後 `docker rm` | 容器不存在 → 訊息提示，`exit 0`（冪等） |
| `exec` | 無旗標：`docker exec -it <container> openclaw`；`-s`：`docker exec -it <container> bash`；`--command <cmd>`：`docker exec`（不配置 TTY） | 容器不存在或非 running → 報錯並提示 `kde openclaw run`，`exit 1` |
| `reset` | 刪除 `${KDE_PATH}/.openclaw`；預設 `read -p` 要 y/n 確認，`-f` 跳過 | 容器 running → 報錯要求先 `stop`，`exit 1` |

`exec` 的預設行為刻意是「跑 `openclaw`」而不是「進 shell」：這個容器存在的理由就是跑 OpenClaw agent，讓最常見的操作不需要旗標。要純 shell 時用 `-s`，沿用 `scripts/utils/pipeline.sh:585-608` 的 `-s`/`--shell` 慣例；`-s` 與 `--command` 互斥（同時給定則報錯，理由與 pipeline 的 `--no-tty` + `--shell` 互斥相同：一個要 TTY、一個不要）。

`exec --command` 的無 TTY 行為與 `scripts/exec/command.sh:39-43` 的既有慣例一致。

原本規劃的獨立 `start` action 已移除：它的行為（互動執行 `openclaw`）現在就是 `exec` 的預設值，多一個 action 只是多一個要記的名字。

`onboard` 之所以必須是獨立 action、而不能只提示使用者去跑 `kde openclaw exec`：`exec` 依賴容器已在運行，但未初始化時 `gateway run` 會拒絕啟動、容器根本起不來，提示 `exec` 只會讓使用者撞回「請先 `kde openclaw run`」的循環。`onboard` 走的是一次性 `--rm` 容器，完全不依賴 gateway。

附帶效果：由於裸 `openclaw` 在 config 缺失時本來就會自動進 guided onboarding，`kde openclaw exec`（預設跑裸 `openclaw`）在容器已運行、但 config 被清空的情況下也會自動帶使用者進精靈。這是 OpenClaw 自身的行為，不是本設計實作的，但不衝突。

### 容器命名

`openclaw-<workspace 目錄名>`，由 `KDE_PATH`（`kde.sh:16-22` 已算好）的 basename 推導。非 `[a-zA-Z0-9_.-]` 的字元一律換成 `-`，避免目錄名含空白時 `docker run --name` 失敗。同一主機的不同 workspace 因此自然共存；port 衝突由 `-p` 解決。

一次性的 onboarding 容器使用 `openclaw-<workspace>-onboard` 名稱，避免與正式容器撞名；狀態檢查容器不具名（見「三種容器的差異」）。

### 環境變數

`kde.sh` 的預設 image 區塊（第 132-168 行）**只**新增 `OPENCLAW_IMAGE`，沿用「不存在就寫回 `kde.env`」的既有寫法：

```bash
if [[ -z ${OPENCLAW_IMAGE} ]]; then
    export OPENCLAW_IMAGE=docker.io/r82wei/kde-openclaw:latest
    echo "OPENCLAW_IMAGE=${OPENCLAW_IMAGE}" >> ${KDE_ENV_FILE}
fi
```

**`OPENCLAW_PORT` 刻意不寫進 `kde.env`。** `kde.env` 是版控檔案，會隨 workspace 一起 git pull 到每個人的機器上；而 port 是每台開發機各自的環境條件（可能已被其他服務佔用），不該同步。預設值 `18789` 直接寫在 `scripts/utils/openclaw.sh` 的變數初始化裡。

覆寫管道有兩條：

- `kde openclaw run -p <port>` —— 當次指定
- `OPENCLAW_PORT=19000 kde openclaw run` —— 環境變數；`scripts/utils/openclaw.sh` 只在該變數為空時才套用預設值

**不可行的管道**：workspace 層級的 `<workspace>/.env`。CLAUDE.md 的目錄結構把它記為「Local overrides (gitignored)」，但 codebase 中沒有任何地方 source 它——實際被載入的只有 `environments/<env>/.env`（`scripts/utils/environment/k8s.sh:122-127`）與專案層級的 `.env`。這是既有的文件與程式碼不一致，本設計不處理，只是不能依賴它。

`PUID` / `PGID` 同樣不設 CLI 旗標、不寫入 `kde.env`：環境變數有值就用，否則取主機的 `id -u` / `id -g`。

port 的優先序：`run -p <port>` > 環境變數 `OPENCLAW_PORT` > 內建預設 `18789`。`-p` 只影響**主機側**的發布 port；容器內一律 `--port 18789`，故 `-p` 只有 `run` 吃，`exec` 不需要。

## 架構

### 檔案配置

```
scripts/
├── openclaw/command.sh        # 薄路由：參數解析 + action 分派
└── utils/openclaw.sh          # 邏輯：show_help / parse / build args / 各 action 實作

dockerfiles/kde-openclaw/
├── Dockerfile                 # 改寫：base 換官方映像
├── entrypoint.sh              # 新增：PUID/PGID 重映射 + setpriv 降權
├── build.sh                   # 修改：OPENCLAW_VERSION 語意改為 base tag
└── release.sh                 # 同上
```

`scripts/utils/openclaw.sh` 匯出的函式：

| 函式 | 職責 |
|---|---|
| `show_openclaw_help()` | 說明文字 |
| `parse_openclaw_args()` | 解析 action 與旗標，回填 `OPENCLAW_*` 全域變數；回傳 0=成功 / 1=參數錯誤 / 2=已顯示說明應結束 |
| `get_openclaw_container_name()` | 由 `KDE_PATH` 推導並清洗容器名稱 |
| `build_openclaw_docker_args()` | 組出三種容器共用的 `docker run` 參數陣列（掛載、PUID/PGID、workdir、group-add） |
| `is_openclaw_onboarded()` | 一次性無 TTY 容器跑 `openclaw config get gateway.mode`，回傳 "true"/"false"（依 `is_*()` 的既有慣例） |
| `onboard_openclaw()` | 一次性互動容器跑 `openclaw onboard --mode local`，結束後以 `is_openclaw_onboarded()` 驗證 |
| `run_openclaw_gateway()` | 檢查容器與初始化狀態，背景啟動 gateway，最後健康檢查 |
| `exec_openclaw()` | 依旗標三選一：互動執行 `openclaw`、互動 `bash`、或無 TTY 執行指定指令 |
| `stop_openclaw()` | 停止並移除容器 |
| `reset_openclaw()` | 刪除 `.openclaw` |

`command.sh` 的骨架沿用 `scripts/code-server/command.sh` 的形狀，包含它那段「本檔被 `kde.sh` source，`set -e` 已開，必須用 `|| rc=$?` 承接非零回傳」的注意事項。

路由掛在 `kde.sh` 的**主 case 區塊**（第 207 行之後），與 `code-server` 同位置。不能放在早期免初始化區塊（第 76-109 行），因為那裡跑在 `source ${KDE_ENV_FILE}` 之前，讀不到 `OPENCLAW_IMAGE`。已知代價：workspace 內沒有任何 k8s 環境時會先印一行「環境 不存在」的雜訊——這是 `code-server` 現有的相同行為，選擇保持一致而非特例處理。

### 容器掛載（三種容器共用）

> **實作期修訂**：下方原本規劃了 `~/.config/openclaw` 的第二個掛載存放 auth 密鑰。實測（見文末「實作期驗證結果」）證明該路徑從未被 OpenClaw 寫入，密鑰實際落在 `~/.openclaw/openclaw.json`，因此該掛載已在實作中移除，最終只有四個掛載。以下內容按最終狀態更新。

```
-v ${KDE_PATH}:${KDE_PATH}                                        # workspace，同路徑
-v ${KDE_PATH}/.openclaw:/home/node/.openclaw                     # OpenClaw 狀態與 auth 密鑰
-v ${KDE_CLI_PATH}:/usr/local/lib/kde:ro                          # kde CLI 與主機同版
-v /var/run/docker.sock:/var/run/docker.sock:ro                   # DooD
--group-add <docker.sock 的 gid>
--workdir ${KDE_PATH}
-e PUID=<id -u> -e PGID=<id -g>
```

`${KDE_PATH}/.openclaw` 這個 host 目錄同時出現在容器的 workspace 路徑底下與 `/home/node/.openclaw`，兩次掛載是刻意的：讓 OpenClaw 讀 `$HOME/.openclaw` 時直接落在 workspace 裡，`reset` 只要刪這一個目錄就真的清乾淨（含 auth 密鑰）。

`docker.sock` 的 gid 取法沿用 `scripts/utils/code-server.sh:228-229`（`stat -c '%g'`，macOS 退回 `stat -f '%g'`）。

### 三種容器的差異

| | 狀態檢查容器 | onboard 容器 | gateway 容器 |
|---|---|---|---|
| 名稱 | 匿名（`--rm`，不具名） | `openclaw-<ws>-onboard` | `openclaw-<ws>` |
| 模式 | `--rm`（無 TTY） | `-it --rm` | `-d` |
| port | 不發布 | 不發布 | `-p ${OPENCLAW_PORT}:18789` |
| restart policy | 無 | 無 | `--restart unless-stopped` |
| 指令 | `openclaw config get gateway.mode` | `openclaw onboard --mode local` | `openclaw gateway run --port 18789` |

除此之外的所有參數由 `build_openclaw_docker_args()` 產出，三邊共用，避免掛載邏輯寫三份而漂移。

狀態檢查容器不具名是刻意的：它可能與 gateway 容器同時存在（例如未來要加 `status` 之類的指令），具名會撞名。onboard 容器則要具名，才能在使用者重複執行時明確報錯而非默默起兩個精靈。

### 初始化狀態的判斷

以 `is_openclaw_onboarded()` 判斷：在一次性無 TTY 容器內執行 `openclaw config get gateway.mode`，值為 `local` 才算已初始化。

這比「`.openclaw` 目錄是否為空」精確得多，理由有二：

1. bind mount 會讓 Docker 在掛載前自動建立不存在的 host 目錄（且屬 root），只要跑過一次任何 action，目錄就必然存在，「存在與否」完全失去鑑別力。
2. 目錄非空也不代表可用——onboarding 中途 Ctrl-C 可能留下半成品的 config，`gateway run` 依然會拒絕啟動。直接問 OpenClaw 自己「`gateway.mode` 是什麼」才是與 `gateway run` 的實際判斷條件對齊的唯一方式。

代價是每次 `run` 多起一個短命容器（約數百毫秒），可接受。

### run 的執行順序

1. 檢查同名 gateway 容器 → 已存在則報錯，提示 `kde openclaw stop`，`exit 1`。
2. `is_openclaw_onboarded()` → 為 `false` 則報錯並 `exit 1`：

```
❌ OpenClaw 尚未初始化（gateway.mode 不是 local）
   請先執行：kde openclaw onboard
```

3. `docker run -d` 啟動 gateway。
4. 健康檢查：等待數秒後以 `docker inspect` 確認容器仍在 running（可搭配 `openclaw gateway health` 的 `/healthz`）。失敗則 `docker logs --tail 50 <name>` 印出錯誤並 `exit 1`，不回報成功。
5. 成功則印出提示（皆為字串，不執行）：

```
✓ openclaw gateway 已在背景啟動 (<name>)
存取網址: http://localhost:${OPENCLAW_PORT}
查看日誌: docker logs -f <name>
取得 token: kde openclaw exec --command "openclaw gateway auth-token"
停止服務: kde openclaw stop
```

`--allow-unconfigured` 不使用：那條路徑不會寫入設定，只會產生一個每次重啟都要重來的 gateway。

### onboard 的執行順序

1. 檢查同名 onboard 容器 → 已存在則報錯，`exit 1`。
2. 若 `is_openclaw_onboarded()` 已為 `true`，提示「已初始化，重跑精靈會覆寫現有設定」並要求 y/n 確認（`-f` 可跳過，與 `reset` 同慣例）。
3. 啟動一次性互動容器跑 `openclaw onboard --mode local`。
4. 精靈結束後再次 `is_openclaw_onboarded()` 驗證；仍為 `false`（使用者中途放棄）→ 報錯 `exit 1`，成功 → 提示可執行 `kde openclaw run`。

## 映像設計

```dockerfile
ARG OPENCLAW_VERSION=latest
FROM ghcr.io/openclaw/openclaw:${OPENCLAW_VERSION}

USER root
# kde-cli 執行時需要的外部指令
RUN apt-get update && apt-get install -y --no-install-recommends \
      git gettext-base ca-certificates docker.io \
 && rm -rf /var/lib/apt/lists/*
# kde-cli 本體。唯一真實來源是 local-install.sh，Dockerfile 不需跟著它改。
COPY . /tmp/kde-src/
RUN cd /tmp/kde-src && bash local-install.sh && cd / && rm -rf /tmp/kde-src
COPY dockerfiles/kde-openclaw/entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
```

- `OPENCLAW_VERSION` 的語意從「install.sh 的版本參數」改為「base image tag」；升級 OpenClaw 等於換 tag。`build.sh` / `release.sh` 的對外介面不變。
- 保留官方的 `tini` 當 PID 1，entrypoint 接在它後面，`docker stop` 的 SIGTERM 才能正確傳達。
- build context 仍是 repo 根目錄（`COPY . /tmp/kde-src/`），故 `COPY` entrypoint 時要寫完整相對路徑。
- 不裝 `sudo`：需要的工具都在 build 期裝好。
- 不裝 Node：官方 base 本身就是 `node:24-bookworm-slim`。

### entrypoint.sh

以 root 進入，依序：

1. `PUID=${PUID:-1000}`、`PGID=${PGID:-1000}`。
2. 若 `PGID != 1000` → `groupmod -g "${PGID}" node`；若 `PUID != 1000` → `usermod -u "${PUID}" node`。等於 1000 時完全不動（官方映像的 `node` 就是 1000，多數情況走這條）。
3. `chown` `/home/node`、`/home/node/.openclaw` 到新的 uid:gid（**不含** `/home/node/.config/openclaw`——見文末「實作期驗證結果」，該路徑從未被使用，掛載與 chown 皆已移除）。**不遞迴 chown 掛進來的 workspace**——那可能很大，而且會改動主機端檔案的擁有者。
4. `export HOME=<容器 home>` 後 `exec setpriv --reuid "${PUID}" --regid "${PGID}" --init-groups --inh-caps=-all "$@"`。**`export HOME` 是必要的一步**：`setpriv` 只切換 uid/gid，不會連帶更新 `$HOME`；不手動改寫會讓降權後的行程仍以 `HOME=/root` 執行（`setpriv` 不改變它，容器起始環境的 `HOME` 繼承自映像設定的 root），導致 OpenClaw 讀寫到 `/root/.openclaw/...` 而非掛載的 workspace 路徑——見文末「實作期驗證結果」的實測記錄。

用 `setpriv` 而非 `gosu`/`sudo`：util-linux 內建、零額外套件，且 `exec` 取代自身，降權後的行程直接承接訊號。

檔頭要註明 `set -e` 的選擇與理由（依 CLAUDE.md 的 Bash 慣例）。

## 錯誤處理

| 情境 | 行為 |
|---|---|
| 同名容器已存在（`run`） | 報錯 + 提示 `kde openclaw stop`，`exit 1` |
| 未初始化（`run`） | 報錯 + 提示 `kde openclaw onboard`，`exit 1` |
| 同名 onboard 容器已存在（`onboard`） | 報錯，`exit 1` |
| 已初始化（`onboard`） | y/n 確認是否覆寫；`-f` 跳過確認 |
| onboarding 結束後 `gateway.mode` 仍非 `local`（`onboard`） | 報錯，`exit 1` |
| 容器不存在或非 running（`exec`） | 報錯 + 提示 `kde openclaw run`，`exit 1` |
| `-s` 與 `--command` 同時給定 | 報錯，`exit 1` |
| 容器 running（`reset`） | 報錯 + 要求先 `stop`，`exit 1` |
| 容器不存在（`stop`） | 訊息提示，`exit 0`（冪等） |
| gateway 啟動後健康檢查失敗 | `docker logs --tail 50` + `exit 1`，不回報成功 |
| `-p` 非數字 | 報錯，`exit 1`（沿用 `parse_code_server_args` 的驗證） |
| 未知參數 / 未知 action | 報錯 + 顯示說明，`exit 1` |

## 測試

四支測試，都照 `test/test-code-server-mounts.sh` 的既有手法：source utils、以 shell 函式 stub 掉 `docker`、對印出的參數字串做斷言，不會真的起容器。

| 檔案 | 覆蓋 |
|---|---|
| `test/test-openclaw-args.sh` | action 分派、`-p` 數字驗證、`--command` 解析、`-s`、`-s` 與 `--command` 互斥報錯、`-f`、未知參數報錯、`-h` 回傳碼 2 |
| `test/test-openclaw-container-args.sh` | 四組 `-v` 掛載、`-p`、`PUID`/`PGID`、`--group-add`、`--workdir`；三種容器的差異（狀態檢查：匿名無 TTY；onboard：`-it --rm`、無 `-p`；gateway：`-d --restart`） |
| `test/test-openclaw-lifecycle.sh` | 同名容器已存在 → `run` 報錯；`gateway.mode` 非 `local` → `run` 報錯並提示 `onboard`（**不**自動代跑）；`gateway.mode` 為 `local` → `run` 正常啟動；`onboard` 在已初始化時要確認、`-f` 跳過；onboarding 後 `gateway.mode` 仍非 `local` → 報錯；容器未運行 → `exec` 報錯；容器運行中 → `reset` 拒絕；`exec` 三種分支各自組出正確的 `docker exec` 參數（有無 `-it`、指令為 `openclaw` / `bash` / 自訂） |
| `test/test-openclaw-entrypoint.sh` | 照 `test/test-agent-entrypoint.sh` 的手法，用假 PATH 攔截 `usermod`/`groupmod`/`chown`/`setpriv` 並記錄呼叫：PUID=1000 時不重映射；PUID≠1000 時才呼叫 `usermod -u`；**不對 workspace 遞迴 chown** |

## 文件同步

依 CLAUDE.md 的規則：

- `docs/core/dev-tools/openclaw.md` — **新增**，逐旗標的正式參考
- `docs/core/quick-reference.md` — 加入 `kde openclaw`
- `.claude/skills/kde-usage/references/quick-reference.md` — 同上，與前者互相 diff 確保同步
- `.claude/skills/kde-usage/SKILL.md` — 加入 openclaw 的操作指引
- `kde.sh` 的 `show_help()` — 一行摘要
- `CLAUDE.md` — 測試表格新增「openclaw」列；Code Layout 補 `scripts/utils/openclaw.sh`
- `docs/core/cicd-pipeline.md` — **不動**，本功能與 pipeline 無關

## 實作期驗證結果

本設計文件原本的「實作期待驗證的未知數」一節列了三個未知數，皆已在實作階段（Task 5）實測解決，結論如下。完整實測指令與輸出見 `.superpowers/sdd/2026-09-03-kde-openclaw/task-5-report.md`。

1. **auth 密鑰路徑：官方文件敘述錯誤，不是 `~/.config/openclaw`。**

   以假金鑰經兩條完全獨立的路徑實測——`openclaw config set gateway.auth.token <fake>` 與 `openclaw onboard --non-interactive ... --custom-api-key <fake>`——兩者都一致把設定與金鑰寫進 `~/.openclaw/openclaw.json`；同時掛出來的 `~/.config/openclaw` 目錄從頭到尾是空的。原本設計規劃的 `~/.config/openclaw` 掛載已從最終實作移除（`build_openclaw_docker_args()` 只剩四個掛載，entrypoint.sh 也不再 `mkdir`/`chown` 該路徑）。

   （曾出現的誤判：`ghcr.io/openclaw/openclaw` 映像內 `FLEET_CONTAINER_AUTH_SECRET_DIR = "/home/node/.config/openclaw"` 這個常數一度被誤讀為頂層 `openclaw` 行程的認證路徑；重新確認後，那其實是 OpenClaw 自己啟動**巢狀 Fleet 子容器**時要掛的路徑名稱，與頂層行程讀寫設定的位置無關。）

2. **官方映像的 apt 可用性：`apt-get install docker.io` 可行，無需 fallback。**

   base `node:24-bookworm-slim`（Debian bookworm）的官方套件庫本身就有 `docker.io`（實測版本 `20.10.24+dfsg1-1+deb12u1+b6`），`bash build.sh` 全程無錯誤建置成功。Dockerfile 維持原文，未套用任何 fallback（例如改走 Docker 官方 apt repo 或 `docker-ce-cli`）。

3. **`tini` 的實際路徑：`/usr/bin/tini`，且官方 `ENTRYPOINT` 本身用 `["tini","-s","--"]`（含 `-s`）。**

   `docker inspect` 確認官方映像 Entrypoint 為 `["tini","-s","--"]`；容器內 `command -v tini` 進一步確認絕對路徑為 `/usr/bin/tini`。實作對齊沿用 `-s`（subreaper），未擅自拿掉：`ENTRYPOINT ["/usr/bin/tini", "-s", "--", "/usr/local/bin/entrypoint.sh"]`。

### 額外的實作期發現（設計階段未預期）

- **`setpriv` 不會更新 `$HOME`。** 走真正的 ENTRYPOINT 鏈路（tini → entrypoint.sh → setpriv → command）實測時，即使 `setpriv --reuid/--regid` 已把行程正確降到 `node`（uid/gid 1000），`$HOME` 仍停在 `/root`（容器起始環境繼承自映像設定的 root）。結果是 OpenClaw 想寫的路徑變成 `/root/.openclaw/...` 而非掛載的 `/home/node/.openclaw`，出現 `EACCES: permission denied` 或設定憑空消失。修正方式：entrypoint.sh 在 `exec setpriv ...` **之前**明確 `export HOME="${OPENCLAW_HOME_DIR}"`，讓降權後的行程看到正確的 `$HOME`。

- **repo 根目錄的 `.dockerignore` 整個排除 `dockerfiles`。** 新增要進映像的檔案（例如 `entrypoint.sh`）必須額外加一行 `!dockerfiles/kde-openclaw/entrypoint.sh` 放行，書寫順序沿用既有的 `!dockerfiles/code-server/...` 慣例（排除規則之後才放行，Docker 的 `.dockerignore` 語意與 `.gitignore` 相同：後出現的規則勝出）。
