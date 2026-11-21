---
name: kde-cli-reviewed
description: 使用 KDE-cli 管理 Kubernetes 開發環境、專案與 script-driven CI/CD pipeline。當使用者需要執行 kde init/start/use/status、kde proj create/pipeline/deploy、kde k9s/headlamp/telepresence/expose 或排查 KDE workspace 結構與環境變數時使用。包含安全護欄（避免破壞性操作）與標準執行順序。
---

# KDE-cli（已審核來源版）

以 **README + docs + source code + Obsidian 原子筆記** 為準，協助使用者穩定操作 KDE-cli。

## 1) 先做三件事

1. 確認目前目錄是否在 workspace（是否存在 `kde.env`，或可往上找到）。
2. 先看環境狀態再動手：
   - `kde list`
   - `kde current`
   - `kde status`
3. 若是部署/刪除類操作，先確認目標環境與專案名稱，避免打錯環境。

## 2) 標準任務流程

### A. 快速建立可用開發環境（MVP）

依序執行：

```bash
kde init
kde start dev-env kind
kde proj create myapp
kde proj pipeline myapp
kde k9s
```

目標是先跑通「環境 → 專案 → 部署 → 觀測」閉環。

> 注意：`kde start` 會在流程尾端自動啟動 K9s。若在非互動或自動化場景，優先改用 `kde create <env> kind|k3d|k8s`，避免 UI/TUI 阻塞。

### B. 日常環境管理

```bash
kde list
kde use <env>
kde status
kde stop <env>
kde restart <env>
```

### C. 專案與 Pipeline

```bash
kde proj create <project>
kde proj pipeline <project>
kde proj pipeline <project> --only build
kde proj pipeline <project> --from build --to deploy
kde proj redeploy <project>
```

### D. 開發與除錯

```bash
kde proj exec <project> develop
kde proj exec <project> deploy
kde proj tail <project>
kde k9s
kde headlamp
```

## 3) 安全護欄（必要）

- 進行 `remove/rm/reset/undeploy` 前，先回報影響範圍並要求確認。
- 外部 K8s 環境執行卸載時，優先確認是否有明確 `undeploy.sh`，避免誤刪資源。
- 不主動寫入或外傳敏感資訊（token、密碼、私鑰）；敏感值放 `.env` 而非 `project.env`。
- 自動化執行時盡量帶齊參數，避免觸發 `select/read` 互動流程（例如 project/env 未帶值時會進入互動選單）。

## 4) 常見故障處理

### 問題：找不到 workspace / `kde.env`

- 移動到正確 workspace 根目錄後重試，或先 `kde init`。

### 問題：Pipeline 失敗

- 先用手動模式縮小範圍：
  - `kde proj pipeline <project> --only <stage> --manual`
- 開啟除錯：
  - `KDE_DEBUG=true kde proj pipeline <project>`
- 檢查腳本權限與檔案存在性（`*.sh`）。

### 問題：環境變數看起來沒生效

- 注意載入順序：`kde.env -> k8s.env -> .env -> project.env -> .env -> .pipeline.env`
- 後載入會覆蓋先載入的同名變數。

## 5) 回覆格式（執行任務時）

輸出請固定包含：

1. **結論**（是否完成）
2. **執行的命令**（關鍵命令）
3. **結果證據**（狀態/輸出摘要）
4. **下一步建議**（1~3 條）

## 6) 參考依據（已審核來源）

- `README.md`
- `docs/core/quick-reference.md`
- `docs/core/workspace.md`
- `docs/core/project.md`
- `docs/core/cicd-pipeline.md`
- `kde.sh`（實際指令入口與參數）
- Obsidian：
  - `KDE-cli/KDE-cli 快速上手流程.md`
  - `KDE-cli/KDE-cli 主要指令速覽.md`
