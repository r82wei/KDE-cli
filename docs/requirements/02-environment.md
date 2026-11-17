# 02 環境生命週期

回到 [總覽](README.md)。

環境有三種類型，能力不同：

| 能力 | `kind` | `k3d` | `k8s`（外部） |
|---|---|---|---|
| 由 CLI 建立與銷毀叢集 | ✅ | ✅ | ❌ 只連線 |
| 專案目錄作為 PVC 儲存（hot reload） | ✅ | ✅ | ❌ |
| `load-image` | ✅ | ✅ | ❌ |
| `stop` / `restart` | ✅ | ✅ | 只印訊息 |
| 沒有 `undeploy.sh` 時的預設解除部署 | 刪除 namespace | 刪除 namespace | 拒絕執行 |
| Docker 網路 | `kde-<env>` | `kde-<env>` | `bridge` |

環境的三個狀態由檔案與叢集共同決定：

| 狀態 | 判定方式 |
|---|---|
| 存在 | `environments/<env>/` 非空且有 `k8s.env` |
| 已初始化 | 有 `kubeconfig/config` |
| 運行中 | 已初始化，且所有 node 的 Ready 狀態為 True（逾時 `K8S_NODE_READY_TIMEOUT`，預設 0.5 秒） |

---

### UC-ENV-01 決定當前環境

**狀態**：✅ 已確認

> 身為開發者，我想要在環境目錄下執行命令時自動作用於該環境，以便不必每次指定或切換。

- **觸發**：任何需要 workspace 的命令。
- **主要流程**：
  1. 若 `$PWD` 位於 `environments/<env>/` 之下，當前環境就是該 `<env>`（只影響這次執行，不改寫 `current.env`）。
  2. 否則讀取 `current.env` 的 `CUR_ENV`，並在 stderr 提示來源。
- **例外流程**：得到的環境不存在時，印出「環境不存在」，改用 `environments/` 下的第一個環境並寫回 `current.env`；一個環境都沒有時刪除 `current.env`。
- 提示訊息走 stderr 是刻意的，避免汙染以 stdout 當資料通道的命令。
- 出處：`kde.sh:251-281`、`scripts/utils/environment/k8s.sh:135-159`（commit「enhance environment detection」）

---

### UC-ENV-02 建立並啟動環境

**狀態**：✅ 已確認

> 身為開發者，我想要用一個命令得到一個可用的本機 K8s 叢集，以便立刻開始部署專案。
>
> 身為 DevOps，我想要把既有的叢集納入 workspace，以便用同一套流程部署到測試或正式環境。

- **命令**：`kde start <env> [kind|k3d|k8s] [config]`、`kde create <env> [kind|k3d|k8s] [config]`
  - `start` 在完成後進入 K9s（[UC-ACC-01](05-cluster-access.md#uc-acc-01-以-k9s-觀察叢集)），`create` 不會。
  - 類型也接受 `--kind`、`--k3d`、`--k3s`、`k3s`、`--k8s`。預設 `kind`。
  - `config` 對 kind/k3d 是自訂叢集設定檔的路徑，對 `k8s` 是 kubeconfig 的路徑。
- **主要流程**（kind / k3d，全新環境）：
  1. **建立**：建立環境目錄與 `k8s.env`，寫入環境名稱、類型、控制節點容器名稱、Docker 網路 `kde-<env>`、`STORAGE_CLASS=local-path`。有給 `config` 就複製成 `<type>-config.template.yaml`。
  2. **初始化**：建立 `.env`、`kubeconfig/`、`namespaces/`；產生自簽 CA（`pki/ca.key`、`ca.crt`，效期 10 年）；詢問 API server port（預設 6443）與 ingress port（預設 80）並寫入 `.env`。
  3. 把這個環境設為當前環境。
  4. **啟動**：以模板加環境變數重新產生叢集設定檔 → 確保 Docker 網路存在 → 在 kind/k3d 容器中建立叢集 → 把 kubeconfig 的 server 位址改寫成 `<控制節點容器名稱>:6443`。
  5. **安裝預設服務**：設定 local-path-provisioner（儲存根目錄對應到 `namespaces/`，路徑樣式 `<namespace>/<pvc>`，刪除 PVC 時**不刪資料**）、安裝 ingress-nginx（NodePort 30080/30443）。
  6. 環境目錄下有 `init.sh` 時，在部署容器中執行它。
- **替代流程**：
  - **環境已存在**：略過「建立」；`k8s.env` 記錄的類型優先於命令列參數。已有 kubeconfig 時也略過「初始化」。
  - **未給環境名稱**：用當前環境；也沒有當前環境時互動詢問（此時輸入會轉成小寫）。
  - **port 已在 `.env`**：不詢問，直接沿用。
  - **外部 K8s**：不建立叢集。取得 kubeconfig（參數、環境變數 `KUBECONFIG_PATH`，或互動詢問；支援 `~`）並複製進環境；從中解析 API server 位址記為 `K8S_CONTAINER_NAME`；Docker 網路設為 `bridge`；印出 RUNNING / UNREADY 後結束（`start` 也**不會**進入 K9s）。
- **例外流程**：

  | 情況 | 行為 |
  |---|---|
  | kind/k3d 環境已在運行 | 「環境已啟動」，結束碼 1 |
  | 指定的 config 檔不存在 | 報錯，結束碼 1 |
  | 叢集建立失敗 | 「kind/k3d 初始化失敗」，結束碼 1 |

- **設計理由**：每次啟動都重新產生設定檔，是為了讓 `k8s.env`、`.env`、模板的修改在重啟後生效；因此手動改產生出來的 `kind-config.yaml` 會被覆蓋，應該改模板（`kind.sh` 的 `start_kind`）。
- 出處：`scripts/start/command.sh`、`scripts/utils/environment/{k8s,kind,k3d}.sh`、`kind-install-default-services.sh`
- 測試：`test/test-kind-config-env.sh`（設定檔的變數渲染）

---

### UC-ENV-03 停止環境

**狀態**：⚠️ 有落差

> 身為開發者，我想要停掉不用的叢集，以便釋放機器資源。

- **命令**：`kde stop [env] [-f|--force]`
- **主要流程**（kind / k3d）：確認環境存在且運行中 → `docker stop` 再 `docker rm` 叢集容器。
- **替代流程**：`-f` 直接 `docker rm -f`。外部 K8s 只印「外部 K8S 環境請自行關閉」。
- **例外流程**：環境不存在或未運行時報錯，結束碼 1。
- **結果**：叢集容器被刪除，叢集內的資源全部消失；`namespaces/` 的檔案保留。
- **落差**：類型取自當前環境而不是指定的環境，見 [GAP-09](09-gaps.md#gap-09)。說明文字寫成 `kde k8s stop`，見 [GAP-13](09-gaps.md#gap-13)。
- 出處：`scripts/stop/command.sh`、`stop_kind`、`stop_k3d`

---

### UC-ENV-04 – 07 其他生命週期命令

| ID | 命令 | 行為 | 狀態 | 出處 |
|---|---|---|---|---|
| UC-ENV-04 | `kde restart [env] [-f]` | 確認環境存在 → `kde stop` → `kde start`（因此結束時會進入 K9s）。環境未運行時 `stop` 會失敗，`restart` 跟著中止 | ❓ [Q4](09-gaps.md#待確認事項) | `scripts/restart/command.sh` |
| UC-ENV-05 | `kde list`、`kde ls` | 列出 `environments/` 下的目錄。不需要 `kde.env` | ✅ | `kde.sh:150-157` |
| UC-ENV-06 | `kde status [json]` | 列出每個環境是 RUNNING 或 UNREADY。加 `json` 輸出 `[{"status":…,"environment":…}]` | ✅（`json` 只在 quick-reference，help 沒有） | `scripts/status/command.sh` |
| UC-ENV-07 | `kde current`、`kde cur` | 印出當前環境名稱，沒有時印「目前沒有設定任何 k8s 環境」 | ✅ | `kde.sh:318-324` |

---

### UC-ENV-08 切換當前環境

**狀態**：⚠️ 有落差

> 身為開發者，我想要切換之後的命令作用於哪個環境，以便在多個環境之間工作。
>
> 身為剛 clone 團隊 workspace 的新成員，我想要選一個環境就直接可用，以便不必了解初始化細節（推定）。

- **命令**：`kde use [env]`
- **主要流程**：把 `env` 寫入 `current.env`。
- **替代流程**：
  - 未給名稱：列出選單讓使用者選，可選「退出」。
  - **環境缺少本機檔案**（沒有 `.env` 或沒有 `kind-config.yaml`）：自動執行 `kde create <env> <類型>`，類型取自 `k8s.env`，沒有就用 `kind`。這讓 clone 下來只有版控檔的環境可以直接被建立起來。
- **例外流程**：環境不存在時報錯，結束碼 1。
- **落差**：判斷條件寫死 `kind-config.yaml`，對 k3d 與外部 K8s 環境永遠成立，見 [GAP-10](09-gaps.md#gap-10)。
- 出處：`scripts/use/command.sh`

---

### UC-ENV-09 移除環境

**狀態**：❓ 待確認

> 身為開發者，我想要刪除不再需要的環境，以便清理 workspace。

- **命令**：`kde remove <env>`、`kde rm <env>`
- **主要流程**：確認環境存在 → 刪除整個環境目錄（含所有專案）→ 把當前環境改成剩下的第一個環境。
- **例外流程**：未給名稱時顯示說明，結束碼 1。
- **注意**：沒有確認提示，也不會先停止叢集；環境若在運行，叢集容器與 Docker 網路會留在主機上。這是否為預期行為待確認，見 [Q2](09-gaps.md#待確認事項)。
- 出處：`scripts/remove/command.sh`、`k8s.sh:161-167`

---

### UC-ENV-10 重置環境

**狀態**：⚠️ 有落差

> 身為開發者，我想要把環境的叢集狀態清掉重來，但保留專案與我自訂的叢集設定，以便從乾淨的狀態重建。

- **命令**：`kde reset [env]`
- **主要流程**：
  1. 確認環境存在，詢問「確定要重置？」，回答不是 `y` 就結束。
  2. 環境運行中就先 `kde stop`。
  3. 刪除環境目錄下除了 `namespaces/` 與 `*.template.yaml` 以外的所有東西（含 `k8s.env`、`.env`、kubeconfig、PKI）。
  4. 詢問「是否要保留 namespaces？」，回答不是 `y` / `Y` 就刪除整個環境目錄（模板也一併刪除）。
- **結果**：保留 namespaces 時，環境因為沒有 `k8s.env` 而不再「存在」，需要重新 `kde start <env>` 建立；專案資料夾會被沿用。
- **落差**：頂層 help 寫的是「清除全部 environments 和 projects 資料夾」，與實際作用範圍不符；外部 K8s 文件說不支援，但程式碼沒有擋。見 [GAP-12](09-gaps.md#gap-12)、[GAP-14](09-gaps.md#gap-14)。
- 出處：`scripts/reset/command.sh`
