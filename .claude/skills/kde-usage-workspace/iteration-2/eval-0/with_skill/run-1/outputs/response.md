# KDE-CLI: 建立 staging 環境並部署 api-service 專案

以下是在 `/home/maxime/workspace` 工作目錄下（已有 `kde.env`）建立 `staging` Kind 環境並部署 `api-service` 專案所需執行的所有指令，按順序說明。

---

## 步驟 0：確認目前狀態

在開始之前，先確認目前的環境狀態：

```bash
kde current
kde proj ls
```

- `kde current`：確認目前啟用的是哪個環境（可能尚未設定任何環境）
- `kde proj ls`：列出目前環境下已有的專案

---

## 步驟 1：建立並啟動 staging Kind 環境

```bash
kde start staging kind
```

**說明：**
- `kde start` 會自動判斷環境是否存在。若不存在，則建立再啟動；若已存在，直接啟動。
- `staging` 是環境名稱
- `kind` 是叢集類型（使用 Kind 在本機模擬 Kubernetes 叢集）
- 這個指令會在 `workspace/environments/staging/` 下產生 `k8s.env`、`kubeconfig/config` 等檔案，並自動設定為 active 環境

---

## 步驟 2：建立 api-service 專案

```bash
kde proj create api-service
```

**說明：**
- 這是互動式指令，會詢問以下資訊：
  - Git 倉庫 URL（例如：`https://github.com/your-org/api-service.git`）
  - 使用的 Docker image（例如：`node:20`）
  - 其他初始設定
- 完成後會在 `workspace/environments/staging/namespaces/api-service/` 下產生：
  - `project.env`（管線設定與專案變數）
  - `build.sh`（建置腳本）
  - `deploy.sh`（部署腳本）
  - 並自動 clone git 倉庫（不需要額外執行 `kde proj fetch`）

> **注意：** 如果是互動式環境，依照提示填入 Git URL 與 image 資訊即可。

---

## 步驟 3：（選用）確認並調整 project.env 設定

建立完專案後，建議先確認管線設定是否符合需求：

```bash
# 查看 project.env（路徑在 workspace/environments/staging/namespaces/api-service/project.env）
```

典型的 `project.env` 設定範例：

```bash
KDE_PIPELINE_STAGES="build,deploy"

KDE_PIPELINE_STAGE_build_IMAGE=node:20
KDE_PIPELINE_STAGE_build_SCRIPT=build.sh

KDE_PIPELINE_STAGE_deploy_IMAGE=bitnami/kubectl:latest
KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh
```

如有需要可直接編輯 `build.sh` 和 `deploy.sh`，再進行部署。

---

## 步驟 4：部署 api-service 專案

```bash
kde proj deploy api-service
```

**說明：**
- `kde proj deploy` 是 `kde proj pipeline` 的別名
- 這會依序執行 `project.env` 中 `KDE_PIPELINE_STAGES` 定義的所有管線階段
- 每個階段在獨立的 Docker 容器中執行，完成後容器自動移除
- 若某個 stage 失敗，管線會停止並回報錯誤（除非設定了 `_ALLOW_FAILURE=true`）

---

## 完整指令摘要（依序執行）

```bash
# 1. 確認目前狀態
kde current
kde proj ls

# 2. 建立並啟動 staging Kind 環境
kde start staging kind

# 3. 建立 api-service 專案（互動式）
kde proj create api-service

# 4. 部署專案（執行完整管線）
kde proj deploy api-service
```

---

## 部署後：確認服務狀態

部署完成後，可使用以下指令確認服務是否正常運行：

```bash
# 列出 api-service 的 pod
kde proj pod api-service

# 查看 pod 日誌
kde proj tail api-service

# 使用終端介面全面查看叢集狀態
kde k9s
```

若 pod 沒有正常啟動（例如 `CrashLoopBackOff`），從 `kde proj tail api-service` 查看日誌開始排查，再搭配 `kde k9s` 查看 Events 區段。

---

## 常見問題提醒

- 若使用 Kind 並需要讓叢集存取本機 Docker image，需先執行：`kde load-image <image_name>`
- 若需要切換環境，執行：`kde use staging`
- 管線 stage 名稱中的連字號（`-`）在變數名稱中須改為底線（`_`），例如：`api-service` → `KDE_PIPELINE_STAGE_api_service_*`
