# 在 /home/maxime/workspace 建立 staging 環境並部署 api-service

以下是完整的執行步驟與指令。由於 `/home/maxime/workspace/kde.env` 已存在，因此不需要執行 `kde init`。

---

## 前提確認

`kde` 指令在執行時會從 `$PWD` 往上尋找 `kde.env`，因此所有 `kde` 指令都必須在 `/home/maxime/workspace` 目錄下執行，或者確保 `KDE_PATH` 能解析到 `/home/maxime/workspace`。

```bash
cd /home/maxime/workspace
```

---

## 步驟一：建立 staging Kind 環境

使用 `kde create` 建立一個名為 `staging` 的 Kind 環境（`create` 不會啟動 K9s，若需要 K9s 可改用 `kde start`）：

```bash
kde create staging kind
```

**說明：**
- `staging` 是環境名稱
- `kind` 指定使用 Kind 作為叢集類型（也是預設值）
- 這個指令會在 `/home/maxime/workspace/environments/staging/` 下建立環境資料夾，初始化 kubeconfig、PKI、Kind 叢集，並將 `staging` 設定為當前預設環境（寫入 `current.env`）

---

## 步驟二：建立 api-service 專案並 fetch 程式碼

使用 `kde project fetch` 建立專案目錄，並從 Git 抓取程式碼：

```bash
kde project fetch api-service https://github.com/myorg/api-service.git main
```

**說明：**
- `fetch` 指令會：
  1. 在 `/home/maxime/workspace/environments/staging/namespaces/api-service/` 建立專案資料夾
  2. 執行 `git clone --recursive -b main https://github.com/myorg/api-service.git` 將程式碼 clone 到專案目錄內
- `fetch` 不會互動式詢問 image 等設定；如果需要完整的 `project.env`（含 pipeline 設定、develop/deploy image），應改用 `kde project create`（互動式）

> **注意：** `kde project fetch` 只負責 clone repo，不會自動建立 `project.env`。若需要執行 pipeline，需先確認 `project.env` 存在於 `/home/maxime/workspace/environments/staging/namespaces/api-service/project.env`，內容至少包含：
>
> ```env
> GIT_REPO_URL=https://github.com/myorg/api-service.git
> GIT_REPO_BRANCH=main
> DEVELOP_IMAGE=<your-build-image>
> DEPLOY_IMAGE=r82wei/deploy-env:1.0.0
> KDE_PIPELINE_STAGES="build,deploy"
> KDE_PIPELINE_STAGE_build_SCRIPT=build.sh
> KDE_PIPELINE_STAGE_build_IMAGE=${DEVELOP_IMAGE}
> KDE_PIPELINE_STAGE_deploy_SCRIPT=deploy.sh
> KDE_PIPELINE_STAGE_deploy_IMAGE=${DEPLOY_IMAGE}
> ```

---

## 步驟三：執行 Pipeline 部署

```bash
kde project deploy api-service
```

**說明：**
- `deploy`（等同 `pipeline`）會讀取 `project.env` 內的 `KDE_PIPELINE_STAGES` 設定
- 每個 stage 會在獨立的 Docker 容器中執行對應的 shell script（`build.sh`、`deploy.sh` 等）
- 容器透過 DooD (Docker outside of Docker) 存取 Kind 叢集的 kubeconfig

---

## 完整指令序列

```bash
cd /home/maxime/workspace

# 1. 建立 staging Kind 環境
kde create staging kind

# 2. 建立 api-service 專案並 clone 程式碼
kde project fetch api-service https://github.com/myorg/api-service.git main

# 3. 執行 pipeline 部署
kde project deploy api-service
```

---

## 驗證環境與部署狀態

```bash
# 確認 staging 是當前環境
kde current

# 列出所有 project
kde project list

# 查看 pod 狀態（需要環境正在運行）
kde project pod api-service

# 進入 K9s dashboard 查看整體狀態
kde k9s
```

---

## 補充說明

| 指令 | 說明 |
|------|------|
| `kde create staging kind` | 建立 Kind 叢集，不啟動 K9s |
| `kde start staging kind` | 建立 Kind 叢集並自動啟動 K9s |
| `kde project fetch` | clone repo 到專案目錄（非互動式） |
| `kde project create` | 互動式建立專案（會詢問 image、是否 clone repo） |
| `kde project deploy` | 執行 pipeline（等同 `kde project pipeline`） |
| `kde project redeploy` | undeploy 後重新執行 pipeline |
