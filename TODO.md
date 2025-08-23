# TODO

#### Core Features

- [ ] 實作 github action，當 release 的時候，自動 build image (kde-cli、code-server)
- [ ] 實作 watch dir 自動 deploy 機制
- [ ] dockerfile 改成 distroless image
- [x] 版本機制
- [ ] 新增 docs 指令，產生 AI agent 可以看的文件，讓 workspace 可以透過 AI agent 產生部署相關指令以及邊開發邊測試
- [ ] 從現有的 project 開新分支環境 (git worktree)
- [x] ls (列出 k8s 環境)
- [x] start/create (啟動/新增 k8s 環境)
  - [x] kind (使用 kind 啟動 K8S)
    - [x] 需要可以指定自訂的 kind-config.yaml
  - [x] k3d (使用 k3d 啟動 K8S)
    - [x] 需要可以指定自訂的 k3d-config.yaml
  - [ ] terraform
  - [x] k8s (加入現有的 K8S 環境)
- [x] stop (停止 k8s 環境)
- [x] restart (重啟 k8s 環境)
- [x] status (顯示 k8s 環境狀態)
- [x] remove (移除 k8s 環境)
- [x] current (顯示當前環境名稱)
- [x] use (切換使用環境)
- [x] load-image (將 docker image load 到 k8s node)
- [x] k9s (啟動 k9s Dashboard)
- [x] expose (將 Pod/Service 暴露到外網)
- [x] exec (進入 k8s control-plane node container)
- [x] reset (重置環境，刪除所有資料)
- [x] project (相當於 namespace)
  - [x] ls (列出 namespaces 資料夾底下的資料夾)
  - [x] create (將 project 資料夾建立到 namespaces 資料夾底下，並且在 k8s 中建立 namespace)
  - [x] fetch (輸入 git url 抓取專案)
  - [x] pull (透過 project.env 內的設定重新抓取專案 repo)
  - [x] link (建立專案資料夾的 softlink 到 namespace 資料夾底下)
  - [x] deploy (部署專案)
  - [x] undeploy (解除部署專案)
  - [x] redeploy (重新部署專案)
  - [x] tail (查看 pod 的 log，預設查看最後 100 行)
  - [x] remove (刪除專案)
  - [x] exec (進入專案的 Container 環境)
    - [x] develop (進入專案的開發 Container 環境)
      - [x] --port (需要支援 bind port)
    - [x] deploy (進入專案的部署 Container 環境)
      - [x] --port (需要支援 bind port)
- [x] projects (project 的集合)
  - [x] fetch (輸入 git url，抓取一個 project 集合)
  - [x] pull (一次性 pull project 集合內全部 project.env 設定的 git repo)
  - [x] link (建立 project 集合資料夾的 softlink 成為 namespaces 資料夾)
  - [x] exec (進入預設部署環境，並且掛載 namespaces 資料夾)
- [x] ngrok (透過 Ngrok 設定對外網址)
- [x] cloudflare-tunnel (透過 Cloudflare Tunnel 設定對外網址)
- [x] dashboard (啟動 Web UI 管理後台介面)

#### Extra Features

- [x] ngrok
- [x] Cloudflare Tunnel
- [ ] mcp server
- [ ] GKE by terraform
- [ ] AKS by terraform
- [ ] EKS by terraform
- [ ] LKE by terraform

#### KDE CLI 互動式指令，需要修改成不互動也可以直接帶參數，並且在 .cursor/rules/ 說明原本選項要怎麼查詢

##### 1. 環境管理相關

- kde start <env_name> - 如果未提供環境名稱，會詢問：
  - 請輸入環境名稱
- 環境初始化時會詢問：
  - 請輸入 K8S api server port (預設: 6443)
  - 請輸入 K8S ingress nginx port (預設: 80)
- kde start <env_name> k8s - 外部 K8s 環境會詢問：
  - 請輸入 kubeconfig 路徑

##### 2. 專案管理相關

- kde project create <project_name> - 會詢問：
  - Is this project a git repo? (y/n)
  - 請輸入專案開發(建置)環境 Image
  - 請輸入專案部署環境 Image
- kde project fetch <project_name> - 會詢問：
  - 請輸入 git repo HTTPS URL
  - 請輸入分支名稱(default: main)
- kde project link <project_name> - 會詢問：
  - 請輸入資料夾路徑
- kde project ingress <project_name> - 會詢問：
  - 請輸入 ingress 的 domain

##### 3. 端口轉發相關

- kde expose - 互動式選擇會詢問：
  - 輸入選項編號 (選擇 Service/Pod)
  - 請輸入本地 port

##### 4. 其他互動式功能

- 專案存在時的確認：
  - 專案已存在，是否要刪除？(y/n)
