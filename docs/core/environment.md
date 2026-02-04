# 環境 (Container、Kubernetes)

- 環境指的是 Container 及 K8S 環境，包含:
  - 本地 K8S
    - kind
    - k3d
  - 雲端 K8S
    - EKS
    - GKE
    - LKE
    - AKS
  - 地端自建 K8S (On-premises)
  - 本地開發容器(project.env DEVELOP_IMAGE container)
- 透過 kubeconfig 連結 K8S 環境 (存放於 workspace 內的 environments/[環境名稱]/kubeconfig/config)
- K8S 環境權限基於 K8S RBAC (kubeconfig)
- 環境狀態有三個階段：存在 -> 初始化 -> 運行

  - **存在 (Exist)**: 環境目錄已建立，k8s.env 檔案存在
  - **初始化 (Init)**: kubeconfig 已產生，環境可被使用
  - **運行 (Running)**: 全部 K8S 節點處於 Ready 狀態，可正常使用

- 透過 environment/[環境名稱] 底下的 k8s.env 設定環境相關定義(可進入 git 版控的共享的環境變數)
- 透過 environment/[環境名稱] 底下的 .env 設定環境相關定義(不可進入 git 版控的本地私有的環境變數)
- 本地 K8S (kind、k3d)

  - 建立
    - 透過 Docker 啟動 kind(Kubernetes in Docker)，快速啟動 Kubernetes/K3S 環境
    - 透過 Docker 啟動 k3d(K3S in Docker)，快速啟動 Kubernetes/K3S 環境
    - 透過 environment/[環境名稱]/init.sh，可以在 kind/k3d 啟動後執行對應的動作，例如：安裝 ingress、grafana、prometheus、...等等
    - 可指定自訂的 kind-config.yaml/k3d-config.yaml 作為 template yaml
      - **kind-config.template.yaml 機制**：
        - 將自訂 kind 配置檔案放置於 `environments/<env_name>/kind-config.template.yaml`
        - 或執行 `kde start <env_name> kind <config_path>` 自動複製為模板
        - 系統會使用模板生成最終的 `kind-config.yaml`，支援環境變數替換
        - 自訂模板可加入版控，生成的配置檔案建議加入 .gitignore
      - **k3d-config.template.yaml 機制**：
        - 將自訂 k3d 配置檔案放置於 `environments/<env_name>/k3d-config.template.yaml`
        - 或執行 `kde start <env_name> k3d <config_path>` 自動複製為模板
        - 系統會使用模板生成最終的 `k3d-config.yaml`，支援環境變數替換
        - 自訂模板可加入版控，生成的配置檔案建議加入 .gitignore
  - local k8s(kind、k3d) 內每個 pvc 名稱都會對應到 project 資料夾底下的一個與 pvc 同名的資料夾 or 檔案
  - 開發
    - 透過 rancher 的 local-path-provisioner，將 environment/[環境名稱] 底下的 namespaces 資料夾掛載到 local-path-provisioner 的 hostPath (/opt/local-path-provisioner)，讓使用者可以透過在 namespace 底下建立 pvc，連結到與 pvc 相同名稱的檔案或資料夾，進而達到 Pod 內的資源同步，進行 hot reload 開發

- 遠端 K8S (kind 及 k3d 以外的 K8S)

  - 建立
    - 透過 Terraform 或 Ansible 建立 Kubernetes，然後透過 kubeconfig 連結 Kubernetes
  - 開發
    - 使用者可以透過 telepresence 攔截 Pod 流量，並且連接到本地的容器開發環境，讓使用者可以透過本地的容器開發環境即時開發。

- 本地開發容器(DEVELOP_IMAGE container)
  - 建立
    - 透過 project.env 設定的 DEVELOP_IMAGE 啟動 container
  - 開發
    - 自動把 project 資料夾掛載進入 container 讓使用者可以快速啟動開發環境，並且載入 project.env 跟 [專案資料夾]/.env 的環境變數


