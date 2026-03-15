# Lima 配置選項

## 資源配置

透過環境變數調整 VM 資源，可在 `kde.env` 中設定或直接設定環境變數：

### CPU

```bash
# 預設 2 核
export KDE_SANDBOX_CPUS=4
kde sandbox start
```

### 記憶體

```bash
# 預設 4GiB
export KDE_SANDBOX_MEMORY=8GiB
kde sandbox start
```

### 磁碟

```bash
# 預設 50GiB
export KDE_SANDBOX_DISK=100GiB
kde sandbox start
```

> **注意**：資源配置僅在首次建立 VM 時生效。若需修改已建立的 VM 資源，需先刪除再重建。

### 在 kde.env 中永久設定

```bash
# kde.env
KDE_SANDBOX_CPUS=4
KDE_SANDBOX_MEMORY=8GiB
KDE_SANDBOX_DISK=100GiB
```

## 目錄掛載

Lima VM 模板預設掛載以下目錄：

| Host 路徑 | VM 路徑 | 權限 | 說明 |
|----------|---------|------|------|
| Workspace 目錄（`KDE_PATH`） | `/workspace` | 可讀寫 | 工作目錄 |
| KDE-CLI 安裝路徑 | `/usr/local/lib/kde-cli-host` | 唯讀 | KDE-CLI 程式碼 |
| `~`（home） | `~` | 可讀寫 | 使用者目錄（SSH keys 等） |

### 掛載類型

Lima 支援多種掛載類型，預設使用平台最佳選項：

- **virtiofs**（macOS 13+ / Linux 推薦） - 效能最佳
- **9p** - 跨平台相容
- **reverse-sshfs** - 相容性最好但效能較低

## Port Forwarding

VM 模板預設配置了自動 port forwarding：

```yaml
portForwards:
  - guestPortRange: [1, 65535]
    hostIP: "0.0.0.0"
```

這表示 VM 內部開啟的任何 port 都會自動轉發到 host，無需額外配置。

### 範例

```bash
# 在 VM 內啟動服務
kde sandbox exec -- python3 -m http.server 8080

# 在 host 上直接存取
curl http://localhost:8080
```

## 資料儲存路徑

Lima 的 VM 映像、快照等持久化資料儲存在 workspace 底下：

```
workspace/.sandbox/lima/
```

KDE-CLI 透過設定 `LIMA_HOME` 環境變數將 Lima 的資料目錄指向此路徑，讓每個 workspace 的 sandbox 資料完全獨立。此目錄已加入 `.gitignore`。

## VM 模板

Lima VM 模板位於 `templates/lima/kde-sandbox.yaml`。

### 模板結構

```yaml
images:          # VM 映像（Ubuntu 24.04，支援 x86_64 和 aarch64）
cpus:            # CPU 數量（使用模板變數 {{CPUS}}）
memory:          # 記憶體大小（使用模板變數 {{MEMORY}}）
disk:            # 磁碟大小（使用模板變數 {{DISK}}）
mounts:          # 目錄掛載配置
containerd:      # containerd 設定（已停用，使用 Docker）
provision:       # VM 初始化腳本（安裝工具）
portForwards:    # Port 轉發規則
hostResolver:    # DNS 解析設定
```

### Provision 腳本

VM 首次啟動時會自動執行以下安裝：

**系統層級（root）**：
1. Docker CE - 容器執行環境
2. kubectl - Kubernetes 命令列工具
3. 基礎工具 - tmux, git, curl, vim, build-essential, jq

**使用者層級**：
1. KDE-CLI - 從 host 掛載路徑安裝
2. tmux-resurrect - tmux session 保存/還原 plugin
3. tmux 配置 - 256 色、滑鼠支援、歷史記錄 50000 行

## DNS 設定

VM 使用 host resolver 進行 DNS 解析，並配置了 `host.docker.internal` 指向 host：

```yaml
hostResolver:
  enabled: true
  hosts:
    host.docker.internal: host.lima.internal
```

這讓 VM 內的容器可以透過 `host.docker.internal` 存取 host 上的服務。

## 進階配置

### 自訂 provision

若需要在 VM 中安裝額外工具，可以進入 VM 後手動安裝：

```bash
kde sandbox exec

# 在 VM 內
sudo apt-get install -y <package>
pip install <package>
npm install -g <package>
```

安裝完成後，建議建立快照保存狀態：

```bash
kde sandbox snapshot create my-custom-env
```
