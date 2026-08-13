# KDE-CLI 操作回應：建立 staging 環境與 api-service 專案

## 重要說明

本次對話中 **Bash 工具的執行權限被拒絕**，因此無法直接代為執行指令。以下是根據 KDE-CLI 原始碼分析所得出的完整、正確操作步驟，請使用者在終端機中依序執行。

---

## 前置條件

你的 `/home/maxime/workspace/kde.env` 已存在，因此 KDE 會自動以 `/home/maxime/workspace` 作為 workspace 根目錄（`kde` 指令會向上尋找 `kde.env`）。

請在 `/home/maxime/workspace` 目錄或其子目錄下執行所有 `kde` 指令，或使用絕對路徑確保 KDE 能找到正確的 workspace。

---

## 步驟一：建立 staging Kind 環境

```bash
cd /home/maxime/workspace
kde create staging kind
```

**說明：**
- `kde create` 會建立環境但不啟動 K9s（`kde start` 才會同時啟動 K9s）
- `staging` 是環境名稱
- `kind` 指定使用 Kind 作為 K8s 叢集類型（也是預設值）
- 指令會在 `/home/maxime/workspace/environments/staging/` 下建立環境設定，並啟動 Kind cluster

---

## 步驟二：切換到 staging 環境（如有需要）

```bash
kde use staging
```

**說明：** 若 `staging` 已是當前環境（`current.env` 記錄），可略過此步驟。

---

## 步驟三：建立 api-service 專案（互動式）

```bash
kde proj create api-service
```

**說明：** 這個指令是**互動式**的，會依序詢問：

1. **是否從 Git 遠端倉庫抓取專案程式碼？(y/n)**
   - 輸入 `n`（若你沒有 Git repo，讓工具建立本地空白目錄）
   - 輸入 `y`（若你有 Git repo，接著輸入 repo URL 與分支名稱）

2. **請輸入開發環境 Image**（例如 `node:20`、`python:3.11`）
   - 根據你的 api-service 技術選擇適當 image

3. **請輸入部署環境 Image**（預設為 `r82wei/deploy-env:1.0.0`，包含 kubectl/helm）
   - 直接按 Enter 使用預設值即可

建立完成後，KDE 會自動產生：
- `project.env`（含 Pipeline 設定）
- `build.sh`（空白，供你填寫 build 邏輯）
- `deploy.sh`（空白，供你填寫 deploy 邏輯）

---

## 步驟四：執行部署 Pipeline

```bash
kde proj deploy api-service
```

**說明：**
- 預設 Pipeline 包含 `build` 和 `deploy` 兩個階段
- `build.sh` 和 `deploy.sh` 初始為空白，若未填寫內容，Pipeline 會執行空腳本（不會出錯，但實際上不做任何事）
- 若想只執行 deploy 階段：`kde proj deploy --only deploy api-service`

---

## 完整指令序列（快速參考）

```bash
cd /home/maxime/workspace

# 1. 建立 staging Kind 環境
kde create staging kind

# 2. （若需要）切換到 staging 環境
kde use staging

# 3. 建立 api-service 專案（互動式，按提示輸入）
kde proj create api-service

# 4. 執行部署
kde proj deploy api-service
```

---

## 注意事項

- `kde proj create` 是互動式指令，無法完全自動化，必須由使用者在終端機中手動回應提示。
- 若想在 `deploy.sh` 中加入實際的 Kubernetes 部署邏輯（例如 `kubectl apply -f ...`），請在執行 `kde proj deploy` 前先編輯該檔案，位置為：
  `/home/maxime/workspace/environments/staging/namespaces/api-service/deploy.sh`
- 若 `kde` 指令找不到，請先執行 `source /path/to/KDE-cli/local-install.sh` 安裝。
