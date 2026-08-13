# 部署 staging 環境 + api-service 專案

你已經有 `/home/maxime/workspace/kde.env`，所以不需要執行 `kde init`。以下是完整的操作步驟：

## 步驟 1：進入工作區目錄

```bash
cd /home/maxime/workspace
```

所有 `kde` 指令都需要在工作區目錄（含有 `kde.env` 的目錄）下執行。

---

## 步驟 2：確認目前狀態

先確認現有環境，確保 staging 尚未存在：

```bash
kde list
```

---

## 步驟 3：建立 staging Kind 環境

```bash
kde start staging kind
```

這個指令會：
- 建立一個名為 `staging` 的 Kind 叢集
- 在 `environments/staging/` 下建立環境目錄與 `k8s.env`
- 自動將 `staging` 設為當前使用的環境

等待叢集啟動完成（通常需要 1-2 分鐘）。

---

## 步驟 4：確認環境已啟動並切換到 staging

```bash
kde current
```

如果 `current` 顯示的不是 `staging`，手動切換：

```bash
kde use staging
```

---

## 步驟 5：建立 api-service 專案

```bash
kde proj create api-service
```

這個指令會：
- 在 `environments/staging/namespaces/api-service/` 建立專案目錄
- 在 K8s 叢集內建立對應的 namespace
- 產生初始 `project.env`、`build.sh`、`deploy.sh`、`undeploy.sh` 範本

---

## 步驟 6：從 Git 抓取程式碼

```bash
kde proj fetch api-service https://github.com/myorg/api-service.git main
```

這個指令會：
- Clone `https://github.com/myorg/api-service.git` 的 `main` branch
- 將 repo 放置在 `environments/staging/namespaces/api-service/api-service/`
- 更新 `project.env` 中的 `GIT_REPO_URL` 與 `GIT_REPO_BRANCH`

---

## 步驟 7：部署 api-service

```bash
kde proj deploy api-service
```

這個指令會執行 `project.env` 中設定的 pipeline stages（通常包含 build、deploy 等步驟），每個 stage 在獨立的 Docker 容器中執行。

---

## 步驟 8：確認部署結果

查看 Pod 狀態：

```bash
kde proj pod api-service
```

查看 Pod 日誌：

```bash
kde proj tail api-service
```

---

## 完整指令摘要（依序執行）

```bash
cd /home/maxime/workspace
kde list
kde start staging kind
kde use staging
kde proj create api-service
kde proj fetch api-service https://github.com/myorg/api-service.git main
kde proj deploy api-service
kde proj pod api-service
kde proj tail api-service
```

---

## 注意事項

- **`kde start staging kind`** 需要 Docker 正在運行。
- 如果 `project.env` 中有 `MANUAL_ONLY` 的 stage，需額外加上 `--manual` 才會執行：
  ```bash
  kde proj deploy api-service --manual
  ```
- 若 pipeline 失敗，可以用 `--from <stage>` 從指定步驟重新開始：
  ```bash
  kde proj deploy api-service --from build
  ```
- 若需要將本地 Docker image 載入 Kind 叢集，使用：
  ```bash
  kde load-image <image_name> staging
  ```
