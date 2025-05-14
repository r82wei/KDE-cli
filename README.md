# KDE-cli

針對 Kubernetes 本地開發與部署流程優化的命令列工具，支援開發者與 DevOps 團隊快速建構、管理與部署多個專案。它整合 Kind、K3d、CI/CD 腳本、Docker 映像、Volume 掛載、服務對外公開及 K9S Dashboard 支援，協助你無痛打造「接近實際雲端」的本地開發環境。

### 🔑 主要功能特色

- ⚙️ `建立與管理 K8s 環境`：透過 Kind / K3d 快速建立本地 Kubernetes 環境，或加入既有叢集，集中管理所有開發用環境。

- 📦 `專案快速部署`：從 Git 倉庫加入專案，並指定 Build-time / Deploy-time 使用的 Docker Image。

- 🚀 `一鍵 CI/CD`：透過 build.sh / deploy.sh 定義 CI/CD 流程，搭配 kde project deploy 部署指令快速觸發建置與部署。

- 🔄 `可逆部署流程`：透過 undeploy.sh 定義解除部署流程，搭配 kde project undeploy 指令自動清除部署資源。

- 🖥️ `原始碼熱更新支援`：將本機 Repo 資料夾以 Persistent Volume 掛載至本地 K8s，配合 HMR / nodemon 等機制支援即時開發。

- 🌐 `多種服務公開方式`：可透過本地 Port 映射、Ngrok 或 Cloudflare Tunnel 對外公開服務。

- 📊 `整合 K9s Dashboard`：內建啟動 K9s 功能，方便開發者在 IDE 即時監控 Pod 狀態、日誌與資源配置，強化除錯體驗。

- ⚡ `安裝簡易、零依賴`：使用 Shell Script 撰寫，不需額外安裝語言執行環境，僅需安裝 Docker 即可運行。

- 🛠️ `IaC 化環境管理`：所有環境設定、部署流程、專案資料皆可版本化管理，透過 Git 儲存與還原。

# 安裝說明

- 安裝 Docker
- Clone 專案並且執行 `install.sh` (需要有系統管理員權限)
  ```
  git clone https://github.com/r82wei/KDE-cli.git && \
  cd KDE-cli && \
  sudo ./install.sh && \
  cd .. && \
  rm -rf KDE-cli
  ```

# 使用說明

### 啟動環境

- `kde start [k8s name]` 啟動 K8S

### 新增專案

- `kde project create [project name]` 新增專案
  - DEVELOP_IMAGE: 開發環境/Build code 使用的 docker image
  - DEPLOY_IMAGE: CD 部署環境時使用的 docker image
  - 會在 environment/[k8s name]/namespaces/[project name]/ 底下新增 build.sh、deploy.sh

### CI/CD

🚀 自動部署

- `kde project deploy [project name]` 執行時，如果下列 shell 存在，會依序執行下列 shell
  - `build.sh`: 建置腳本，在透過 DEVELOP_IMAGE 啟動的 container 內執行的 shell script，通常用來 build code 或是安裝關聯套件。
  - `pre-deploy.sh`: 部署前置作業腳本，在透過 DEPLOY_IMAGE 啟動的 container 內執行的 shell script，可用來 build docker image 或是初始化資料庫等作業
  - `deploy.sh`: 部署腳本，在透過 DEPLOY_IMAGE 啟動的 container 內執行的 shell script，可用 helm、kubectl、docker compose、docker 等指令來部署或啟動服務
  - `post-deploy.sh`: 部署後置作業腳本，在透過 DEPLOY_IMAGE 啟動的 container 內執行的 shell script，可用來

🔄 解除部署

- `kde project undeploy [project name]` 執行時，會執行 `undeploy.sh`，否則預設刪除與 `[project name]` 同名的 k8s namespace
  - `undeploy.sh`: 解除部署腳本，在透過 DEPLOY_IMAGE 啟動的 container 內執行的 shell script，可用 helm、kubectl、docker compose、docker 等指令來解除部署或關閉服務
  - 如果 `undeploy.sh` 不存在：kubectl delete ns [project name]

### Dashboard

- `kde k9s` 啟動 K9S Dashboard

### 服務公開

- `kde expose` 透過本地 port 公開服務
- `kde ngrok <target>` 透過 ngrok 公開服務
- `kde cloudflare-tunnel <domain> <target>` 透過 Cloudflare Tunnel 公開服務

### 解除部署

- 執行 `kde project undeploy [project name]` 解除部署

### 查看當前使用的環境名稱

- 執行 `kde current` 查看目前使用的 K8S 名稱

### 切換環境

- 執行 `kde use [k8s name]` 切換目前使用的 K8S 環境

### 停止環境

- 執行 `kde stop [k8s name]` 停止 K8S

### 查看所有環境狀態

- 執行 `kde status` 查看所有 K8S 環境狀態

## 相關套件

- [k3d](https://k3d.io/stable/)
- [kind](https://kind.sigs.k8s.io/)
- [k9s](https://k9scli.io/)
- [rancher/local-path-provisioner](https://github.com/rancher/local-path-provisioner)
