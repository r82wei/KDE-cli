## Script 驅動的 CI/CD 部署流程

- 透過 pre-build.sh、build.sh、post-build.sh、pre-deploy.sh、deploy.sh、post-deploy.sh、undeploy.sh 模擬 CI/CD 觸發或執行
- 可以僅作為觸發事件執行專案內原有的 CI/CD 腳本，也可以直接在流程腳本內實作實際執行的步驟
- 每個 CICD 腳本可以在 project.env 自訂 Docker image ，啟動各自自定義的執行環境
- 透過 project.env 設定 CICD 執行需要的環境變數
- 本地與 CI 執行的流程應盡可能一致。
- 可讀性、可除錯性
