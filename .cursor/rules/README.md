# KDE CLI Cursor 規則說明

本目錄包含 KDE CLI 工具的 Cursor MDC 格式規則檔案，旨在幫助開發者快速了解和使用 KDE CLI 工具。

## 規則檔案說明

### 1. kde-cli-overview.mdc

- **描述**: KDE CLI 工具總覽
- **適用範圍**: 所有 .sh 檔案
- **自動應用**: 是
- **內容**: 工具概覽、主要功能模組、核心指令架構、環境變數與配置

### 2. environment-management.mdc

- **描述**: 環境管理詳細指南
- **適用範圍**: 環境管理相關腳本
- **自動應用**: 否
- **內容**: kind/k3d/外部 K8s 環境的建立、管理與操作

### 3. project-management.mdc

- **描述**: 專案管理詳細指南
- **適用範圍**: 專案管理相關腳本
- **自動應用**: 否
- **內容**: 專案建立、部署、管理與專案集合操作

### 4. cloud-proxy-tools.mdc

- **描述**: 雲端代理工具詳細指南
- **適用範圍**: 雲端代理相關腳本
- **自動應用**: 否
- **內容**: Cloudflare Tunnel、Ngrok、Telepresence 與 Port Forward

### 5. operations-tools.mdc

- **描述**: 運維工具詳細指南
- **適用範圍**: 運維工具相關腳本
- **自動應用**: 否
- **內容**: K9s、Dashboard、Exec、Load Image 等運維工具

### 6. installation-setup.mdc

- **描述**: 安裝與設定詳細指南
- **適用範圍**: 安裝與配置相關檔案
- **自動應用**: 否
- **內容**: 安裝、解除安裝、配置與初始化

### 7. quick-reference.mdc

- **描述**: 快速參考指南
- **適用範圍**: 所有 .sh 檔案
- **自動應用**: 是
- **內容**: 常用指令速查表、工作流程、環境變數參考

## 使用方式

### 在 Cursor 中使用

1. **自動應用規則**: 當您開啟 KDE 專案時，`kde-cli-overview.mdc` 和 `quick-reference.mdc` 會自動載入
2. **手動引用規則**: 在對話中使用 `@environment-management` 等來引用特定規則
3. **上下文感知**: 當您編輯特定類型的腳本時，相關規則會自動提供建議

### 規則類型說明

- **Always Apply**: 總是自動載入的規則
- **Auto Attached**: 根據檔案類型自動附加的規則
- **Agent Requested**: AI 可選擇性載入的規則
- **Manual**: 需要手動引用的規則

## 規則內容特色

### 1. 結構化資訊

- 清晰的章節組織
- 詳細的指令說明
- 實用的範例代碼

### 2. 實用性導向

- 快速參考表格
- 故障排除指南
- 最佳實踐建議

### 3. 完整性覆蓋

- 涵蓋所有主要功能
- 包含配置說明
- 提供工作流程

## 自訂規則

您可以根據專案需求自訂這些規則：

1. **修改現有規則**: 編輯對應的 .mdc 檔案
2. **新增規則**: 建立新的 .mdc 檔案
3. **調整適用範圍**: 修改 globs 設定
4. **變更自動應用**: 調整 alwaysApply 設定

## 規則格式

每個規則檔案都使用 MDC 格式：

```yaml
---
description: 規則描述
globs: ["檔案模式"]
alwaysApply: true/false
---
# 規則內容
## 章節標題
內容...
```

## 貢獻指南

如果您想改進這些規則：

1. 確保內容準確性
2. 保持格式一致性
3. 更新相關的 globs 設定
4. 測試規則的有效性

## 相關資源

- [Cursor Rules 官方文檔](https://docs.cursor.com/context/rules)
- [KDE CLI 專案文檔](../README.md)
- [KDE CLI 使用指南](../readme.usage.md)
