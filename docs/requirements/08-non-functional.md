# 08 非功能需求與約束

回到 [總覽](README.md)。

這裡的每一條都是從多個命令的共同做法、測試、程式碼註解或 commit 訊息歸納出來的。
「證據」欄列出最直接的出處；「遵守情形」說明程式碼是否一致地做到。

## 非功能需求

### NFR-01 主機只需要 Docker

所有工具都在容器中執行，不汙染主機，並確保每個人的工具版本一致。

- **證據**：`docs/principle.md`「容器優先」；`README`；每個工具命令都是 `docker run`。
- **遵守情形**：⚠️ 部分。CLI 本身仍在主機上直接呼叫數個非 Docker 的程式，見 [GAP-04](09-gaps.md#gap-04)。

### NFR-02 非互動可操作性

AI agent 與 CI 沒有 TTY，也不能回答提問。它們需要的每個操作都必須有不需要 TTY、不跳選單的執行方式。

- **證據**：`--no-tty`（pipeline、redeploy、tail）、`--command`（exec、proj exec、pod-exec、openclaw exec）、
  `kde status json`、`kde openclaw downgrade <編號>`；2026-04-09 至 04-13 的一系列 commit；
  `TODO.md`「互動式指令，需要修改成不互動也可以直接帶參數」。
- **規則**（已實作的部分一致遵守）：
  - 非互動模式下缺少必要參數時**報錯**，不跳選單（`tail --no-tty`、`pod-exec --command` 沒給 pod）。
  - 非互動模式下原本的確認提示自動通過並說明（pipeline 的 `PAUSE`）。
  - 需要 TTY 的功能與非互動旗標互斥並報錯（`--shell` 與 `--no-tty`）。
- **遵守情形**：⚠️ 進行中。仍只能互動操作的清單見 [GAP-20](09-gaps.md#gap-20)。

### NFR-03 stdout 是資料通道

會被管線接走的輸出，stdout 只能有資料本身；提示、警告、錯誤一律走 stderr。

- **證據**：`kde openclaw token`（`openclaw.sh:681-715`）；當前環境的提示改走 stderr（`kde.sh:268-270`）；映像釘選提示走 stderr（`openclaw.sh:895-901`）。
- **遵守情形**：只有上述幾處明確遵守。多數命令的錯誤訊息仍印到 stdout，但那些命令的 stdout 目前沒有被當成資料使用。`kde status json` 的 stdout 是否乾淨取決於前置流程的提示（已改走 stderr）。

### NFR-04 錯誤訊息要指向真正的原因

不同的失敗原因要有不同的訊息，而且訊息建議的下一步必須是對的。

- **證據**：
  - workspace 目錄不存在 vs 不是 workspace（`kde.sh:74-79`、`181-191`）。
  - OpenClaw 映像取不到 vs 尚未初始化（`openclaw.sh:244-271`、`423-446`）。
  - gateway 沒有 token 是因為認證停用還是未初始化（`openclaw.sh:700-711`）。
  - 專案不存在時列出可用的專案（`project.sh:84-94`）。
  - 背景啟動的容器若立刻掛掉，主動印出日誌而不是回報成功（`openclaw.sh:566-582`）。
- **遵守情形**：2026-07 之後的程式碼一致遵守；早期的命令多半只有一句訊息。

### NFR-05 破壞性操作要有防護

會刪除資料或影響他人的操作，需要確認、需要明確的意圖，或直接拒絕。

- **證據**：
  - 要求確認：`kde reset`、`openclaw reset` / `downgrade` / `backup`、`openclaw onboard`（已初始化時）、clone 目標已存在時。
  - 拒絕：外部 K8s 沒有 `undeploy.sh` 時不做預設刪除；有未提交修改時不 pull；容器運行中不 reset；安裝路徑為 `/`、`/usr` 等時中止安裝。
  - 不猜測：降級的備份編號無效時報錯（`openclaw.sh:1110-1114`）。
  - 先備份再覆蓋：降級前備份現況（`openclaw.sh:1136-1141`）。
- **遵守情形**：⚠️ 不一致。`kde remove`、`kde project remove`、`kde project pull --force`、Cloudflare 的 DNS 覆寫、
  Telepresence 的 `replace` 都沒有確認。見 [Q2](09-gaps.md#待確認事項)。

### NFR-06 版控設定與本機狀態分離

會隨 workspace 同步給團隊的檔案，不能被寫入只屬於某一台機器的狀態。

- **證據**：設定分層（[總覽](README.md#設定的分層)）；`OPENCLAW_PORT` 刻意不寫入 `kde.env`（`openclaw.sh:9-12`）；
  降級用 `.openclaw-image` 而不改 `kde.env`（`openclaw.sh:845-852`）；`templates/init/.gitignore`。
- **遵守情形**：大致遵守。例外是 UC-WS-06 會自動把預設映像附加到 `kde.env`，這是刻意的（把版本固定下來並同步給團隊）。

### NFR-07 可重現

同一份 workspace 在任何機器上得到相同的環境。

- **證據**：工具映像版本集中在 `kde.env`；叢集設定由模板加變數**每次啟動時重新產生**（`kind.sh` 的 `start_kind`）；
  `project.env` 進版控；`init.sh` 在每次建立叢集後執行。
- **遵守情形**：⚠️ 部分。`CODE_SERVER_IMAGE`、`OPENCLAW_IMAGE` 預設為 `latest`，Headlamp 與 ngrok 寫死 `latest`（[GAP-17](09-gaps.md#gap-17)）。

### NFR-08 不默默變更使用者沒提到的東西

使用者的指令沒有提到的屬性，不應該因為這個指令而改變；實際狀態與設定不一致時要說出來。

- **證據**：`openclaw restart` / `upgrade` 沿用現有 port（`openclaw.sh:804-843`）；沒有新版時不重啟；
  映像釘選生效時每次都說明（`openclaw.sh:890-901`）；`restart` 不順便拉新映像（`openclaw.sh:1176-1190`）。
- **遵守情形**：OpenClaw 一致遵守。其他命令沒有類似情境。

### NFR-09 離線可用

已經取得的映像不應該在每次操作時重新向 registry 查詢。

- **證據**：`ensure_openclaw_image_available` 本機有就不拉（`openclaw.sh:254-256`）；換版本是獨立的 `upgrade` 動作。
- **遵守情形**：一致（其他命令用 `docker run` 的預設行為，同樣不重拉）。代價是 `latest` 不會自動更新，這正是需要 `upgrade` 的原因。

### NFR-10 資料安全

使用者的資料在升級與還原過程中不能遺失或損壞。

- **證據**：備份一律在容器停止後進行（`openclaw.sh:973-981`、`1231-1234`）；升級前自動備份；備份有保留上限；
  同一秒內的備份不互相覆蓋（`openclaw.sh:939-945`）；local-path 儲存在刪除 PVC 時不刪資料（`kind-install-default-services.sh`）。
- 測試：`test/test-openclaw-backup.sh`

### NFR-11 冪等

重複執行同一個操作不應該失敗或產生副作用。

- **證據**：`openclaw stop` 對不存在的容器正常結束；`restart` 對未啟動的 workspace 等同 `run`；`docker volume create` 的使用方式。
- **遵守情形**：⚠️ 只有 OpenClaw 遵守。`kde stop` 對未運行的環境會失敗（因此 `kde restart` 也是）、
  `kde start` 對運行中的環境會失敗、`kde alias` 會重複附加、`kde init` 會產生巢狀目錄。見 [Q4](09-gaps.md#待確認事項)。

### NFR-12 容器產生的檔案屬於使用者

在容器中建立的檔案，在主機上的擁有者必須是使用者本人，否則使用者之後無法修改或刪除。

- **證據**：專案容器 `--user $UID:gid`；code-server `-u`；OpenClaw 的 `PUID` / `PGID` 與 `docker exec -u node`（`openclaw.sh:614-619`）；
  掛載點由主機端先建立，避免 Docker 以 root 代建（`openclaw.sh:385-391`）；kubeconfig 產生後 `chown`（`kind.sh` 的 `start_kind`）。
- 測試：`test/test-openclaw-entrypoint.sh`

### NFR-13 跨平台

Linux 為主要平台，macOS 與 WSL 可用。

- **證據**：`stat -c` 失敗時退回 `stat -f`；開瀏覽器嘗試 `xdg-open`、`open`、`explorer.exe`；本機 IP 偵測有 macOS 分支。
- **遵守情形**：⚠️ 部分。`readlink -f`、`grep -oP`、`sed` 的部分用法是 GNU 版本才有，macOS 內建的版本不支援。未實測。

### NFR-14 可測試

邏輯必須能在不啟動真實容器的情況下測試。

- **證據**：參數解析抽成獨立函式（`parse_pipeline_args`、`parse_code_server_args`、`parse_openclaw_args`、`parse_pod_exec_args`），
  以回傳碼 0 / 1 / 2 區分成功、錯誤、已顯示說明；可覆寫的鉤子（`KDE_INSTALL_LIB_DIR`、`OPENCLAW_HEALTH_WAIT`）；
  測試以 shell 函式取代 `docker`。
- **遵守情形**：2026-07 之後的命令遵守；早期命令的解析直接寫在 `command.sh` 裡，沒有測試。

## 約束

### CON-01 純 Bash，無建置步驟

CLI 只由 Bash 腳本組成，安裝就是複製檔案加一個 symlink。`kde.sh` 與 `scripts/` 全部在 `set -eo pipefail` 下執行。

- 這個約束帶來一個反覆出現的陷阱：被 `source` 的腳本裡，任何回傳非零的呼叫都會讓整個 CLI 中止。
  新的程式碼以 `|| rc=$?` 明確承接（`scripts/openclaw/command.sh:5-8`）；早期的 pipeline 程式碼沒有，後果見 [GAP-01](09-gaps.md#gap-01)。

### CON-02 容器內外路徑一致

CLI 採用 DooD（容器使用主機的 Docker daemon）。容器內發出的 `docker run -v` 是由主機的 daemon 解讀的，
所以凡是可能被再次掛載的路徑，在容器內外必須是同一個絕對路徑。

- **證據**：專案目錄、workspace（`openclaw.sh:317-318`）、K9s 設定目錄都以 `路徑:相同路徑` 掛入；`-C` 的路徑會被絕對化（`kde.sh:38-41`）。

### CON-03 叢集連線透過 Docker 網路

工具容器不是經由主機的 port 連到叢集，而是加入環境的 Docker 網路（`kde-<env>`），以控制節點的容器名稱連線。
kubeconfig 的 server 位址因此被改寫成 `<容器名稱>:6443`（`kind.sh` 的 `start_kind`）。

- 推論：這份 kubeconfig 無法直接給主機上的 `kubectl` 使用，除非主機能解析該容器名稱（未實測）。

### CON-04 重裝不得破壞運行中的容器

CLI 的安裝目錄被運行中的 code-server 與 OpenClaw 容器掛載。重裝時只能清空目錄內容，不能刪除目錄本身，
否則容器會守著已刪除的 inode，容器內的 `kde` 消失且重裝也救不回來。

- **證據**：`local-install.sh` 的註解；`restore_openclaw_backup` 對 `.openclaw-home` 的相同處理（`openclaw.sh:1063-1066`）。
- 測試：`test/test-local-install.sh`

### CON-05 專案名稱等於 namespace 名稱

專案目錄名直接被當成 K8s namespace 與 PVC 路徑的一部分使用，因此必須是合法的 namespace 名稱。CLI 不驗證。

### CON-06 語言

程式碼註解與使用者訊息使用繁體中文。變數名與部分早期訊息為英文。
目錄與變數中的 `enviroments`（`ENVIROMENTS_PATH`、`load_enviroment_env`）是既有的拼字，實際目錄名是正確的 `environments`。
