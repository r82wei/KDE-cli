# 快照管理

**透過快照保存和還原 Sandbox VM 的完整狀態。**

## 核心概念

快照會保存 VM 在特定時間點的完整狀態，包括：
- 磁碟內容（已安裝的套件、設定檔、資料等）
- 系統狀態

快照不包含掛載的 host 目錄（`/workspace`）內容，因為那些檔案在 host 上。

## 指令

### 建立快照

```bash
kde sandbox snapshot create <tag>
```

- 建立前會自動停止 VM（Lima 要求 VM 處於停止狀態）
- 建立完成後自動重新啟動 VM
- `<tag>` 是快照的標識名稱，建議使用描述性名稱

```bash
# 範例
kde sandbox snapshot create initial-setup
kde sandbox snapshot create after-install-claude
kde sandbox snapshot create dev-milestone-1
```

### 列出快照

```bash
kde sandbox snapshot list
```

### 還原快照

```bash
kde sandbox snapshot restore <tag>
```

- 還原前會自動停止 VM
- 還原完成後自動重新啟動 VM
- 還原會覆蓋 VM 當前的磁碟狀態

```bash
# 範例
kde sandbox snapshot restore initial-setup
```

## 使用場景

### 環境基線

在 VM 初始化完成、安裝好所有工具後建立基線快照：

```bash
kde sandbox start
kde sandbox exec
# 安裝 AI agent、自訂工具等
npm install -g @anthropic-ai/claude-code
pip install codex-cli
exit

kde sandbox snapshot create baseline
```

日後若 VM 環境損壞，可以快速還原：

```bash
kde sandbox snapshot restore baseline
```

### 實驗性變更

進行可能影響系統的操作前建立快照：

```bash
kde sandbox snapshot create before-experiment
kde sandbox exec
# 進行實驗性操作 ...
```

若實驗失敗，還原快照：

```bash
kde sandbox snapshot restore before-experiment
```

### 多配置切換

為不同開發場景建立不同的快照：

```bash
kde sandbox snapshot create python-env    # Python 開發環境
kde sandbox snapshot create node-env      # Node.js 開發環境
kde sandbox snapshot create rust-env      # Rust 開發環境

# 切換到 Python 環境
kde sandbox snapshot restore python-env
```

## 注意事項

- 快照會佔用磁碟空間，建議定期清理不需要的快照
- 快照儲存在 `workspace/.sandbox/lima/` 目錄下
- 快照不包含 `/workspace` 掛載目錄的內容（那些是 host 上的檔案）
- 建立和還原快照需要暫時停止 VM，操作完成後會自動重啟
