# Claude Code Skill 安裝工具

**將 KDE-CLI 的 Claude Code 操作技能安裝到個人開發環境，讓 AI 助手了解如何正確操作 kde 指令。**

---

## 說明

`kde claude-skill` 是一個輔助工具，用於將 KDE-CLI 附帶的 Claude Code skill 安裝到使用者的個人目錄（`~/.claude/skills/`），讓 Claude Code 能夠：

- 了解 `kde` 指令的完整語法和工作流程
- 在 KDE workspace 環境下正確引導使用者操作
- 區分不同情境的最佳做法（如 hot reload vs redeploy）

> **這個指令是給「主機端的 Claude Code」用的。** `kde openclaw` 容器內的 agent 不需要它——
> 那邊是把 CLI 自帶的同一份 skill 唯讀掛進容器（`~/.agents/skills/kde-usage`），
> 一啟動就有、且不會隨 CLI 升級而過期。詳見
> [OpenClaw 文件的「CLI 自帶 skill 的自動載入」](./openclaw.md#cli-自帶-skill-的自動載入)。

**為什麼需要手動安裝？**

KDE-CLI 是一個 CLI 工具，使用者會在 workspace 或專案子目錄中操作，無法預設將 skill 放置在 workspace 或專案目錄內（那樣每個 workspace 都要安裝一份）。因此 skill 需要安裝在個人全域目錄，只需安裝一次即可在所有 KDE workspace 中生效。

---

## 安裝步驟

### 1. 安裝 KDE-CLI

```bash
source ./local-install.sh
```

### 2. 安裝 Claude Code Skill

```bash
kde claude-skill install
```

安裝完成後重新啟動 Claude Code 即可使用。

---

## 指令說明

```bash
kde claude-skill install    # 安裝 skill 到 ~/.claude/skills/kde-usage/
kde claude-skill update     # 更新到最新版本（覆蓋安裝）
kde claude-skill status     # 確認目前安裝狀態
```

此指令**不需要** KDE workspace（kde.env）即可執行，可在任何目錄下操作。

---

## Skill 內容

安裝後，Claude Code 在 KDE workspace 環境下將能正確處理：

| 情境 | Claude 的行為 |
|------|-------------|
| 建立環境與專案 | `kde start` → `kde proj create`（互動式，含 git clone） |
| 日常開發（hot reload） | 說明 volume mount + watcher 自動生效，不建議 redeploy |
| 部署與 Redeploy | 正確使用 `kde proj deploy` / `kde proj redeploy` |
| 服務異常除錯 | `kde proj pod` → `kde proj tail` → `kde k9s` / `kde headlamp` |
| Pipeline 控制 | 正確使用 `--from` / `--to` / `--only` flags |

---

## 更新 Skill

當 KDE-CLI 升級包含 skill 更新時，重新安裝即可：

```bash
kde claude-skill update
```
