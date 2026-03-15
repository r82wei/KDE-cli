# Lima 快速開始

## 前置需求

### 安裝 Lima

**macOS（推薦使用 Homebrew）**：
```bash
brew install lima
```

**Linux**：
```bash
# 參考官方文件安裝
# https://lima-vm.io/docs/installation/
```

### 驗證安裝

```bash
limactl --version
# 輸出類似：limactl version 1.0.0
```

## 啟動第一個 Sandbox

### 1. 進入 workspace 目錄

```bash
cd /path/to/my-project
```

確保目錄下有 `kde.env`（若沒有則執行 `kde init`），或任何你想掛載進 VM 的專案目錄。

### 2. 啟動 Sandbox

```bash
kde sandbox start
```

首次啟動時會：
1. 下載 Ubuntu 24.04 雲端映像（約 600MB，僅首次）
2. 建立 VM 並配置資源（CPU/記憶體/磁碟）
3. 掛載 workspace 目錄到 VM 的 `/workspace`
4. 自動安裝 Docker、KDE-CLI、kubectl、tmux 等工具

首次啟動約需 3-5 分鐘，後續啟動約 10-30 秒。

### 3. 查看狀態

```bash
kde sandbox status
```

輸出範例：
```
名稱:     kde-sandbox-my-project
狀態:     Running
架構:     aarch64
CPU:      2
記憶體:   4 GiB
磁碟:     50 GiB
```

### 4. 進入 Sandbox

```bash
kde sandbox exec
```

進入後會自動 attach 到 tmux session，你會看到 VM 內的 shell。
workspace 已掛載在 `/workspace`：

```bash
cd /workspace
ls  # 可以看到 host 上的專案檔案
```

### 5. 在 Sandbox 內使用 KDE-CLI

```bash
cd /workspace
kde init
kde start dev-env kind
kde proj create myapp
```

### 6. 安裝 AI Agent（可選）

```bash
# Claude Code
npm install -g @anthropic-ai/claude-code

# Codex CLI
pip install codex-cli

# Gemini CLI
npm install -g @anthropic-ai/gemini-cli
```

### 7. 退出 Sandbox

```bash
# 在 tmux 中按 prefix + d（detach），或直接輸入 exit
exit
```

### 8. 停止 Sandbox

```bash
kde sandbox stop
```

停止前會自動保存 tmux session，下次啟動後可以還原。

## 常見問題

### Q: 首次啟動很慢？
A: 首次需要下載 Ubuntu 映像和安裝工具。後續啟動（已建立的 VM）約 10-30 秒。

### Q: workspace 的修改會同步嗎？
A: 是的。workspace 目錄透過 virtiofs 掛載，host 和 VM 之間的檔案修改是即時同步的。

### Q: 可以同時執行多個 Sandbox 嗎？
A: 可以。每個 workspace 對應一個獨立的 VM instance，不同 workspace 的 Sandbox 互不影響。

### Q: limactl 未安裝會怎樣？
A: KDE-CLI 會在執行 `kde sandbox` 時檢查 `limactl` 是否存在，若未安裝會顯示安裝指引。
