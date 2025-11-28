# Shell 腳本使用說明

### 啟動 K8S

- 關閉當前使用的 k8s 環境 (可以從 current.env 或是執行指令 `kde cur` 查詢目前使用的 k8s 環境)
  ```
  ./shell/start-k8s.sh
  ```
- 關閉指定 k8s 環境
  ```
  ./shell/start-k8s.sh [環境名稱]
  ```

### 部署專案開發環境

- 互動式選單選擇專案

  ```
  ./shell/deploy-project.sh
  ```

- 直接指定專案
  ```
  ./shell/deploy-project.sh [專案名稱]
  ```

### 查看專案部署的服務狀態

#### K9S (TUI K8S Dashboard)

```
./shell/k9s.sh
```

### 重新部署專案開發環境 (有修改 k8s yaml 或是 values.yaml 時)

- 互動式選單選擇專案

  ```
  ./shell/redeploy-project.sh
  ```

- 直接指定專案
  ```
  ./shell/redeploy-project.sh [專案名稱]
  ```

### 解除部署專案開發環境

- 互動式選單選擇專案

  ```
  ./shell/undeploy-project.sh
  ```

- 直接指定專案
  ```
  ./shell/undeploy-project.sh [專案名稱]
  ```

### 切換 K8S

- 切換當前使用的 k8s 環境 (可以從 current.env 或是執行指令 `kde cur` 查詢目前使用的 k8s 環境)
  ```
  ./shell/switch-k8s.sh
  ```
- 切換指定 k8s 環境
  ```
  ./shell/switch-k8s.sh [環境名稱]
  ```

### 關閉 K8S

- 關閉當前使用的 k8s 環境 (可以從 current.env 或是執行指令 `kde cur` 查詢目前使用的 k8s 環境)
  ```
  ./shell/stop-k8s.sh
  ```
- 關閉指定 k8s 環境
  ```
  ./shell/stop-k8s.sh [環境名稱]
  ```
