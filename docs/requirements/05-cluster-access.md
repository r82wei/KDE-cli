# 05 觀察與進入叢集

回到 [總覽](README.md)。

這組命令讓使用者不必在主機安裝 `kubectl` 或任何 K8s 工具，就能觀察與操作當前環境。
全部作用於**當前環境**，並以環境的 kubeconfig 與 Docker 網路啟動對應的工具容器。

---

### UC-ACC-01 以 K9s 觀察叢集

**狀態**：✅ 已確認

> 身為開發者，我想要一個終端機介面瀏覽叢集裡的資源，以便快速查看 pod 狀態與日誌。

- **命令**：`kde k9s [-p|--port <port>] [-n|--namespace <ns>]`；`kde start` 成功後也會自動進入。
- **前置條件**：當前環境存在。
- **主要流程**：以 `K9S_IMAGE` 啟動容器，預設顯示所有 namespace。
- **替代流程**：
  - `-n`：只看指定的 namespace。
  - `-p`：把該 port 對應到主機（讓 K9s 內的 port-forward 能從主機連到）。
  - **自訂設定**：`environments/<env>/k9s/` 存在時用它，否則用 `<workspace>/k9s/`（單一環境優先於全域）。使用自訂設定時容器以主機使用者身分執行。
  - **主機已安裝 `k9s`**：直接執行主機的 `k9s`，不啟動容器。❓ 見 [Q8](09-gaps.md#待確認事項)。
  - **停用**：`ENABLE_K9S=false` 時這個命令靜默結束（結束碼 0），`kde start` 也不會進入 K9s。
- **例外流程**：未知參數顯示說明，結束碼 1；環境不存在時「請先建立 k8s 環境」，結束碼 1。
- **設計理由**：容器內 `USER` 可能是空的（例如在 OpenClaw 容器裡執行 `kde k9s`），而 K9s 需要它來決定 log 目錄，所以依序退回 `id -un` 與 uid。
- 出處：`scripts/k9s/command.sh`、`scripts/utils/k9s.sh`　測試：`test/test-k9s-user-env.sh`

---

### UC-ACC-02 – 03 Web 介面

**狀態**：✅ 已確認

> 身為開發者，我想要用瀏覽器管理叢集，以便用圖形介面檢視資源。

| | UC-ACC-02 Headlamp | UC-ACC-03 Kubernetes Dashboard |
|---|---|---|
| 命令 | `kde headlamp [-p <port>] [-d]` | `kde dashboard [-p <port>] [--insecure]` |
| 預設 port | 4466 | 8443 |
| 映像 | 寫死 `ghcr.io/headlamp-k8s/headlamp:latest`（[GAP-17](09-gaps.md#gap-17)） | `K8S_UI_DASHBOARD_IMAGE` |
| 背景執行 | `-d`，容器名稱 `headlamp-<env>`，印出網址與停止方式 | 不支援 |
| 連線方式 | HTTP | 預設 HTTPS（自動產生憑證）；`--insecure` 改用 HTTP |
| 自動開瀏覽器 | 前景模式會 | 會 |

- 開瀏覽器依序嘗試 `xdg-open`、`open`、`explorer.exe`（Linux、macOS、WSL），都沒有時印出網址。網址用偵測到的本機 IP 而不是 `localhost`。
- 例外：環境不存在時「請先啟動 k8s 環境」；Headlamp 的 `--port` 缺值或未知參數時報錯，結束碼 1。
- `--insecure` 只出現在 `dashboard` 的 usage 行，選項說明沒有列（[GAP-16](09-gaps.md#gap-16)）。
- 出處：`scripts/{headlamp,dashboard}/command.sh`、`scripts/utils/{headlamp,dashboard}.sh`

---

### UC-ACC-04 把叢集內的服務轉發到本機

**狀態**：✅ 已確認

> 身為開發者，我想要從主機直接連到叢集裡的 service 或 pod，以便用本機工具測試。

- **命令**：`kde expose [-d] [namespace] [pod|service] [名稱] [目標 port] [本機 port]`
- **前置條件**：當前環境運行中。
- **主要流程**（五個參數都有效）：啟動一個容器執行 `kubectl port-forward`，並把本機 port 對應到主機。
- **替代流程**：
  - **參數不完整或任一項無效**（namespace 不存在、資源不存在、port 不在 1–65535）：改走互動流程，依序選 namespace → 類型 → 資源 → port，再輸入本機 port。
  - `-d`：背景執行。必須是第一個參數。
- **例外流程**：環境未運行時報錯，結束碼 1。
- 轉發綁定 `0.0.0.0`，區網內其他機器也連得到。
- 參數無效時是靜默改走互動流程而不是報錯，對非互動的呼叫端會卡住，見 [NFR-02](08-non-functional.md#nfr-02-非互動可操作性)。
- 出處：`scripts/expose/command.sh`、`k8s.sh:271-295`；`docs/core/dev-tools/port-forward.md`

---

### UC-ACC-05 進入叢集節點

**狀態**：⚠️ 有落差

> 身為 DevOps，我想要進入控制節點容器，以便檢查節點層級的狀態（containerd、映像、掛載）。
>
> 身為 AI agent，我想要在節點上執行單一指令，以便不依賴 TTY。

- **命令**：`kde exec [env] [--command <cmd>]`
- **主要流程**：`docker exec -it <控制節點容器> bash`。
- **替代流程**：`--command` 以 `docker exec -i … bash -c` 執行指令，不配置 TTY。
- **例外流程**：環境不存在時報錯；`--command` 缺值時 stderr 報錯，結束碼 1。
- **契約**（程式碼註解）：指令內容的安全性由呼叫端負責，CLI 不做檢查。
- **落差**：外部 K8s 環境的「控制節點容器名稱」其實是 API server 位址，這個命令對它無法運作，見 [GAP-26](09-gaps.md#gap-26)。
- 出處：`scripts/exec/command.sh`、`k8s.sh:535-545`　測試：`test/test-exec-no-tty.sh`

---

### UC-ACC-06 把本機映像載入叢集

**狀態**：✅ 已確認

> 身為開發者，我想要讓叢集直接使用我剛在本機 build 的映像，以便不必推到 registry。

- **命令**：`kde load-image <image> [env]`
- **主要流程**：kind 用 `kind load docker-image`，k3d 用 `k3d image import`。
- **例外流程**：外部 K8s 印出「目前只支援 kind & k3d 環境」；未給映像時顯示說明，結束碼 1。
- 和 `kde stop` 一樣，類型取自當前環境（[GAP-09](09-gaps.md#gap-09)）。
- 出處：`scripts/load-image/command.sh`、`kind_load_image`、`k3d_load_image`
