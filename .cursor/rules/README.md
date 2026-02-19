# KDE-CLI Cursor Rules 說明

本目錄包含 KDE-CLI 專案的 AI agent 指導規則，幫助 Cursor AI 更好地理解和協助 KDE-CLI 的開發與使用。

## 📚 Rules 列表

### 1. `kde-cli-core.mdc` (Always Apply)
**描述**：KDE-CLI 核心概念與最佳實踐指南

**內容**：
- 核心架構（環境、專案、Pipeline）
- 環境類型（Kind、K3D、外部 K8s）
- Pipeline 系統完整說明
- 三種開發模式（開發容器、K8s PVC、Telepresence）
- 環境變數載入順序
- 常用工作流程
- DooD 支援
- 指令速查

**觸發時機**：所有對話都會載入

---

### 2. `kde-project-config.mdc`
**描述**：KDE-CLI 專案配置與 Pipeline 腳本指南

**內容**：
- `project.env` 完整配置結構
- Pipeline 階段配置模式
- 常見語言專案配置範例（Node.js、Go、Python）
- Pipeline 腳本最佳實踐（build.sh、test.sh、deploy.sh）
- 階段間資料傳遞機制
- 檔案掛載範例
- 除錯技巧

**觸發時機**：編輯以下檔案時
- `**/project.env`
- `**/build.sh`
- `**/deploy.sh`
- `**/test.sh`
- `**/*-deploy.sh`
- `**/*-build.sh`

---

### 3. `kde-k8s-deployment.mdc`
**描述**：KDE-CLI Kubernetes 部署與 PVC 掛載最佳實踐

**內容**：
- PVC 掛載機制（local-path-provisioner）
- PVC 命名規則與資料夾對應
- 完整部署範例（Node.js、Go、Python Hot Reload）
- 部署腳本整合（kubectl、Helm）
- ConfigMap 和 Secret 管理
- Ingress 設定
- 多容器 Pod 範例
- 資源限制和健康檢查
- 常見錯誤與解決

**觸發時機**：編輯以下檔案時
- `**/k8s/**/*.yaml`
- `**/k8s/**/*.yml`
- `**/helm/**/*.yaml`
- `**/kustomization.yaml`

---

### 4. `kde-environment.mdc`
**描述**：KDE-CLI 環境管理與故障排除指南

**內容**：
- 環境配置檔案（k8s.env、.env）
- init.sh 環境初始化腳本
- Kind/K3D 配置範例
- 環境操作指令
- 環境切換機制
- 完整的故障排除指南
- 效能優化技巧
- 最佳實踐

**觸發時機**：編輯以下檔案時
- `**/k8s.env`
- `**/kind-config.yaml`
- `**/k3d-config.yaml`
- `**/init.sh`

---

## 🎯 使用指南

### 對於開發者

當你在 Cursor 中工作時，這些 rules 會自動提供給 AI agent：

1. **核心概念**始終可用（`kde-cli-core.mdc`）
2. 根據你正在編輯的檔案，相關的專門 rules 會被啟用

### 對於 AI Agent

當協助使用者時：

1. **Always Apply Rule** (`kde-cli-core.mdc`) 已經提供核心概念
2. 根據使用者開啟的檔案，讀取對應的 file-specific rules
3. 參考 rules 中的範例和最佳實踐
4. 使用 rules 中的除錯技巧幫助排查問題

---

## 📖 快速參考

### 環境管理
```bash
kde start <env> [kind|k3d|k8s]  # 建立環境
kde use <env>                    # 切換環境
kde status                       # 查看狀態
```

### 專案管理
```bash
kde proj create <name>           # 建立專案
kde proj pipeline <name>         # 執行 Pipeline
kde proj exec <name> [dev|dep]   # 進入容器
```

### Pipeline 執行
```bash
kde proj pipeline <name>                # 完整執行
kde proj pipeline <name> --only build   # 只執行特定階段
kde proj pipeline <name> --manual       # 手動模式
```

### Telepresence
```bash
kde telepresence intercept <ns> <workload>  # 攔截流量
kde telepresence list                       # 查看連線
kde telepresence clear                      # 清理連線
```

---

## 🔧 維護指南

### 更新 Rules

當 KDE-CLI 功能更新時：

1. 確認哪個 rule 需要更新
2. 更新對應的 `.mdc` 檔案
3. 保持範例程式碼的正確性
4. 更新本 README 如有必要

### Rule 檔案規範

- 檔案格式：`.mdc` (Markdown with frontmatter)
- 檔案大小：建議 < 500 行
- 內容原則：
  - ✅ 簡潔明確
  - ✅ 提供具體範例
  - ✅ 包含常見錯誤處理
  - ❌ 避免冗長說明
  - ❌ 避免重複內容

---

## 📚 相關資源

- [KDE-CLI 完整文檔](../docs/)
- [快速參考指南](../docs/core/quick-reference.md)
- [Pipeline 系統](../docs/core/cicd-pipeline.md)
- [環境管理](../docs/core/environment/)

---

## 🙋 FAQ

**Q: 為什麼需要這些 rules？**
A: 讓 AI agent 能快速理解 KDE-CLI 的核心概念、配置模式和最佳實踐，提供更準確的協助。

**Q: Rules 會影響效能嗎？**
A: 不會。Rules 只在需要時被載入，且都經過精簡設計。

**Q: 如何測試 rule 是否生效？**
A: 開啟對應的檔案類型，詢問 AI agent 關於 KDE-CLI 的問題，檢查回答是否參考了 rules 中的內容。

**Q: 可以自訂 rules 嗎？**
A: 可以。你可以在 `.cursor/rules/` 中加入自己的 rules，遵循相同的格式即可。
