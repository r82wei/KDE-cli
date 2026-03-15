# Lima 後端

**Lima 是 KDE Sandbox 的預設 microVM 後端，提供原生 macOS 和 Linux 支援。**

## 什麼是 Lima？

Lima（Linux virtual Machines）是一個 CNCF 專案，用於在 macOS 和 Linux 上建立和管理 Linux 虛擬機。

**官方資源**：
- 官方網站：https://lima-vm.io/
- GitHub：https://github.com/lima-vm/lima
- 文檔：https://lima-vm.io/docs/

## 為何選擇 Lima？

經分析 5 個候選方案後，Lima 是 KDE Sandbox 唯一合理的預設後端：

| 方案 | macOS 支援 | 快照 | 目錄掛載 | Docker-in-VM | CLI 自動化 |
|------|-----------|------|---------|-------------|-----------|
| **Lima** | 原生（QEMU / Virtualization.framework） | 內建 | virtiofs / 9p / reverse-sshfs | 支援 | `limactl -y` |
| Firecracker | 不支援（需 KVM） | 無內建 | 無 | 需額外設定 | 有 API |
| Cloud Hypervisor | 不支援（需 KVM） | 無內建 | 無 | 需額外設定 | 有 API |
| crosvm | 不支援（需 KVM） | 無內建 | 有限 | 需額外設定 | 有限 |
| QEMU | 支援但無管理層 | 手動 | 手動 | 需手動配置 | 手動 |

**Lima 的關鍵優勢**：
- **Apple Silicon 原生支援** - 使用 Virtualization.framework，效能優於 QEMU 模擬
- **內建快照管理** - `limactl snapshot create/apply/delete`
- **目錄掛載** - virtiofs 提供高效的 host-VM 檔案共享
- **CLI 自動化** - `--tty=false` 支援非互動式操作，適合腳本化
- **CNCF 專案** - 活躍的社群和穩定的維護

## Lima 與 KDE Sandbox 的對應關係

| KDE Sandbox 指令 | Lima CLI |
|-----------------|----------|
| `kde sandbox start` | `limactl start --name=<name> <template> --tty=false` |
| `kde sandbox stop` | `limactl stop <name>` |
| `kde sandbox exec` | `limactl shell <name> --workdir /workspace` |
| `kde sandbox exec <cmd>` | `limactl shell <name> --workdir /workspace <cmd>` |
| `kde sandbox status` | `limactl list --json` |
| `kde sandbox snapshot create <tag>` | `limactl snapshot create <name> --tag <tag>` |
| `kde sandbox snapshot list` | `limactl snapshot list <name>` |
| `kde sandbox snapshot restore <tag>` | `limactl snapshot apply <name> --tag <tag>` |

## Instance 命名規則

Lima instance 名稱格式：`kde-sandbox-<workspace_dir_name>`

例如，若 workspace 目錄為 `/Users/dev/my-project`，則 instance 名稱為 `kde-sandbox-my-project`。

## 平台自動偵測

KDE-CLI 啟動 sandbox 時會自動偵測作業系統，選擇最佳的 hypervisor 和掛載方式：

| 平台 | vmType | mountType | 說明 |
|------|--------|-----------|------|
| macOS 13+ (Ventura) | `vz` (Virtualization.framework) | `virtiofs` | 最佳效能，Apple Silicon 原生 |
| macOS 12 以下 | `qemu` | `reverse-sshfs` | QEMU 模擬，相容性優先 |
| Linux (有 KVM) | `qemu` (KVM 加速) | `virtiofs` | 近原生效能 |
| Linux (無 KVM) | `qemu` | `9p` | 純軟體模擬 |

偵測結果會在 `kde sandbox start` 時顯示：

```
建立並啟動 Sandbox 'kde-sandbox-my-project'...
  VM 類型: vz, 掛載方式: virtiofs
  CPU: 2, 記憶體: 4GiB, 磁碟: 50GiB
  掛載目錄: /path/to/workspace -> /workspace
```

## VM 模板

KDE-CLI 使用 `templates/lima/kde-sandbox.yaml` 作為 Lima VM 模板，主要配置：

- **OS**: Ubuntu 24.04 LTS
- **vmType / mountType**: 根據平台自動偵測填入
- **掛載**: workspace → `/workspace`（writable）、KDE-CLI → `/usr/local/lib/kde-cli-host`（readonly）
- **資源**: 可透過環境變數自訂 CPU / 記憶體 / 磁碟
- **Provision**: 自動安裝 Docker、KDE-CLI、kubectl、tmux + tmux-resurrect、基礎開發工具
- **Port forwarding**: 自動轉發 VM 內所有 port 到 host

## 進階用法

### 直接使用 limactl

KDE Sandbox 底層使用 `limactl`，進階使用者可以直接操作：

```bash
# 查看所有 Lima instances
limactl list

# 直接 SSH 進入 VM
limactl shell kde-sandbox-my-project

# 複製檔案
limactl copy kde-sandbox-my-project:/path/in/vm /local/path

# 刪除 instance
limactl delete kde-sandbox-my-project
```

### 自訂 VM 模板

可以複製 `templates/lima/kde-sandbox.yaml` 並修改，然後透過環境變數指定自訂模板路徑（未來功能）。

## 相關文件

- [快速開始](quick-start.md) - 從安裝到啟動的完整指南
- [配置選項](configuration.md) - 資源、掛載、port forwarding 等設定
- [快照管理](snapshot.md) - 快照的建立、列出和還原
