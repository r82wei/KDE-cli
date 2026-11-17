# 09 落差清單與待確認事項

回到 [總覽](README.md)。

這裡列出分析過程中發現的所有不一致。每一條都標明**它是怎麼被確認的**：

| 驗證方式 | 意義 |
|---|---|
| **已執行** | 實際執行過程式碼並觀察到結果（方法寫在該條目中） |
| **讀碼** | 從程式碼推得，沒有執行。真實環境下的表現可能受這裡沒看到的因素影響 |
| **比對** | 直接比對兩份文字（程式碼與文件、help 與實作），不需要執行 |

落差分三類：**A 行為與宣稱不符**（可能是 bug）、**B 文件或 help 過時**、**C 設計不一致**（沒有錯，但值得決定）。

## 摘要

| ID | 類別 | 驗證 | 摘要 |
|---|---|---|---|
| [GAP-01](#gap-01) | A | 已執行 | Pipeline stage 失敗時，`ALLOW_FAILURE` 與 `FAIL_FAST=false` 不生效；`redeploy` 會把失敗的解除部署當成成功 |
| [GAP-02](#gap-02) | A | 已執行 | `kde init` 在全新目錄失敗（結束碼 1） |
| [GAP-03](#gap-03) | A | 已執行 | 重複 `kde init` 產生巢狀的 `docs/kde-cli/docs` |
| [GAP-04](#gap-04) | A | 讀碼 | 「主機只需要 Docker」不成立：還需要 `envsubst`、`openssl`、`git` 等 |
| [GAP-05](#gap-05) | A | 讀碼 | `kde project create` 不建立 K8s namespace |
| [GAP-06](#gap-06) | A | 讀碼 | ngrok token 寫到當前目錄，讀取卻在 workspace 根目錄 |
| [GAP-07](#gap-07) | A | 讀碼 | Telepresence 覆寫了專案容器的啟動函式，條件與其他地方不同 |
| [GAP-08](#gap-08) | C | 讀碼 | 互動與非互動的專案容器掛載內容不同 |
| [GAP-09](#gap-09) | A | 讀碼 | `kde stop <env>`、`load-image` 的環境類型取自當前環境 |
| [GAP-10](#gap-10) | A | 讀碼 | `kde use` 以 `kind-config.yaml` 判斷是否需要建立，對 k3d / 外部 K8s 永遠成立 |
| [GAP-11](#gap-11) | C | 讀碼 | `redeploy` 只接受 `--no-tty`，其他 pipeline 選項被忽略 |
| [GAP-12](#gap-12) | B | 比對 | 頂層 help 對 `kde reset` 的描述與實際作用範圍不符 |
| [GAP-13](#gap-13) | B | 比對 | `stop`、`restart`、`remove` 的用法文字寫成 `kde k8s …` |
| [GAP-14](#gap-14) | B | 比對 | 文件說外部 K8s 不支援 `reset`，程式碼沒有擋 |
| [GAP-15](#gap-15) | B | 比對 | `kde ngrok` 的 help 列出 `-d`，沒有實作 |
| [GAP-16](#gap-16) | B | 比對 | 數個存在的功能沒出現在 help 或 `docs/core/` |
| [GAP-17](#gap-17) | C | 讀碼 | Headlamp 與 ngrok 的映像寫死為 `latest` |
| [GAP-18](#gap-18) | B | 比對 | 兩份 quick-reference 已分歧（35 行） |
| [GAP-19](#gap-19) | C | 讀碼 | 旗標慣例不一致 |
| [GAP-20](#gap-20) | C | 讀碼 | 仍只能互動操作的命令 |
| [GAP-21](#gap-21) | C | 比對 | 未被呼叫的函式 |
| [GAP-22](#gap-22) | B | 比對 | `TODO.md` 的狀態過時 |
| [GAP-23](#gap-23) | B | 比對 | `CLAUDE.md` 的 stage 選項「完整清單」漏了兩項 |
| [GAP-24](#gap-24) | C | 讀碼 | Pipeline 不驗證 stage 名稱 |
| [GAP-25](#gap-25) | A | 讀碼 | `kde projects link` 的行為與說明不符 |
| [GAP-26](#gap-26) | A | 讀碼 | `kde exec` 對外部 K8s 環境無法運作 |
| [GAP-27](#gap-27) | C | 讀碼 | 說明與結束碼不一致 |

---

## A 類：行為與宣稱不符

<a id="gap-01"></a>
### GAP-01 Pipeline 的失敗處理不生效

- **宣稱**：stage 失敗時依 `ALLOW_FAILURE`、`KDE_PIPELINE_FAIL_FAST` 決定是否繼續，並印出失敗訊息
  （`pipeline.sh:450-473`、`docs/core/cicd-pipeline.md`、pipeline 的 help）。
- **實際**：
  1. **一般情況**（`kde proj pipeline`）：stage 的容器回傳非零時，CLI 立刻以該結束碼中止。
     `ALLOW_FAILURE=true` 的 stage 失敗後，後面的 stage **不會執行**；`KDE_PIPELINE_FAIL_FAST=false` 沒有效果；
     「❌ 階段執行失敗」「❌ Pipeline 執行失敗」這些訊息都不會出現。
  2. **`kde proj redeploy` 的解除部署階段**：失敗被吞掉，印出「✅ 階段 undeploy 執行完成」與「已解除部署」，然後繼續跑 pipeline。
- **原因**：`kde.sh` 開了 `set -e`。容器是在函式中間以裸呼叫執行的（`k8s.sh:449-464`、`511-528`），
  失敗時 shell 直接結束，走不到後面檢查 `$?` 的程式碼。而 `redeploy` 以 `undeploy_project … || exit 1` 呼叫，
  `||` 會讓整個呼叫鏈的 `set -e` 失效；此時容器函式的最後一個指令是清理暫存檔的 `if`，所以函式回傳 0。
- **驗證方式**：載入真正的 `k8s.sh` 與 `pipeline.sh`，在 `set -eo pipefail` 下以 shell 函式取代 `docker`
  （讓 stage `a` 回傳 7），設定 `KDE_PIPELINE_STAGES="a,b"` 與 `KDE_PIPELINE_STAGE_a_ALLOW_FAILURE=true`：
  - 裸呼叫 `execute_custom_pipeline`：輸出停在 stage `a`，stage `b` 沒有執行。
  - 以 `… || …` 呼叫：stage `a` 顯示「執行完成」，stage `b` 接著執行，pipeline 回報成功。
- **未驗證**：沒有用真實的 Docker 容器跑過。
- **為什麼測試沒抓到**：`test/test-allow-failure.sh` 只測 `is_stage_allow_failure` 的回傳值，沒有測整條流程。
- **影響**：`ALLOW_FAILURE`、`KDE_PIPELINE_FAIL_FAST` 是文件記載的功能。對 CI 與 AI agent 來說，第 2 點更嚴重：失敗被回報為成功。

<a id="gap-02"></a>
### GAP-02 `kde init` 在全新目錄失敗

- **宣稱**：`mkdir my-workspace && cd my-workspace && kde init`（`docs/core/workspace.md`「從頭建立」）。
- **實際**：`cp: cannot create directory '…/docs/kde-cli': No such file or directory`，結束碼 1。
  `kde.env` 與 `.gitignore` 已經建立，所以 workspace 其實可以用，但命令回報失敗，文件也沒有複製。
- **原因**：`kde.sh:143` 複製到 `<workspace>/docs/kde-cli`，而 `<workspace>/docs/` 不存在；`templates/init/` 只有 `.gitignore`。
- **驗證方式**：在空的暫存目錄執行 `bash kde.sh -C <目錄> init`。

<a id="gap-03"></a>
### GAP-03 重複初始化產生巢狀目錄

- **實際**：`docs/kde-cli` 已存在時，`cp -r docs docs/kde-cli` 會複製成 `docs/kde-cli/docs/`，而不是覆蓋。
  `kde docs` 選擇覆蓋時用的是同一個指令（`kde.sh:293`），推定有相同結果（這一支沒有執行）。
- **驗證方式**：在已有 `docs/` 的暫存目錄連續執行兩次 `kde init`，確認出現 `docs/kde-cli/docs`。

<a id="gap-04"></a>
### GAP-04 主機不只需要 Docker

`README`、`docs/principle.md`、skill 都說「主機只需要 Docker」。CLI 在主機上直接呼叫的程式：

| 程式 | 用途 | 位置 |
|---|---|---|
| `envsubst`（gettext） | 產生 kind / k3d 設定檔、展開 `project.env` | `kind.sh`、`k3d.sh`、`k8s.sh:360` 等 |
| `openssl` 與 `/etc/ssl/openssl.cnf` | 建立環境時產生 CA | `k8s.sh:203-216` |
| `git` | 專案的 clone 與 pull | `project.sh:253`、`276-286` |
| `tar` | OpenClaw 備份 | `openclaw.sh:959` |
| `tmux` | `kde alias` 產生的捷徑 | `scripts/alias/command.sh` |
| `kde`（需在 `PATH`） | `restart`、`reset`、`use` 會再呼叫自己 | 各 `command.sh` |
| GNU 版 `readlink -f`、`grep -oP` | 路徑解析、IP 偵測 | `kde.sh`、`dashboard.sh` |

多數 Linux 發行版預設都有這些，所以平常不會察覺；精簡的映像或 macOS 才會遇到。

<a id="gap-05"></a>
### GAP-05 建立專案不建立 namespace

- **宣稱**：`create_project` 的註解「建立專案資料夾、namespace」；`TODO.md`「並且在 k8s 中建立 namespace」。
- **實際**：只建立目錄與檔案。`create_namespace` 函式存在（`k8s.sh:547-550`）但沒有任何地方呼叫。
- namespace 要由 `deploy.sh` 自己建立。

<a id="gap-06"></a>
### GAP-06 ngrok token 的存放位置

- 寫入：`echo "NGROK_TOKEN=…" >> ngrok.env`，相對於**當前目錄**（`ngrok.sh` 的 `check_ngrok_token`）。
- 讀取：`${KDE_PATH}/ngrok.env`（`kde.sh:247-249`）。
- 在 workspace 根目錄以外執行 `kde ngrok` 時，token 會存到別處，下次又被詢問。文件（`dev-tools/ngrok.md`）寫的是 `${KDE_PATH}/ngrok.env`。

<a id="gap-07"></a>
### GAP-07 Telepresence 的專案容器條件不同

`telepresence.sh` 重新定義了 `exec_script_in_container_with_project`，蓋掉 `k8s.sh` 的版本。差異：

| | 一般版本（`k8s.sh`） | Telepresence 版本 |
|---|---|---|
| `KDE_MOUNT_*` 掛載 | 有 | **沒有** |
| 專案的 `.env` | 載入 | **沒有載入** |
| `~/.docker`、`~/.netrc` | 沒有 | 有 |
| `HOME` | 未設定 | `/home/$USER` |
| docker 群組 | 從 `docker.sock` 取 gid | 從 `getent group docker` 取 |

專案若依賴 `KDE_MOUNT_*` 或 `.env`，在 Telepresence 的開發容器裡會缺東西。

<a id="gap-09"></a>
### GAP-09 環境類型取自當前環境

`scripts/stop/command.sh` 與 `scripts/load-image/command.sh` 以 `ENV_TYPE` 決定走 kind、k3d 還是外部 K8s 的分支，
而 `ENV_TYPE` 是前置流程為**當前環境**載入的。`kde stop other-env` 在 `other-env` 與當前環境類型不同時，會走錯分支。

<a id="gap-10"></a>
### GAP-10 `kde use` 的建立判斷

`scripts/use/command.sh:27` 的條件是「沒有 `.env` 或沒有 `kind-config.yaml`」就執行 `kde create`。
k3d 環境的設定檔叫 `k3d-config.yaml`，外部 K8s 沒有設定檔，所以對它們條件永遠成立；
環境運行中時 `kde create` 會以「環境已啟動」結束（結束碼 1），讓 `kde use` 回報失敗（當前環境已經切換成功）。

<a id="gap-25"></a>
### GAP-25 `kde projects link`

- **宣稱**：`TODO.md`「建立 project 集合資料夾的 softlink 成為 namespaces 資料夾」。
- **實際**：先要求 `namespaces/` 已存在，再 `ln -s <目錄> namespaces`。目標是既有目錄時，`ln -s` 會在**裡面**建立連結，
  結果是 `namespaces/<目錄名>` 這個 symlink，等於連結了一個專案，而不是把整個集合換成連結。

<a id="gap-26"></a>
### GAP-26 `kde exec` 與外部 K8s

外部 K8s 環境的 `K8S_CONTAINER_NAME` 是從 kubeconfig 解析出來的 API server 位址（`k8s.sh:253-266`），
`kde exec` 對它執行 `docker exec` 一定失敗。程式碼沒有像 `load-image` 那樣給出「不支援」的訊息。

---

## B 類：文件或 help 過時

<a id="gap-12"></a>
### GAP-12 `kde reset` 的頂層說明

`kde.sh:119`：「重置 kde 環境，清除全部 environments 和 projects 資料夾」。
實際（`scripts/reset/command.sh`）只作用於**一個**環境，保留 `*.template.yaml`，並詢問是否保留 `namespaces/`。
`docs/core/quick-reference.md` 的描述（「保留 namespaces」）比較接近實作。

<a id="gap-13"></a>
### GAP-13 過時的用法文字

`scripts/stop/command.sh`、`scripts/restart/command.sh`、`scripts/remove/command.sh` 的 `show_help` 寫的是
`kde k8s stop <name>` 等，`k8s` 這層子命令已不存在。

<a id="gap-14"></a>
### GAP-14 外部 K8s 與 `reset`

`docs/core/environment/kubernetes/external-kubernetes.md:89`：「外部 K8s 環境不支援 `kde stop`、`kde restart`、`kde reset`」。
`stop` 確實只印訊息，但 `reset` 對任何類型都會執行，會刪除外部環境的本機設定（含 kubeconfig）。

<a id="gap-15"></a>
### GAP-15 `kde ngrok -d`

help 的 `option: daemon, -d  在背景執行` 在 `scripts/ngrok/command.sh` 與 `scripts/utils/ngrok.sh` 中沒有任何對應的程式碼。

<a id="gap-16"></a>
### GAP-16 存在但沒記載的功能

| 功能 | help | `docs/core/` |
|---|---|---|
| `kde docs` | 有 | 沒有 |
| `kde status json` | 沒有 | quick-reference 有 |
| `kde projects exec` | 沒有 | quick-reference 有 |
| `kde dashboard --insecure` | 只在 usage 行 | quick-reference 有 |
| `kde start` 的第三個參數（自訂設定檔 / kubeconfig 路徑） | 頂層 help 沒有，`start -h` 有 | 有 |
| 環境變數 `KUBECONFIG_PATH`、`K8S_NODE_READY_TIMEOUT` | — | 沒有 |
| `kde openclaw` 整組命令 | 有 | `dev-tools/openclaw.md` 與 quick-reference 有；`overview.md` 的工具表、`README.zh-TW.md`、`principle.md` 都沒有提到 |

<a id="gap-18"></a>
### GAP-18 兩份 quick-reference 的分歧

`docs/core/quick-reference.md` 與 `.claude/skills/kde-usage/references/quick-reference.md` 應保持同步（`CLAUDE.md`），目前相差 35 行：

| 內容 | `docs/core` | skill |
|---|---|---|
| Pipeline 的 `--shell`、`--no-tty` | 沒有 | 有 |
| `kde proj tail --no-tty` | 有 | **沒有** |
| `kde claude-skill` 一節 | 有 | 沒有 |
| code-server 掛載 CLI 的說明 | 沒有 | 有 |
| 「方式 B」的標題 | Pipeline Redeploy 模式 | Pipeline Deploy 模式 |
| 「方式 B」的建議 | 改了映像、manifest 或環境變數才需要 `redeploy` | 一般直接 `deploy`；需要先清除既有資源時才用 `redeploy` |

最後一列是兩份文件給出**不同的操作建議**，不只是措辭差異。

skill 那份少了 `tail --no-tty`，而 skill 的讀者正是需要非互動用法的 AI agent。

<a id="gap-22"></a>
### GAP-22 `TODO.md`

- 「新增 docs 指令」仍未勾選，但 `kde docs` 已存在（只是複製文件，未必是當初設想的「產生 AI agent 可以看的文件」）。
- 「互動式指令需要修改成不互動」一節沒有反映 2026-04 之後已完成的部分。
- 清單中沒有 code-server、openclaw、claude-skill、telepresence、headlamp、alias。

<a id="gap-23"></a>
### GAP-23 `CLAUDE.md` 的 stage 選項清單

`CLAUDE.md` 稱 `_IMAGE`、`_SCRIPT`、`_WORKDIR`、`_SKIP`、`_MANUAL_ONLY`、`_ALLOW_FAILURE`、`_PAUSE` 是
「`scripts/utils/pipeline.sh` 讀取的完整集合」。就 `pipeline.sh` 而言正確，但 stage 層級還有 `_MOUNT_<名稱>`
（在 `k8s.sh` 讀取），pipeline 層級還有 `KDE_PIPELINE_FAIL_FAST`。讀者容易把它當成全部的設定。

---

## C 類：設計不一致

<a id="gap-08"></a>
### GAP-08 互動與非互動容器的掛載不同

`exec_script_in_container_with_project_no_tty` 額外掛入 `~/.docker` 與 `~/.netrc`（`k8s.sh:523-524`），互動版本沒有。
同一支 `build.sh` 以 `--no-tty` 執行時拿得到 registry 與 git 的憑證，互動執行時拿不到。

<a id="gap-11"></a>
### GAP-11 `redeploy` 的選項

`kde proj redeploy` 只掃描 `--no-tty`，不呼叫 `parse_pipeline_args`。`--from`、`--manual` 等會被靜默忽略。

<a id="gap-17"></a>
### GAP-17 寫死的映像

| 位置 | 映像 |
|---|---|
| `scripts/utils/headlamp.sh` | `ghcr.io/headlamp-k8s/headlamp:latest` |
| `scripts/utils/ngrok.sh`（`ingress` 與 URL 模式） | `ngrok/ngrok:latest` |

其他工具都由 `kde.env` 控制版本（[UC-WS-06](01-workspace.md#uc-ws-06-統一工具版本)）。

<a id="gap-19"></a>
### GAP-19 旗標慣例

| 旗標 | 意義 |
|---|---|
| `-d` | `expose`、`headlamp`、`code-server`：背景執行。`cloudflare-tunnel`：網域 |
| `-f` | `stop`、`pull`、`openclaw`（多數動作）：強制。`openclaw log`：跟隨 |
| `-p` | 多數命令：主機 port。`cloudflare-tunnel`：目標 port |
| 非互動 | `--no-tty`（pipeline、tail）與 `--command`（exec 類）兩套 |
| 未知參數 | `k9s`、`headlamp`、`code-server`、`openclaw` 報錯；`cloudflare-tunnel` 靜默忽略；`expose` 改走互動流程 |

`openclaw` 的 `-f` 雙重意義是經過考慮的（程式碼註解說明兩者不可能同時適用）；其餘沒有說明。

<a id="gap-20"></a>
### GAP-20 仍只能互動操作的命令

對照 [NFR-02](08-non-functional.md#nfr-02-非互動可操作性)，下列操作沒有非互動的執行方式：

| 命令 | 互動點 |
|---|---|
| `kde code-server` | 密碼（每次都問，沒有旗標或環境變數） |
| `kde start`（新環境） | API server port、ingress port |
| `kde project create` | 是否使用 Git、repo、分支、兩個映像 |
| `kde project link`、`kde projects link` | 目錄路徑 |
| `kde project ingress` | domain、service、port |
| `kde projects fetch` / `pull` | 每個專案是否下載 |
| `kde reset` | 兩次確認，沒有 `-f` |
| `kde ngrok service` / `pod` | namespace、資源、port（沒有對應的旗標） |
| `kde telepresence` | CIDR、port 對應、專案選擇 |
| `kde openclaw onboard` | 精靈本身是互動的 |

<a id="gap-21"></a>
### GAP-21 未被呼叫的函式

`create_namespace`、`is_env_initializing`、`exit_if_env_init`（`k8s.sh`）、`start_linuxserver_code_server`（`code-server.sh`，註解「暫時不使用」）
在 `scripts/` 中只有定義、沒有呼叫。`has_any_namespace`、`has_any_pod`、`has_any_service` 同樣沒有被使用（後兩者直接呼叫主機的 `kubectl`）。
`get_local_ip` 與 `open_browser` 在 `dashboard.sh` 與 `headlamp.sh` 各有一份相同的實作。

<a id="gap-24"></a>
### GAP-24 Pipeline 不驗證 stage 名稱

- `--only <s>` 直接執行該 stage，不檢查它是否在 `KDE_PIPELINE_STAGES` 裡。這是 `undeploy` 能運作的機制（它通常不在清單中），但也表示打錯名稱時得到的是「腳本不存在」而不是「沒有這個 stage」。
- `--from <s>` 的 stage 不存在時，沒有任何 stage 被執行，印出「沒有執行任何階段」，結束碼 0。

<a id="gap-27"></a>
### GAP-27 說明與結束碼

- 顯示說明的結束碼不一致：頂層、`start`、`stop`、`k9s`、`code-server`、`openclaw` 為 0；`project`、`projects`、`ngrok`、`cloudflare-tunnel`、`telepresence`、`project exec -h` 為 1。
- 未知的頂層命令顯示說明、結束碼 0，腳本無法由結束碼得知命令打錯了。
- `kde telepresence <未知動作>` 要等選完 namespace、輸入 CIDR、啟動連線容器之後才顯示說明。

---

## 待確認事項

這些是程式碼無法回答的問題。答案會決定對應的條目是「需求」還是「缺陷」。

| # | 問題 | 相關 |
|---|---|---|
| Q1 | Pipeline 的 `ALLOW_FAILURE` 與 `FAIL_FAST=false` 是仍然要支援的功能嗎？如果是，GAP-01 是需要修的 bug；如果已經沒人用，文件應該拿掉 | GAP-01 |
| Q2 | `kde remove`、`kde project remove` 沒有確認提示，`remove` 也不停止叢集。這是刻意的（方便腳本使用）還是遺漏？ | UC-ENV-09、UC-PRJ-08、NFR-05 |
| Q3 | 「專案」是否應該保證 K8s namespace 存在？還是 namespace 的建立本來就該交給 `deploy.sh`？ | GAP-05 |
| Q4 | `kde restart` 對已停止的環境應該成功（等同 `start`）嗎？OpenClaw 的 `restart` 是這樣設計的 | UC-ENV-04、NFR-11 |
| Q5 | 「主機只需要 Docker」是硬性需求還是行銷用語？若是硬性需求，`envsubst`、`openssl`、`git` 需要搬進容器 | GAP-04、NFR-01 |
| Q6 | 非互動操作的目標是「所有命令」還是「AI agent 日常會用到的命令」？這決定 GAP-20 的清單有多少要處理 | GAP-20、NFR-02 |
| Q7 | 未知命令與顯示說明時的結束碼，是否需要統一？ | GAP-27 |
| Q8 | 主機裝有 `k9s` 時直接使用主機版本，是刻意保留的後門嗎？它與「容器優先」及 kubeconfig 使用容器名稱連線（[CON-03](08-non-functional.md#con-03-叢集連線透過-docker-網路)）都有衝突 | UC-ACC-01 |
| Q9 | macOS 是否為正式支援的平台？ | NFR-13 |
| Q10 | 外部 K8s 環境的 `reset`、`exec` 應該被擋下來嗎？ | GAP-14、GAP-26 |
