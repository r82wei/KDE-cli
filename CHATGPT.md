# KDE-cli Shell Scripts Overview

KDE-cli 是用於建立與管理 Kubernetes 本地開發環境的指令集。以下概要說明專案內各 `.sh` 檔案的功能，方便 ChatGPT 在回答相關問題時參考。

## 1. 核心腳本

| 檔案 | 位置 | 說明 |
| --- | --- | --- |
| `kde.sh` | 根目錄 | 主要執行入口。設定環境變數並依照輸入指令呼叫 `scripts/` 內的子指令。 |
| `install.sh` | 根目錄 | 將 `kde.sh` 與 `scripts/` 安裝到 `/usr/local/lib/kde`，並建立 `kde` 執行檔連結。 |
| `uninstall.sh` | 根目錄 | 移除安裝的檔案與連結。 |
| `test.sh` | 根目錄 | 載入環境並提供各種測試或除錯範例指令。 |

## 2. 子指令 (scripts/)

`scripts/` 目錄內每個資料夾都對應一個子指令，`command.sh` 為其實作。常見指令如下：

| 指令資料夾 | 主要功能 |
| --- | --- |
| `start` / `stop` / `restart` | 建立、停止或重新啟動 K8s 環境。依環境類型呼叫 `utils/environment/` 內的函式。 |
| `status` | 列出所有環境並顯示目前狀態。 |
| `use` | 切換或建立預設環境。 |
| `exec` | 進入 K8s 節點容器。 |
| `load-image` | 將 Docker image 載入 kind 或 k3d 環境。 |
| `project` | 管理單一專案 (namespace)。涵蓋建立、部署、執行等。 |
| `projects` | 管理多專案集合。 |
| `dashboard` | 啟動 Kubernetes Dashboard Web UI。 |
| `k9s` | 啟動終端機版 K9s 儀表板。 |
| `expose` | 使用 port-forward 將 Pod 或 Service 映射到本機。 |
| `ngrok` | 透過 Ngrok 對外公開服務。 |
| `cloudflare-tunnel` | 以 Cloudflare Tunnel 公開服務。 |
| `telepresence` | 啟動 Telepresence 連線，取代或攔截遠端 Pod 流量。 |
| `remove` / `reset` | 刪除或重置環境。 |

## 3. 共用工具 (scripts/utils)

- **environment/**：
  - `k8s.sh`：環境檢查與通用操作，例如切換環境、執行指令、Port 轉發等。
  - `kind.sh`、`k3d.sh`：分別處理 kind 與 k3d 的安裝、啟動及 image 載入。
  - 其他 `*-install-default-services.sh`：啟動環境時安裝必要的預設服務 (local-path storage、ingress-nginx)。
- **project.sh**、**projects.sh**：專案與專案集合的 CRUD、Git 下載、部署流程等。
- **ngrok.sh**、**cloudflare.sh**：使用容器方式啟動 ngrok 或 cloudflared 並建立連線。
- **k9s.sh**、**dashboard.sh**：啟動 k9s 或 Web Dashboard 的輔助函式。
- **telepresence.sh**：建立 telepresence session、攔截 workload 等相關操作。

## 4. 其他腳本

`dockerfiles/` 內的 `build.sh`、`run.sh` 等提供建構各種輔助 Docker image 的範例；`test/` 目錄則包含示範測試腳本。

以上簡述可協助 ChatGPT 對 KDE-cli 專案的 shell 腳本有基本認識，方便在需要時定位指令來源或理解其作用。
