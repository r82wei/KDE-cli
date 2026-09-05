# OpenClaw

**以容器承載 OpenClaw agent，容器內可直接使用 `kde` CLI 操作宿主的 Docker**

## 核心概念

### 什麼是 `kde openclaw`？

`kde openclaw` 用一個容器承載 [OpenClaw](https://openclaw.ai) agent gateway。容器內已安裝與主機同版的 `kde` CLI（透過唯讀掛載），並掛入宿主的 `docker.sock`（DooD），因此 OpenClaw agent 可以在容器內直接執行 `kde` 指令來操作你的 K8s 開發環境。

### 主要特點

- **狀態全在 workspace 裡**：容器 home 整個掛在 `${KDE_PATH}/.openclaw-home`（涵蓋 `~/.openclaw`、`~/.codex`、`~/.claude` 等），可隨 workspace 搬移、可用 `kde openclaw reset` 一次清除。該目錄含 provider 的 OAuth 憑證與 gateway token，`kde init` 的 `.gitignore` 範本已將它排除，**不要**把它加進版控
- **容器可拋棄**：容器本身不保存任何獨有狀態，`kde openclaw stop` 隨時可以安全執行
- **DooD 整合**：容器內可直接下 `kde` / `docker` 指令操作宿主環境
- **PUID/PGID 對齊**：預設沿用主機使用者的 uid/gid，避免掛載檔案的擁有權問題

### 十三個 action 總覽

| action | 用途 |
|---|---|
| `run` | 背景常駐啟動 gateway |
| `onboard` | 一次性互動容器，執行初始化精靈 |
| `stop` | 停止並移除容器（冪等） |
| `restart` | 先 `stop` 再 `run`（未指定 port 時沿用現有容器的 port） |
| `backup` | 手動備份 `.openclaw-home`（會短暫停止容器） |
| `upgrade` | 拉取映像的最新版本，映像真的變了才重啟容器 |
| `downgrade` | 從備份還原資料與映像版本（不改 `kde.env`） |
| `tui` | 互動進入 OpenClaw TUI |
| `exec` | 進入容器的 bash（不帶指令）或非互動執行指令 |
| `log` | 查看 gateway 容器日誌 |
| `token` | 印出 gateway 的 auth token |
| `dashboard` | 鑄一次性的 owner 配對連結（瀏覽器首次連上 dashboard 用） |
| `reset` | 刪除 workspace 的 `.openclaw-home` |

## 使用說明

### 基本指令語法

```bash
kde openclaw <action> [option]
```

### 選項總表

| 選項 | 簡寫 | 說明 | 哪些 action 吃 |
|------|------|------|------|
| `--port` | `-p` | gateway 對外發布的 port（預設 `18789`，亦可用環境變數 `OPENCLAW_PORT`） | `run`、`restart`、`upgrade` |
| `--force` | `-f` | 略過確認提示 | `onboard`、`reset`、`backup`、`downgrade` |
| `--follow` | `-f` | 跟隨日誌輸出 | `log` |
| `--tail` | - | 日誌顯示的行數（預設 `100`） | `log` |
| `--command` | - | `exec` 時執行指定指令（不配置 TTY），等同直接寫成位置參數 | `exec` |
| `--json` | - | 輸出原始 JSON 而非人類可讀的指引 | `dashboard` |
| `--list` | - | 只列出可用備份，不做任何還原 | `downgrade` |
| `--help` | `-h` | 顯示說明 | 全部 |

> **`-f` 依 action 分流**：對 `onboard`/`reset` 是「略過確認」，對 `log` 是「跟隨」。這兩件事不可能同時適用於同一個 action（`log` 沒有確認提示可略過，`onboard`/`reset` 也沒有日誌可跟隨），所以共用 `-f` 不會產生歧義；要明確表達時仍有 `--force` 與 `--follow` 兩個長旗標。

> `exec` 的指令可以直接寫成位置參數（`kde openclaw exec "openclaw doctor"`），與 `--command` 等效，但只能給一次。**含空白的指令請用引號包成一個參數**——`kde openclaw exec ls -la` 會在 `-la` 上報錯，而不是靜默只跑 `ls`。

## 各 Action 詳解

### `run` — 背景常駐啟動 gateway

```bash
kde openclaw run
kde openclaw run -p 19000
```

**前置條件**：
- OpenClaw 必須已完成初始化（見下方「初始化狀態判斷」），否則報錯並提示先執行 `kde openclaw onboard`——**不會**自動代跑 onboarding
- 同名容器不可已存在，否則報錯並提示先 `kde openclaw stop`

**行為**：`docker run -d` 背景啟動 `openclaw gateway run --port 18789`（視 auth 設定可能再加上 `--bind auto`，見下方 Dashboard），套用 `--restart unless-stopped`，接著等待數秒做健康檢查（容器仍在 running 才算成功；失敗會印出 `docker logs --tail 50` 並 `exit 1`，不會回報假成功）。

**成功輸出範例**：
```
✓ openclaw gateway 已在背景啟動 (openclaw-myworkspace)
存取網址: http://localhost:18789 (已配對過的瀏覽器)
首次連線: kde openclaw dashboard (鑄一次性的 owner 配對連結)
查看日誌: kde openclaw log -f
取得 token: kde openclaw token
停止服務: kde openclaw stop
```

**失敗訊息範例**：
```
❌ OpenClaw 尚未初始化 (gateway.mode 不是 local)
   請先執行：kde openclaw onboard
```
```
❌ 容器 openclaw-myworkspace 已存在，請先停止：kde openclaw stop
```

### `onboard` — 執行初始化精靈

```bash
kde openclaw onboard
kde openclaw onboard -f    # 已初始化時跳過覆寫確認
```

**前置條件**：不需要 gateway 已在運行——`onboard` 走的是獨立的一次性互動容器（`--rm`），這正是它必須是獨立 action 的理由：未初始化時 `run` 會拒絕啟動，若要求使用者先 `run` 再 `onboard` 會變成死結。

**行為**：啟動一次性互動容器（`-it --rm`，容器名 `openclaw-<workspace>-onboard`）跑 `openclaw onboard --mode local --agent-name main`。若已偵測到初始化完成，會先詢問 `y/n` 是否覆寫（`-f` 跳過確認）。精靈結束後（含被 Ctrl-C 中斷的情況）都會重新檢查初始化狀態，仍未成功則報錯。

**為什麼釘住 `--agent-name main`**：帶了這個旗標，精靈就不會問「What should we call your first agent?」——而那一題填非 `main` 的名字會壞掉。實測（OpenClaw 2026.8.2 互動精靈）填 `MaximeDev` 時，精靈確實建立了 agent `maximedev` 並把 provider 的 OAuth 憑證寫進該 agent 自己的 `agents/maximedev/agent/openclaw-agent.sqlite`，但**最後一次寫 config 時把 `agents.entries` 整段蓋掉了**；roster 於是退回隱含的預設 agent `main`，而 `main` 的 auth store 是空的，聊天就會拿到 `401 Missing bearer`（見下方故障排除）。名字保留 `main` 時即使 entries 同樣被蓋掉也無害：共用 auth store 的正規位置本來就是 `agents/main`，其他 agent 靠 `agents.defaults.authInheritance` 繼承它。代價是不能在精靈裡命名第一個 agent，事後仍可用 `openclaw agents set-identity` / `openclaw agents add` 處理。

**前置條件失敗**：同名 onboard 容器已存在（例如上次異常中斷未清乾淨）→ 報錯並提示 `docker rm -f <name>-onboard`。

**成功輸出**：`✓ OpenClaw 初始化完成，可執行：kde openclaw run`

### `stop` — 停止並移除容器

```bash
kde openclaw stop
```

冪等：容器不存在時印出提示並 `exit 0`，不視為錯誤。存在時依序 `docker stop` + `docker rm`；任一步驟失敗會報錯並提示手動 `docker rm -f <name>`。

### `restart` — 先 stop 再 run

```bash
kde openclaw restart
kde openclaw restart -p 20000
```

等同依序執行 `stop` 與 `run`，但 port 的處理多一層：**未指定 port 時沿用現有容器目前發布的 port**，而不是退回內建預設。

理由是用 `kde openclaw run -p 19000` 起的容器，若 `restart` 悄悄退回 `18789`，已配對的瀏覽器書籤與先前鑄出的 dashboard 連結會一起失效——而使用者的指令裡完全沒提到 port，不會預期它改變。port 是問 `docker port` 取得的（與 `dashboard` 同一個做法，因為容器實際發布的 port 才是真相），讀不到就維持原值，不會讓 `restart` 因此失敗。

只有在**完全沒表態**時才沿用容器現況，所以明確打的 `-p 18789` 仍然勝出：

| 情境 | 結果 |
|---|---|
| `restart`（容器跑在 19000） | 19000（沿用） |
| `restart -p 20000` | 20000 |
| `restart -p 18789`（容器跑在 19000） | 18789——明確指定勝過沿用 |
| `OPENCLAW_PORT=20000 kde openclaw restart` | 20000（環境變數也算表態） |
| `restart`（容器不存在） | 依 `run` 的既有規則，即內建預設 |

注意最後一列的推論：若有人把 `OPENCLAW_PORT` 寫進 workspace 的 `.env`，那等於永久表態，`restart` 會一直用那個值而不再沿用容器現況。這符合上述優先序，不是故障。

`stop` 失敗時會中止，不繼續 `run`——否則 `run` 會立刻報「容器已存在，請先停止」，使用者會同時看到兩條互相矛盾的錯誤，後者還會叫他去做剛剛失敗的那件事。

容器本來就沒在跑時 `stop` 是冪等的，因此 `restart` 對未啟動的 workspace 等同 `run`，這是刻意的。

### `backup` — 手動備份 `.openclaw-home`

```bash
kde openclaw backup       # 容器運行中會先問過
kde openclaw backup -f    # 略過確認
```

與 `upgrade` 內建的那次備份產出完全相同的東西（同樣的檔名格式、manifest、保留份數），差別在於它自己負責停止與啟動：

| 容器狀態 | 行為 |
|---|---|
| 運行中 | 提示確認 → 停止 → 備份 → **啟動回來**（沿用原本的 port） |
| 未運行 | 直接備份，不提示、**不啟動** |

**為什麼要停止容器**：手動備份幾乎都在容器運行中執行，正面撞上熱備份 SQLite 的一致性問題——`.codex` 的 WAL 有未 checkpoint 的交易，而打包實測要 9 秒，期間若有寫入就可能備出還原不回來的快照。停掉再備份是唯一可信的做法，代價是中斷服務，所以先問過再動手（預設是**不**繼續，直接按 Enter 等於取消）。

容器本來就沒在跑時不問也不啟動：沒有東西要中斷，而把停著的容器叫起來是 `run` 的職責，不該由備份順手代辦。

停止失敗會中止，不會繼續備份——那樣會拿到熱快照，而且後面還會試著啟動一個沒停掉的容器。

手動備份同樣受保留份數約束，否則它會成為繞過上限的漏洞。

### `upgrade` — 拉取最新映像，有變才重啟

```bash
kde openclaw upgrade
```

**為什麼需要這個 action**：`docker run` 的預設 pull policy 是 `missing`——本地只要已有該 tag 就直接用，**永遠不會回頭問 registry**。所以 registry 上的 `latest` 換了新版之後，`run` 與 `restart` 仍會沉默地跑舊映像，而且完全沒有徵兆。要換版本就必須明確 `docker pull`。

`--pull always` 刻意沒有加進 `run`：`restart` 的語意是重啟而非升級，每次都打 registry 會讓離線環境直接失敗，也讓每次重啟多一次網路往返。換版本是明確的意圖，值得一個明確的指令。

行為矩陣：

| 容器狀態 | 映像有變 | 行為 |
|---|---|---|
| 運行中 | 是 | 印出版本變化，接著 `restart`（沿用現有 port） |
| 運行中 | 否 | 印「已是最新版本」，**不重啟** |
| 未運行 | 是 | 更新映像，提示用 `run` 啟動 |
| 未運行 | 否 | 印「已是最新版本」，提示用 `run` 啟動 |

- **沒有新版就不重啟**：重啟會中斷 gateway、踢掉進行中的 session，在沒有換到新映像的情況下不值得付這個代價。
- **容器未運行時只更新映像、不順便啟動**：`upgrade` 的職責是「把映像更新到最新，並讓正在跑的容器換過去」，沒有東西要重啟時就把啟動留給 `run`。
- **換版本前會自動備份 `.openclaw-home`**，時機在 `stop` 之後、新版啟動之前；要退回去用 [`downgrade`](#downgrade--從備份還原資料與映像版本)。
- **`pull` 失敗會在動到容器之前中止**：離線時把跑著的 gateway 停掉卻換不到新映像，會把「沒升級」惡化成「服務不見了」。
- 判斷「映像有沒有變」是比對 `docker image inspect` 的 image ID，不去解析 `docker pull` 的輸出文字——那是給人看的訊息，格式會隨 Docker 版本變。版本號取自映像的 `org.opencontainers.image.version` label，純粹用於顯示，取不到會顯示 `unknown`。

> **`build.sh` 刻意不打 `latest` tag**：`latest` 的語意是「registry 上最新發布的版本」，而本機 `build.sh` 的產物只是一次性的測試映像。讓它冒用 `latest` 會污染之後這台機器上所有 `run`/`restart` 的映像來源——本機跑一次 build 就會永久停在該映像上，症狀正是「明明 release 了新版，容器卻一直是舊的」。要用剛建好的映像請明確指定 `OPENCLAW_IMAGE=r82wei/kde-openclaw:<hash>-<version> kde openclaw run`（`build.sh` 結束時會把這行印出來）。

### `downgrade` — 從備份還原資料與映像版本

```bash
kde openclaw downgrade            # 列出備份並互動選擇
kde openclaw downgrade --list     # 只看有哪些備份，不動任何東西
kde openclaw downgrade 2          # 直接還原第 2 份
kde openclaw downgrade 2 -f       # 略過確認
```

還原**資料與映像版本兩者**，讓 workspace 回到那份備份當時的狀態。

#### 備份從哪裡來

`upgrade` 換版本時自動建立，落在 `<workspace>/.openclaw-backups/`：

```
openclaw-backup-20260904-161500-r82wei_kde-openclaw_5e990b9-2026.8.2.tar.gz
```

- **時機是 `stop` 之後、新版啟動之前**。那個瞬間「舊版已停、新版未起」，沒有行程在寫 SQLite——容器還在跑時打包 sqlite 加 WAL 會拿到不一致的快照，而問題要到還原那天才會浮現。附帶好處是 `pull` 失敗或本來就是最新版時不會白備份。
- 預設**保留最新 3 份**，超過就由舊而新刪除。整個 `.openclaw-home` 實測 374MB、壓縮後 147MB（耗時約 9 秒），所以刻意有上限。份數可用 `OPENCLAW_BACKUP_KEEP` 調整。
- 檔名裡的 tag 經過清洗（`/` 與 `:` 都變成 `_`），**無法反推原始值**。精確資訊放在包內最前面的 `openclaw-backup-manifest`：

```
OPENCLAW_BACKUP_IMAGE=docker.io/r82wei/kde-openclaw:5e990b9-2026.8.2
OPENCLAW_BACKUP_IMAGE_ID=sha256:4456b43d97a4...
OPENCLAW_BACKUP_VERSION=2026.8.2
OPENCLAW_BACKUP_AT=2026-09-04T16:15:00+08:00
```

  `downgrade` 從這裡取要還原成哪個映像，不從檔名猜。manifest 排在 tar 最前面，所以列出備份只需抽出前幾 KB，不必解開整包。

#### 映像釘選：為什麼不改 `kde.env`

`downgrade` 把映像寫進 `<workspace>/.openclaw-image`，而**不動 `kde.env`**——後者是版控檔案，會隨 workspace 同步到每個人的機器上，而「我這台暫時停在舊版」純粹是本機狀態。把它 commit 出去會讓其他人也被釘住，甚至拉不到那個 tag。

| action | 對釘選的行為 |
|---|---|
| `upgrade` 以外的所有 action | 遵守釘選（`run`、`restart`、`tui`、`exec`、`token`…），並明確印出使用了哪個映像與釘選檔路徑 |
| `downgrade` | **寫入**釘選（值取自備份的 manifest） |
| `upgrade` | **清除**釘選，回到 `kde.env` 指定的映像 |

兩者對稱：`downgrade` 釘住、`upgrade` 放開。否則 `downgrade` 之後執行 `upgrade` 會變成「升級一個被釘住的舊 tag」，沒有意義。

釘選生效時一定會印出來，而且**連釘選檔的路徑一起印**：

```
ℹ️  使用釘選映像：docker.io/r82wei/kde-openclaw:5e990b9-2026.8.2
   來源：/path/to/workspace/.openclaw-image
   此檔覆蓋 kde.env 的 OPENCLAW_IMAGE，改 kde.env 不會生效
   解除：kde openclaw upgrade（或刪除上述檔案）
```

實際跑的版本與 `kde.env` 寫的不一致卻毫無線索，正是這個專案已經踩過一次的無聲版本歪掉；而只說「有釘選」不說路徑，使用者會反覆去改 `kde.env`——`kde.env` 在這裡正是被蓋掉的那一邊，怎麼改都不會生效。

這幾行印在 **stderr**，因為 `token` 的 stdout 是設計成可被管線接走的（`kde openclaw token | pbcopy`），提示混進去會讓管線拿到垃圾。

#### 還原流程

1. 列出備份（由舊到新編號），未給編號則互動詢問
2. 確認（`-f` 略過）
3. 停止容器
4. **備份現況**——還原會覆蓋它，不先存一份的話 `downgrade` 自己就不可逆。這份同樣算進保留額度
5. 清空並還原 `.openclaw-home`
6. 寫入映像釘選
7. 啟動容器

第 5 步是「清空目錄內容」而非 `rm -rf` 目錄本身：`.openclaw-home` 是 named volume（`local` driver + `o=bind`）綁著的路徑，把目錄刪掉再重建會讓掛載守著已刪除的 inode——`cdb2e58` 在 `local-install.sh` 上踩過同一個坑。

編號無效（超出範圍或非數字）一律報錯而不猜：還原是破壞性的，猜錯等於用錯的資料蓋掉現況。

#### `.gitignore`

備份包、釘選檔與容器 home 都以 `.openclaw` 開頭，由一條規則涵蓋：

```gitignore
/.openclaw*
```

**前導斜線是必要的。** gitignore 的 pattern 不帶斜線時會匹配任何層級，少了它會連 `environments/*/namespaces/*/<repo>/.openclaw*` 這種專案內的檔案一起忽略掉。實測對照：

```
/.openclaw*  →  k9s/.openclaw-note  未被忽略（正確）
.openclaw*   →  k9s/.openclaw-note  被忽略（誤傷）
```

備份包本身刻意**不**以 `.` 開頭——外層目錄已被忽略，裡面再隱藏一次只會讓人用 `ls` 看不到數百 MB 的佔用。

### `tui` — 互動進入 OpenClaw TUI

```bash
kde openclaw tui
```

**前置條件**：容器必須正在運行，否則報錯並提示先 `kde openclaw run`：
```
❌ 容器 openclaw-myworkspace 未在運行，請先執行：kde openclaw run
```

**行為**：`docker exec -u node -it <container> openclaw`。

### `exec` — 進入容器的 bash

```bash
kde openclaw exec                                   # 互動進入 bash
kde openclaw exec "openclaw doctor"                 # 非互動執行指令
kde openclaw exec --command "openclaw doctor"        # 等效寫法
kde openclaw exec "kde proj tail api --no-tty"       # 容器內的其他指令一樣能跑
```

**前置條件**：同 `tui`，容器必須正在運行。

**兩種行為**：
- 不帶指令：`docker exec -u node -it <container> bash`
- 帶指令：`docker exec -u node <container> bash -c "<cmd>"`（不配置 TTY，適合腳本 / AI agent）

**`exec` 刻意不代入 `openclaw`**：指令原封不動交給 `bash -c`，所以你打的字跟容器裡實際跑的一致。若這裡自動補上 `openclaw`，就得反過來把 `openclaw` 這個字拿掉（`kde openclaw exec dashboard`）——既反直覺，也跑不了容器內的其他指令（`kde`、`git`…）。互動的 OpenClaw TUI 由 `tui` 提供。

### `log` — 查看 gateway 容器日誌

```bash
kde openclaw log                # 最後 100 行，印完就結束
kde openclaw log -f             # 跟隨（--follow 亦可），Ctrl-C 離開
kde openclaw log --tail 500     # 改行數
kde openclaw log -f --tail 20   # 兩者可併用
```

**前置條件**：容器必須**存在**——注意是存在，不是正在運行。容器因設定有誤而 crash 掉之後，正是最需要看日誌的時候，而 `docker logs` 對已退出的容器仍讀得到。容器不存在時：
```
❌ 容器 openclaw-myworkspace 不存在，請先執行：kde openclaw run
```

**行為**：`docker logs [-f] --tail <n> <container>`。跟隨模式下用 Ctrl-C 離開會讓 docker 回 130，那是正常結束而不是失敗，`log` 會回 0。

### `token` — 印出 gateway 的 auth token

```bash
kde openclaw token
kde openclaw token | xclip -sel clip    # stdout 只有 token，可被管線接走
```

**前置條件**：無。走一次性容器讀設定檔，**gateway 沒在運行也能取**。

**行為**：以一次性容器（與初始化狀態檢查同一組掛載）讀 `~/.openclaw/openclaw.json` 的 `gateway.auth.token`，只把 token 本身印到 stdout；所有錯誤訊息走 stderr，因此管線接走的內容不會夾帶提示文字。

**為什麼不用官方的 `openclaw gateway auth-token`**：實測（2026.8.2）該指令需要 `--show`，且會以「Refusing to print the Gateway token outside an interactive terminal」拒絕印到非互動終端機，腳本完全取不到；而 `openclaw config get gateway.auth.token` 回傳的是 `__OPENCLAW_REDACTED__`。

**失敗訊息**：
```
❌ gateway.auth.mode 為 none，本來就沒有 token
   要啟用 auth：kde openclaw exec 後執行 openclaw configure
```
```
❌ 讀不到 gateway token (openclaw.json 的 gateway.auth.token 為空或檔案不存在)
   若尚未初始化，請先執行：kde openclaw onboard
```

### `dashboard` — 鑄一次性的 owner 配對連結

```bash
kde openclaw dashboard          # 印出連結與注意事項
kde openclaw dashboard --json   # 原始 JSON（單行，可餵給 jq / python）
```

**前置條件**：容器必須正在運行。

**為什麼需要這個 action**：gateway 的 token auth 過關之後，**新瀏覽器第一次連線還要一次性的裝置配對核准**，失敗長相是 `disconnected (1008): pairing required`。詳見下方「Dashboard 的首次連線需要裝置配對」。

**行為**：`docker exec -u node <container> openclaw dashboard --no-open --json`，取出 JSON 後把 URL 裡的 `127.0.0.1` 換成 `localhost`、容器內的 `18789` 換成 `docker port` 查到的**主機實際發布 port**（拿不到時退回 `OPENCLAW_PORT`），再印出 `browserUrl`。

不改寫的話，`kde openclaw run -p 19000` 的人會拿到一個指向 `127.0.0.1:18789` 的連結——那是容器自己的視角，貼到主機瀏覽器連不上。

**輸出範例**：
```
✓ 已鑄出一次性的 owner 配對連結，請在主機的瀏覽器打開：

  http://localhost:18789/#bootstrapToken=<...>&bootstrapProfile=owner

注意：連結約 10 分鐘後失效，且只能用一次——它只會把「第一個打開它的瀏覽器
      profile」配成 administrator。換瀏覽器、清掉 site data 或用無痕視窗，
      都要重新執行本指令。
已配對過的瀏覽器直接開 http://localhost:18789 即可，token 用 kde openclaw token 取得。
```

**失敗訊息**：
```
❌ 取不到 dashboard 連結，openclaw dashboard 沒有回傳 JSON
   請確認 gateway 是否健康：kde openclaw log --tail 50
```

### `reset` — 刪除 workspace 的 `.openclaw-home`

```bash
kde openclaw reset
kde openclaw reset -f
```

**前置條件**：容器不可在運行中，否則報錯並要求先 `kde openclaw stop`（避免在容器運行中抽掉設定，產生難以診斷的半死狀態）：
```
❌ 容器 openclaw-myworkspace 仍在運行，請先執行：kde openclaw stop
```

**行為**：`.openclaw-home` 不存在時視為無需重設（`exit 0`）。存在時預設 `read -p` 詢問 `y/n`（含 OpenClaw 設定與 auth 密鑰的警告文字），`-f` 跳過確認，直接 `rm -rf`。

## Port 說明

- 容器**內**恆為 `18789`（`openclaw gateway run --port 18789`，不受 `-p` 影響）
- 主機側發布 port 的優先序：`-p`/`--port`（當次指定）> 環境變數 `OPENCLAW_PORT` > 內建預設 `18789`
- `restart` 在前兩者都沒給時，會先沿用**現有容器目前發布的** port，只有容器不存在時才落到內建預設（見上面的 `restart` 章節）
- **`OPENCLAW_PORT` 刻意不寫入 `kde.env`**：`kde.env` 是版控檔案，會隨 workspace git pull 到每個人的機器上；而 port 是每台開發機各自的環境條件（可能已被其他服務佔用），同步只會互相干擾。要固定使用非預設 port，請自行在 shell profile 或 `export OPENCLAW_PORT=...` 設定，不要寫進 `kde.env`
- 相對地，`OPENCLAW_IMAGE`（映像版本）**會**寫入 `kde.env`——那是整個 workspace 該對齊的版本，理應同步

```bash
# 一次性指定
kde openclaw run -p 19000

# 或用環境變數（-p 優先於此）
export OPENCLAW_PORT=19000
kde openclaw run
```

## Dashboard

Dashboard 與 gateway 共用同一個 port（單一多工 port：WebSocket RPC、HTTP API、plugin routes、Control UI 全部共用），開啟 `http://localhost:<port>` 即可看到（`run` 成功時會印出正確的網址）。

### bind 位址：為什麼 `run` 會加 `--bind auto`

OpenClaw 偵測到容器環境時，預設會把 gateway 綁在 `0.0.0.0` 以配合 port forwarding。但
**onboarding 精靈常會把 `gateway.bind` 明確寫成 `loopback`**，而明確的 config 值會蓋過那個
預設值。這時 gateway 只聽容器內的 `127.0.0.1`，`-p` 永遠轉不進去，dashboard 從主機完全連不到。

因此 `kde openclaw run` 會主動帶 `--bind auto`（CLI 旗標優先於 config）把它覆蓋回來。
在容器隔離的 network namespace 內綁 `0.0.0.0` 是標準做法——對外仍只有 `-p` 發布的那一個 port。

**例外：`gateway.auth.mode` 為 `none` 時不加這個旗標。** OpenClaw 會以
`Refusing to bind gateway to auto without auth` 拒絕啟動，硬加旗標等於把「能跑但連不到」
變成「根本起不來」。這種情況 `run` 不會印存取網址，而是明說 dashboard 僅容器內可達，
並提示先啟用 auth。

### 首次連線需要裝置配對

gateway 的 token auth 只是第一關。OpenClaw 對 Control UI 還有一層**裝置配對**：
新瀏覽器（精確地說是新的瀏覽器 profile）第一次連線需要一次性核准，沒核准前會看到
`disconnected (1008): pairing required`。

OpenClaw 對「直接 loopback 連線」有自動核准配對的例外，但**這個容器架構吃不到**：
gateway 跑在容器內，主機瀏覽器經 `-p` 轉進來，從 gateway 的角度對端位址是 Docker
bridge（例如 `172.17.0.1`）而不是 `127.0.0.1`。官方文件對這種情形的規則是仍需明確核准
（「Direct Tailnet binds and LAN browser connects still require explicit approval」）。

官方指定的 owner 路徑是在 gateway 主機上跑 `openclaw dashboard`，`kde` 把它包成一個
action：

```bash
kde openclaw dashboard
```

它會鑄一條短命（實測約 10 分鐘）、單次使用的連結，並讓 redeem 它的那一個瀏覽器拿到
持久的 administrator 憑證。已配對過的瀏覽器之後直接開 `http://localhost:<port>`
即可，需要在設定面板貼 token 時用 `kde openclaw token` 取得。

**為什麼這件事不能在 `onboard` 一次做完**：

1. bootstrap token 短命（約 10 分鐘），onboard 完到真的開瀏覽器之間隔多久無法預期
2. 連結單次使用，且只綁定「redeem 它的那一個瀏覽器 profile」，別的 profile 無法繼承或重放
3. 每個瀏覽器 profile 有自己的 device ID——換瀏覽器、清 site data、無痕視窗都要重新配對，
   所以這本質上不是「初始化一次」而是「每次要用新瀏覽器時做一次」
4. `onboard` 走的是一次性容器，那時常駐 gateway 還沒啟動，在那裡鑄的連結指向一個即將消失的 gateway

也可以走 CLI 核准流程（適合已經在瀏覽器按下連線、想手動核准的情況）：

```bash
kde openclaw exec "openclaw devices list"
kde openclaw exec "openclaw devices approve <requestId>"
```

## 狀態的持久化位置

這個功能的核心保證是「容器可拋棄、狀態全在 workspace」。而 **OpenClaw 的狀態並不只在
`~/.openclaw`**：

| 狀態 | 位置 |
|---|---|
| 設定、gateway sqlite（含 device 身分與配對）、agent auth store | `~/.openclaw/` |
| codex 側憑證（含 ChatGPT OAuth） | `~/.codex/` |
| hermes | `~/.hermes/` |
| Claude CLI 整合 | `~/.claude/`、`~/.claude.json`、`~/.local/share/claude`、`~/.local/bin` |
| legacy OAuth 憑證的加密金鑰 | `~/.config/openclaw/` |
| 個人 skills | `~/.agents/skills`（`kde-usage` 由唯讀掛載提供，見「CLI 自帶 skill 的自動載入」） |
| 套件與快取 | `~/.npm`、`~/.cache` |

因此 `kde openclaw` 讓**整個容器 home** 落在 workspace 裡。做法不是直接 bind mount
該目錄，而是建一個指向它的 named volume：

```bash
docker volume create --driver local \
    --opt type=none --opt device=${KDE_PATH}/.openclaw-home --opt o=bind \
    openclaw-<workspace>-home
docker run -v openclaw-<workspace>-home:/home/node ...
```

兩種寫法的內容都落在主機的 `${KDE_PATH}/.openclaw-home`，差別在**首次掛載時**：

| | 直接 bind mount 空目錄 | named volume（採用） |
|---|---|---|
| 映像 `/home/node` 的既有內容 | 被整個遮蔽 | Docker 自動預先複製進來 |
| `.bashrc` / `.profile` | 消失，要自己補 | 保留 |
| 未來版本烤進 home 的東西 | 靜默失效 | 自動帶進來 |

映像已經把 `PLAYWRIGHT_BROWSERS_PATH` 指向 `~/.cache/ms-playwright`（目前是 runtime
下載，不在映像裡）。若上游哪天把 Chromium 烤進去，直接 bind mount 會讓它安靜消失，
named volume 則不會——這是選後者的主要理由。

`docker volume create` 本身冪等，所以每次都直接呼叫，不需要先檢查存在與否。

> **但書**：預先複製只在目錄為空時發生**一次**。既有 workspace 升級 base image 時，
> 新版映像新增在 home 的內容不會被補進來。這是 Docker named volume 的既定行為，官方
> 的 `OPENCLAW_HOME_VOLUME` 做法亦同。因此 `build.sh` / `release.sh` 的
> `OPENCLAW_VERSION` 刻意釘住版本而非用浮動的 `latest`，讓升級是一次有意識的動作。

`kde openclaw reset` 除了刪除 `.openclaw-home`，也會 `docker volume rm` 該 volume ——
否則會留下一個指向已不存在路徑的 volume 定義，下次 `run` 會沿用它、拿不到預先複製。

### 為什麼不逐個設環境變數

那些路徑多半都有覆寫用的環境變數（`CODEX_HOME`、`HERMES_HOME`、`CLAUDE_CONFIG_DIR`、
`GEMINI_CLI_HOME`、`GH_CONFIG_DIR`、`XDG_*`…），但逐個覆寫是追不完的：每新增一個
provider plugin 就要再補一行，而硬寫路徑、未提供覆寫的 plugin 根本救不了。

### 不處理會出現的症狀

如果只掛 `~/.openclaw`，會出現一個很難診斷的症狀：**onboarding 精靈的「Test AI access
now」測試通過（憑證此刻就在該容器內），但精靈結束、`--rm` 容器銷毀後憑證一起消失，
之後 gateway 一問就 `401 Missing bearer`**，而 `openclaw models status` 顯示
`OAuth/token status: none`。

## 掛載說明

`kde openclaw` 的三種容器（狀態檢查、onboard、gateway）共用同一組掛載參數：

```bash
-v ${KDE_PATH}:${KDE_PATH}                          # workspace，容器內外絕對路徑一致
-v openclaw-<workspace>-home:/home/node              # 整個容器 home（named volume → ${KDE_PATH}/.openclaw-home）
-v ${KDE_CLI_PATH}:/usr/local/lib/kde:ro             # kde CLI，與主機同版（唯讀）
-v /var/run/docker.sock:/var/run/docker.sock:ro      # DooD；`:ro` 只限制掛載點本身不能被改寫或卸載，
                                                      # 不限制透過 socket 可下達的 Docker API 呼叫，
                                                      # 見下方「風險說明」
-v ${KDE_CLI_PATH}/.claude/skills/<skill>:/home/node/.agents/skills/<skill>:ro
                                                      # CLI 自帶的每個 skill 各一個（掃 */SKILL.md 得出，
                                                      # 目前只有 kde-usage），見下方「CLI 自帶 skill 的自動載入」
```

另外帶入三個環境變數：`PUID` / `PGID`（見下方「PUID / PGID」）與 `KDE_PATH`
（讓容器內的 `kde` 不依賴 cwd，見下方「agent 的 cwd 與 `KDE_PATH`」）。

容器 home 整個對應到 `${KDE_PATH}/.openclaw-home`，所以 agent 在 home 底下的任何狀態都隨 workspace 一起搬移 / 清除。

> 早期設計曾另外掛載 `~/.config/openclaw`，並在實作階段以假金鑰經 `openclaw config set` 與 `openclaw onboard --non-interactive` 實測後移除。事後查官方文件才發現那個路徑確實有用途（legacy OAuth 憑證的加密金鑰），只是那兩條測試路徑都走不到它——這正是改為整個 home 掛載的動機之一：不必逐個猜哪些路徑有用。

### 為什麼 kde CLI 一定來自主機掛載

映像**刻意不內建 kde-cli**，`/usr/local/bin/kde` 只是一支 wrapper
（`dockerfiles/kde-openclaw/kde-wrapper.sh`），實際執行的是掛進來的
`/usr/local/lib/kde/kde.sh`。

這個掛載沒有開關，也不打算提供。理由不只是「版本一致比較好」：workspace 是**讀寫**
掛進容器的，容器內外的 kde 會寫同一批 state（`current.env`、`k8s.env`、
`.pipeline.env`、`kubeconfig/config`）。版本歪掉不是功能少一點，是兩邊互相寫壞對方
認得的格式。要換版本，換的是主機端那一份（`KDE_CLI_PATH`，由 `kde` 指令自身的路徑
推導），容器會跟著改變。

wrapper 而不是裸 symlink，是為了讓掛載缺席時的錯誤訊息指向真正的原因；裸 symlink
只會得到 `bash: /usr/local/bin/kde: No such file or directory`，指向 symlink 自己。

### CLI 自帶 skill 的自動載入

容器一啟動，OpenClaw 的 agent 就已經有 `kde-usage` skill，不需要手動安裝任何東西。
它不是被複製進去的，而是把 CLI 自帶的那一份唯讀掛到 OpenClaw 會掃的 skill 根目錄：

```bash
${KDE_CLI_PATH}/.claude/skills/kde-usage → /home/node/.agents/skills/kde-usage (ro)
```

**掛哪些目錄是掃出來的，不寫死名稱**：`build_openclaw_docker_args` 掃
`${KDE_CLI_PATH}/.claude/skills/*/SKILL.md`，對每個命中的目錄各加一個掛載。所以

- 資料夾改名照樣有效
- 日後在 `.claude/skills/` 新增第二個 skill，自動被帶進 OpenClaw，不必改程式碼
- `kde-usage-workspace` 那種沒有頂層 `SKILL.md` 的 skill 開發／eval 資料目錄自動排除
- 一個 `SKILL.md` 都掃不到時（例如 `local-install.sh` 哪天不再複製 `.claude`）會印警告，
  而不是靜默少一個 skill

確認方式：

```bash
kde openclaw exec "openclaw skills list" | grep kde-usage
# │ ✓ ready │ kde-usage │ Guide for Claude on how to … │ agents-skills-personal │
```

**為什麼是掛載而不是複製**：skill 內容講的是 `kde` 的旗標與流程，跟 CLI 版本強耦合。
複製一份進容器 home，CLI 一升級那份就過期，而且沒有任何機制會告知——後果是 agent 拿
過期旗標去操作叢集。掛載讓它永遠等於主機端掛進來的那份 CLI，與 kde CLI 本身只信掛載、
刻意不內建副本的理由完全相同。這也是它跟 `kde claude-skill install`（那是 `cp` 到
`~/.claude/skills/`，供主機端的 Claude Code 使用）的差別。

**為什麼是 `~/.agents/skills` 而不是 `~/.openclaw/skills`**：OpenClaw 有多個 skill 根目錄，
其中兩個是全域的（對所有 agent 可見）：

| 路徑 | source | 誰在管 |
|---|---|---|
| `~/.openclaw/skills` | `openclaw-managed` | OpenClaw 自己：`skills install --global` 的安裝目標、`update` / `uninstall` 的操作對象 |
| `~/.agents/skills` | `agents-skills-personal` | 沒有人自動管，適合外部掛入 |

把唯讀掛載點放進前者，那些 skill 管理指令碰到它就會失敗。放後者沒有衝突，而且該目錄
本身仍可寫，要放自己的 personal skill 不受影響。

實測確認過後者不會被 OpenClaw 的 skill 管理指令碰到：`openclaw skills update` 的說明是
「in the active or shared managed directory」，`openclaw skills workshop propose-update`
是「an existing **workspace** skill」——兩者的作用範圍都不含 `~/.agents/skills`。

> **但書**：`agents-skills-personal` 這個 source 只在 `OPENCLAW_STATE_DIR` 未被覆寫時
> 才載入（OpenClaw 內部的 `isDefaultStateDir()`）。`kde openclaw` 不設那個變數，所以成立；
> 哪天要設，這個掛載就會安靜失效。

**刻意的例外**——以下情況不加這個掛載：

1. **掃不到任何 `SKILL.md` 時**（連帶印出警告）。掛一個不存在的來源沒有意義：bind mount
   的來源缺席時 Docker 會自動建立它，於是主機端的 CLI 安裝目錄裡多出一個空目錄，而
   skill 依然不存在——那是把「skill 沒裝到」變成「skill 沒裝到，還汙染了安裝目錄」。
2. **`.openclaw-home` 還是空的時候**（此時不警告，這是正常的一次性狀態）。那代表
   home volume 還沒被掛載過，Docker 會在首次
   掛載時把映像的 `/home/node` 預先複製進來，而預先複製只在目錄為空時發生——先在裡面
   建掛載點會讓它整個不發生。錯過的只有「第一個一次性狀態檢查容器」，它跑完 home 就
   被填充，同一次 `run` / `onboard` 接下來真正要用的容器就都帶上掛載了。

**掛載點為什麼由主機端 `mkdir` 先建好**，而不是讓 Docker 代建：Docker 建的掛載點屬
**root**（發生在 entrypoint 降權之前），而它落在 `.openclaw-home` 裡面，而
`kde openclaw reset` 是以主機使用者 `rm -rf` 整個 `.openclaw-home`——遇到 root 所有的
中間目錄會「拒絕不符權限的操作」而刪不掉。由主機端建立則屬使用者本人，`reset` 刪得掉。

### agent 的 cwd 與 `KDE_PATH`

容器的 `--workdir` 是 workspace 根目錄，但那只決定**容器的起始 cwd**，管不到之後 `cd`
走的行程。OpenClaw agent 執行工具（bash / exec）時的 cwd 是**它自己的 workspace**——
`agents.defaults.workspace`，預設 `~/.openclaw/workspace`，也就是它放 `AGENTS.md` /
`SOUL.md` / `USER.md` / `memory/` 的家。那裡沒有 `kde.env`。

不處理的話，agent 跑 `kde` 拿到的不是「找不到 workspace」，而是一句會害它做錯事的指示：

```
kde.env 不存在，請先執行 kde init 初始化環境
```

而 `kde init` 是 `touch kde.env` + `cp -r templates/init/. ${KDE_PATH}/` + 複製整份 docs。
agent 照做就會把整套 workspace 模板灌進它自己的家目錄——那裡還有它自己的 git repo。
所以問題不只是「agent 用不了 kde」，是**它一試就會製造出一個假 workspace**。

修法是把 `KDE_PATH` 帶進容器（`-e KDE_PATH=${KDE_PATH}`）。`kde.sh` 優先採用帶入值，
只在它缺席或為空字串時才由 `$PWD` 往上找 `kde.env`，所以容器內的 `kde` 在**任何 cwd**
下都指向掛進來的那個 workspace，agent 不需要記得先 `cd`。

（同一個機制對人也開放：`kde -C <workspace> <command>` 是它的旗標形式，`-C` 優先於帶入的
`KDE_PATH`。見 [快速參考的環境變數一節](../quick-reference.md#環境變數)。）

**為什麼不改 `agents.defaults.workspace`**：把它指到 KDE workspace 確實能讓 cwd 一次對齊，
但那個目錄同時是 agent 的家——`AGENTS.md`（開頭就是 "This folder is home. Treat it that
way."）、`SOUL.md`、`IDENTITY.md`、`USER.md`、`memory/YYYY-MM-DD.md`、`BOOTSTRAP.md`，
外加它自己的 `.git`。指過去等於把這些全部倒進使用者版控的 workspace（`kde init` 的
`.gitignore` 範本沒有排除它們），而且 `<KDE_PATH>/skills` 與 `<KDE_PATH>/.agents/skills`
會變成 skill root。代價遠大於「少打一次 cd」。

`KDE_PATH` 只解決「跑 `kde` 指令」。agent 要讀寫專案原始碼（hot reload 開發的主要動作）
還是得知道實際路徑，那部分寫在 `kde-usage` skill 裡：`$KDE_PATH` 有值即代表身處容器，
專案原始碼在 `$KDE_PATH/environments/<env>/namespaces/<project>/<repo>/`。

## 風險說明

`kde openclaw` 把宿主的 Docker socket 掛進容器，容器內跑的是一個**自主運作的 AI agent**，不是人在鍵盤前操作。這代表：

- 這個 agent 對宿主的 Docker daemon 有完整控制權，等同對宿主機擁有 effective root——例如可以自行下 `docker run --privileged -v /:/host` 之類的指令直接操作宿主檔案系統，不受任何額外限制。
- workspace（`${KDE_PATH}`）以**讀寫**、且容器內外路徑相同的方式掛入，agent 在 workspace 內的任何寫入都直接反映到宿主檔案系統。
- socket 掛載上的 `:ro` 只限制容器內不能重新掛載或卸載該掛載點本身，不會限制透過這個 socket 能下達的 Docker API 呼叫；PUID/PGID 對齊解決的是掛載檔案的擁有權問題，與上述兩點風險無關，不構成防護。

掛 socket（DooD）本身是這個工具刻意選擇的設計（`kde code-server` 也是同樣做法），這裡不重新討論那個取捨；差別在於這裡的操作者是自主 agent 而非人，上述風險必須被明確認知，而不是被 `:ro` 或 PUID/PGID 這些字眼帶過。

## PUID / PGID

容器內 OpenClaw 使用者固定為 `node`（home 固定 `/home/node`，官方映像既定），只有 uid/gid 會依 `PUID`/`PGID` 變動：

- 預設取主機的 `id -u` / `id -g`
- 可用環境變數覆寫：`PUID=1500 PGID=1500 kde openclaw run`

## 初始化狀態判斷

`kde openclaw` 不是用「`.openclaw` 目錄是否存在/是否為空」來判斷初始化狀態——bind mount 會讓 Docker 自動建立不存在的 host 目錄，只要跑過任何一次 action，目錄必然存在；目錄非空也不代表可用（onboarding 中途 Ctrl-C 可能留下半成品 config）。

實際判斷方式：在一次性容器內執行 `openclaw config get gateway.mode`，值為 `local` 才算已初始化——這正是 `openclaw gateway run` 自己唯一在意的條件。

### 前置檢查：映像必須先能取得

因為初始化狀態是「跑一個容器問出來的」，映像取不到時那次讀取會得到空字串，而空字串與「真的沒初始化」長得一模一樣。所以在組任何 docker 參數之前會先確認映像可用：

- 本機已有該映像 → 直接通過，**不會** pull（那是 `upgrade` 的職責；每個 action 都打 registry 會讓離線環境不能用）
- 本機沒有 → 拉一次；拉得到就繼續
- 拉不到 → 明確報「取得映像失敗」，連同**設定來源的檔案路徑**（釘選檔或 `kde.env`），並中止

沒有這道檢查時，`OPENCLAW_IMAGE` 指到不存在的 tag 會被誤報成「OpenClaw 尚未初始化，請先 onboard」——照著跑 `onboard` 只會用同一個壞映像再失敗一次，而 `onboard -f` 甚至會覆寫掉本來好好的設定。

## 典型流程

```bash
kde openclaw onboard      # 1. 一次性初始化精靈
kde openclaw run          # 2. 背景啟動 gateway
kde openclaw dashboard    # 3. 首次用瀏覽器連 dashboard（鑄一次性的配對連結）
kde openclaw tui          # 4. 互動操作 OpenClaw agent（或 exec 進 bash 跑 kde 指令）
kde openclaw log -f       # 5. 有問題時看日誌
kde openclaw stop          # 6. 用完停止並移除容器
```

## 故障排除

### agent 回 `401 Missing bearer`，但 onboarding 的「Test AI access」明明通過

```
run error: unexpected status 401 Unauthorized: Missing bearer or basic
authentication in header, url: https://api.openai.com/v1/responses
```

若這個 workspace 是用**舊版 `kde`（尚未釘住 `--agent-name main`）**做的 onboarding，
且當時把第一個 agent 改了名字，憑證會落在一個 config roster 不認得的 agent 上。
gateway 跑的是 `main`，讀不到憑證，於是發出不帶 `Authorization` header 的請求。

確認方式（任一即可）：

```bash
kde openclaw exec "openclaw agents list"   # 只看得到 main (default)
kde openclaw exec "openclaw doctor"        # 會有下面這段
```

```
- Found 1 agent directory on disk without a matching agents.list entry.
  Examples: <你當時取的名字>
```

**解決方法**（保留 Slack 等既有設定，只重做 model 登入；憑證這次會寫進 `main`）：

```bash
docker run -it --rm -e PUID=$(id -u) -e PGID=$(id -g) \
  -v openclaw-<workspace>-home:/home/node \
  ${OPENCLAW_IMAGE} openclaw configure --section model
```

完成後 `kde openclaw restart` 讓 gateway 重讀設定。確認能聊之後，
再刪掉 `<workspace>/.openclaw-home/.openclaw/agents/<舊名字>`——在那之前那裡是 token
的唯一副本。要從頭來的話 `kde openclaw reset -f && kde openclaw onboard` 也可以，
新版精靈不會再問 agent 名字。

### `models status` 顯示 `OAuth/token status: none`

代表 provider 的憑證從未建立 —— onboarding 精靈可能只記下了 auth profile 的身分
（provider / mode / email），但沒有完成登入。注意精靈裡的「Test AI access now」通過
**不代表**憑證已落地。

先確認狀態：

```bash
kde openclaw exec "openclaw models status"
```

若 `Providers w/ OAuth/tokens` 是 0，執行登入。**登入必須有 TTY**，所以要用 `exec`
進 shell 再跑，不能把它塞進 `exec <cmd>`：

```bash
kde openclaw exec
# 進到容器後：
openclaw models auth login --provider openai --device-code
```

`--device-code` 會給一組代碼讓你在主機的瀏覽器完成授權，不需要把 OAuth callback
導回容器。非互動執行（`exec <cmd>`）會直接被擋下：

```
models auth login requires an interactive TTY. In automation, use
openclaw models auth paste-token --provider <provider> when token auth is available.
```

（若該 provider 支援 token 貼上，`openclaw models auth paste-token` 才是非互動的路徑。）

### `run` 說尚未初始化

```
❌ OpenClaw 尚未初始化 (gateway.mode 不是 local)
   請先執行：kde openclaw onboard
```

**解決方法**：先執行 `kde openclaw onboard` 完成初始化精靈，再重新 `kde openclaw run`。

這句話現在只會在**真的**讀到 `gateway.mode` 且值不是 `local` 時出現。映像取不到是另一則訊息（見下）。

### 取得映像失敗

```
↓ 本機沒有 docker.io/r82wei/kde-openclaw:5e990b9-2026.8.2-browser，嘗試拉取 ...
❌ 取得映像失敗：docker.io/r82wei/kde-openclaw:5e990b9-2026.8.2-browser
   本機沒有這個映像，registry 也拉不到
   （tag 打錯，或那是只在別台機器上 build 過、從未推上 registry 的映像）
   設定來源：<workspace>/kde.env 的 OPENCLAW_IMAGE
```

**解決方法**：照最後一行指出的檔案去改。常見成因是 `kde.env` 的 tag 打錯，或填了本機 `build.sh` 產出、從未 push 的映像。若最後一行指的是 `.openclaw-image`，那是 `downgrade` 設下的釘選（它覆蓋 `kde.env`），用 `kde openclaw upgrade` 解除。

### `exec` 說容器未運行

```
❌ 容器 openclaw-<workspace> 未在運行，請先執行：kde openclaw run
```

**解決方法**：先 `kde openclaw run` 背景啟動 gateway，確認成功後再 `kde openclaw exec`。

### `reset` 被拒絕

```
❌ 容器 openclaw-<workspace> 仍在運行，請先執行：kde openclaw stop
```

**解決方法**：先 `kde openclaw stop`，確認容器已移除後再 `kde openclaw reset`。

### gateway 啟動後健康檢查失敗

`run` 會在啟動後等待數秒並確認容器仍在 running；若容器已退出，會印出 `docker logs --tail 50 <name>` 的內容並回報失敗（不會謊報成功）。常見原因是設定不完整——回頭確認 `kde openclaw onboard` 是否真的成功完成。

### 容器內 `kde` 說 command not found

```
bash: kde: command not found
```

代表 `/usr/local/lib/kde` 這個掛載點在容器內是空的。最常見的成因是**容器啟動之後，
主機端把該目錄整個換掉了**：bind mount 綁的是 inode，目錄被 `rm -rf` 再重建之後，
運行中的容器會繼續守著那個已刪除的 inode，看到的就是一個空目錄。舊版
`local-install.sh` 重裝時正是這樣做的（現已改為只清內容、保留目錄）。

確認方式：

```bash
kde openclaw exec "ls /usr/local/lib/kde"          # 空的
kde openclaw exec "stat -c '%i %h' /usr/local/lib/kde"   # links 為 0 = 已刪除的 inode
```

**解決方法**：重建容器即可，狀態全在 `${KDE_PATH}/.openclaw-home`，不會掉設定。

```bash
kde openclaw restart
```

### 除錯指令

```bash
# 查看容器狀態
docker ps -a | grep openclaw

# 查看容器日誌
kde openclaw log
kde openclaw log -f                   # 持續查看

# 檢查掛載的 Volume
docker inspect openclaw-<workspace> | grep -A 20 Mounts
```

---

**相關文檔**：
- **[KDE-cli 概述](../overview.md)** - 完整的工具生態系統
- **[Code Server 文檔](./code-server.md)** - 另一個以容器承載工具、內建 kde-cli 的整合範例
