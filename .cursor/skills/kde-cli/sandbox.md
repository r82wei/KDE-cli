# KDE Sandbox 指令參考

MicroVM 沙箱，透過 Lima 提供 workspace 級別的系統隔離。VM 持久化資料存放在 `workspace/.sandbox/lima/`。

## 指令

```bash
# 生命週期
kde sandbox start                          # 啟動 VM（首次會自動建立）
kde sandbox stop                           # 停止 VM（自動保存 tmux session）
kde sandbox status                         # 查看 VM 狀態（名稱、CPU、記憶體、VM 類型）
kde sandbox exec                           # 進入 VM（自動 attach tmux session "kde"）
kde sandbox exec <command>                 # 在 VM 內執行單一指令

# Port 轉發
kde sandbox expose <guest_port> [host_port] # 轉發 VM port 到 host（預設相同 port）
kde sandbox expose list                    # 列出活躍的轉發
kde sandbox expose stop <host_port>        # 停止指定轉發
kde sandbox expose stop-all                # 停止所有轉發

# 快照
kde sandbox snapshot create <tag>          # 建立快照（會暫停 VM）
kde sandbox snapshot list                  # 列出快照
kde sandbox snapshot restore <tag>         # 還原快照（會暫停 VM）
```

## 環境變數

```bash
KDE_SANDBOX_BACKEND=lima        # 後端（目前僅支援 lima）
KDE_SANDBOX_CPUS=2              # CPU 核數
KDE_SANDBOX_MEMORY=4GiB         # 記憶體
KDE_SANDBOX_DISK=50GiB          # 磁碟大小
```

## 平台偵測

啟動時自動偵測 OS 選擇 hypervisor：

| 平台 | vmType | mountType |
|------|--------|-----------|
| macOS 13+ | `vz` (Virtualization.framework) | `virtiofs` |
| macOS 12- | `qemu` | `reverse-sshfs` |
| Linux + KVM | `qemu` (KVM) | `virtiofs` |
| Linux 無 KVM | `qemu` | `9p` |

## VM 內建工具

Docker、KDE-CLI、kubectl、tmux（含 tmux-resurrect）、git、curl、vim、build-essential、jq

## 目錄結構

```
workspace/
├── .sandbox/lima/          # VM 持久化資料（❌ 不版控）
├── kde.env
└── environments/
```

VM 內掛載：
- `/workspace` ← host workspace 目錄（可讀寫）
- `/usr/local/lib/kde-cli-host` ← KDE-CLI 安裝路徑（唯讀）
- `~` ← host home 目錄（可讀寫）

## 工作流程

### AI Agent 沙箱開發

```bash
kde sandbox start
kde sandbox exec
# VM 內：
npm install -g @anthropic-ai/claude-code   # 安裝 AI agent
cd /workspace
claude                                       # 啟動 AI agent
# Ctrl-b d 離開 tmux（session 保留）
kde sandbox stop                             # tmux session 自動保存
kde sandbox start && kde sandbox exec        # 下次自動還原
```

### Sandbox 內使用 KDE-CLI

```bash
kde sandbox exec
# VM 內：
cd /workspace
kde init
kde start dev-env kind
kde proj create myapp
kde proj pipeline myapp
```

### Port 轉發

```bash
kde sandbox expose 3000                      # VM:3000 -> Host:3000
kde sandbox expose 8080 9090                 # VM:8080 -> Host:9090
kde sandbox expose list                      # 查看活躍轉發
kde sandbox expose stop 9090                 # 停止 Host:9090 轉發
kde sandbox expose stop-all                  # 停止所有轉發
```

### 快照管理

```bash
kde sandbox snapshot create baseline         # 保存基準環境
# ... 進行實驗 ...
kde sandbox snapshot restore baseline        # 回退到基準
```

## 依賴

- `limactl`：未安裝時執行 `kde sandbox` 會提示錯誤並顯示安裝指引（`brew install lima`）

## 除錯

```bash
# 查看 Lima instance 詳細資訊
LIMA_HOME=.sandbox/lima limactl list --json

# 直接操作 Lima
LIMA_HOME=.sandbox/lima limactl shell <instance-name>

# 刪除並重建
LIMA_HOME=.sandbox/lima limactl delete <instance-name>
kde sandbox start
```
