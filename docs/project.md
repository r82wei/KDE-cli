## 專案 (Project)

- 專案指的是遠端的 git repository 或一個位於 environments/[k8s name]/namespaces/ 底下的本地資料夾
- 每個專案都是一個 k8s namespace (Project = k8s namespace)
- 專案權限基於 git repository 對於權限的控管 (Github、Gitlab repository 的權限)
- 區分為本地專案(local directory)及遠端專案 (git remote)
  - **Loca Directoryl**: 純本地專案，適合快速測試和原型開發
  - **Git Remote**: 從遠端 Git 倉庫拉取，支援版本控制和協作
- 透過 project.env 設定專案相關定義(可進入 git 版控的共享的環境變數)
- 透過 .env 設定專案所需的環境變數(不可進入 git 版控的本地私有的環境變數)
  - 建議透過 Pipeline 階段腳本提示使用者輸入後寫入 .env
- 一鍵快速進入 K8S 節點容器或專案容器環境
