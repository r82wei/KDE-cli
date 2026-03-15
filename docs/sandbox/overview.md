# Sandbox - MicroVM 開發沙箱

**透過 microVM 提供工作區級別的系統隔離，支援多租戶開發和 AI Agent 安全沙箱。**

## 核心概念

### 什麼是 Sandbox？

Sandbox 是 KDE-CLI 提供的 microVM 隔離環境功能，以 workspace 為單位，在 host 上啟動一個輕量級虛擬機，將當前工作目錄掛載進 VM 內部。

**解決的問題**：
- **系統隔離** - 在同一台 host 上實現開發環境多租戶功能，各 workspace 互不影響
- **AI Agent 安全執行** - 讓 AI agent（Claude Code、Codex CLI、Gemini CLI 等）可以在沙箱內自由開發除錯，不影響 host 系統
- **環境一致性** - VM 內預裝 Docker、KDE-CLI、tmux 等工具，確保開發環境標準化

### 運作原理

```
┌─────────────────────────────────────────────────────────────────┐
│                         Host (macOS/Linux)                      │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  kde sandbox start                                        │ │
│  │  → 建立 microVM，掛載 workspace 到 /workspace              │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                  │
│                              ▼                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  MicroVM (Ubuntu 24.04)                                    │ │
│  │                                                            │ │
│  │  /workspace/ ←── 掛載自 host 的 workspace 目錄（可讀寫）    │ │
│  │                                                            │ │
│  │  內建工具：                                                 │ │
│  │  ├── Docker       → 容器化開發                              │ │
│  │  ├── KDE-CLI      → 完整的 K8s 開發環境管理                 │ │
│  │  ├── kubectl      → K8s 操作                               │ │
│  │  ├── tmux         → Session 管理 + 還原                     │ │
│  │  └── git, curl... → 基礎開發工具                            │ │
│  │                                                            │ │
│  │  可自行安裝：                                               │ │
│  │  ├── Claude Code  → AI 開發助手                             │ │
│  │  ├── Codex CLI    → OpenAI 開發助手                         │ │
│  │  └── Gemini CLI   → Google 開發助手                         │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 後端抽象設計

Sandbox 底層的 VM 實作可以抽換，透過 `KDE_SANDBOX_BACKEND` 環境變數選擇後端。

目前支援的後端：

| 後端 | 平台支援 | 說明 |
|------|---------|------|
| **Lima**（預設） | macOS / Linux | 原生支援 Apple Silicon，內建快照、目錄掛載 |

未來可擴展：Firecracker（Linux KVM）、QEMU 直接操作等。

每個後端實作統一的函式介面：
- `sandbox_start` / `sandbox_stop` - 啟動 / 停止 VM
- `sandbox_exec` - 進入 VM 或執行指令
- `sandbox_status` / `sandbox_is_running` - 查看狀態
- `sandbox_snapshot_create` / `sandbox_snapshot_list` / `sandbox_snapshot_restore` - 快照管理

## 指令速查

```bash
# 基本操作
kde sandbox start                    # 啟動 Sandbox microVM
kde sandbox status                   # 查看 Sandbox 狀態
kde sandbox exec                     # 進入 Sandbox（tmux session）
kde sandbox exec <command>           # 在 Sandbox 內執行指令
kde sandbox stop                     # 停止 Sandbox

# 快照管理
kde sandbox snapshot create <tag>    # 建立快照
kde sandbox snapshot list            # 列出快照
kde sandbox snapshot restore <tag>   # 還原快照
```

## 環境變數

| 環境變數 | 說明 | 預設值 |
|---------|------|--------|
| `KDE_SANDBOX_BACKEND` | 後端類型 | `lima` |
| `KDE_SANDBOX_CPUS` | CPU 數量 | `2` |
| `KDE_SANDBOX_MEMORY` | 記憶體大小 | `4GiB` |
| `KDE_SANDBOX_DISK` | 磁碟大小 | `50GiB` |

可在 `kde.env` 中設定，或透過環境變數覆蓋。

## 資料儲存

Sandbox 的 VM 持久化檔案儲存在 workspace 底下的 `.sandbox/` 目錄：

```
workspace/
├── .sandbox/
│   └── lima/          # Lima 後端的 VM 映像、快照等持久化資料
├── kde.env
└── environments/
```

- `.sandbox/` 已加入 `.gitignore`，不會被版控
- 每個 workspace 的 sandbox 資料完全獨立
- 刪除 `.sandbox/` 等同於移除該 workspace 的所有 VM 資料

## tmux Session 還原

- 進入 Sandbox 時自動 attach 到名為 `kde` 的 tmux session
- 若 session 不存在則自動建立
- 已安裝 `tmux-resurrect` plugin：
  - `prefix + Ctrl-s` → 保存 session
  - `prefix + Ctrl-r` → 還原 session
- 停止 Sandbox 前自動保存 tmux session

## 典型工作流程

### AI Agent 隔離開發

```bash
# 啟動沙箱
kde sandbox start

# 進入沙箱
kde sandbox exec

# 在沙箱內安裝 AI agent
npm install -g @anthropic-ai/claude-code
# 或 pip install codex-cli

# 使用 AI agent 開發（在隔離環境中）
claude

# 完成後退出
exit
kde sandbox stop
```

### 多租戶開發

```bash
# Workspace A
cd /path/to/project-a
kde sandbox start      # 建立 kde-sandbox-project-a

# Workspace B（另一個終端）
cd /path/to/project-b
kde sandbox start      # 建立 kde-sandbox-project-b

# 各自獨立，互不影響
```

### 快照保存開發進度

```bash
kde sandbox start
kde sandbox exec
# ... 開發工作 ...

# 保存當前狀態
kde sandbox snapshot create dev-milestone-1

# 繼續開發 ...
# 如果需要回退
kde sandbox snapshot restore dev-milestone-1
```

## 後端詳細文件

- [Lima 後端](Lima/overview.md) - 預設後端的詳細說明
