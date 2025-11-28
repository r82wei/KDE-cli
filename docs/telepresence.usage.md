# 透過 [Telepresence](https://telepresence.io/docs/quick-start) 擷取遠端 K8S Pod 流量到容器開發環境進行開發

### 適合場景：

- 難以重複建立的 k8s 環境 (e.g. 建立成本過高、環境設定過於複雜費時)
- 只有在特定環境才會發生問題的使用情境

### ⚠️ 不推薦直接代理正式環境的服務

## 使用說明

1. 首次執行時，Telepresence 會在指定 K8S 的 ambassador namespace 啟動 traffic-manager 代理程式，控制 Pod 的流量。
   - 如果是 k8s 是離線環境，需要確保 traffic-manager 的 image 存在， Telepresence 使用的 image 及版本可以查看 `kde.env` 內的 `TELEPRESENCE_IMAGE` 設定。
2. kde-cli 會在本地啟動 `容器開發環境`，並且將目標 Pod 的環境變數注入，`容器開發環境` 內的程式也可以連線到原本 Pod 可以連線到的服務，例如:資料庫、k8s service...等等，就像把 Pod 的環境搬移到 `容器開發環境` 內一樣。
3. kde-cli 會自動把`專案資料夾 (source code)`掛載進入本地 container 內，開發者可以使用 hot reload 模式啟動服務，就可以達到即時開發即時測試的效果。

## 開始使用

- 連線指令

  ```
  kde telepresence replace [namespace] [deployment]
  ```

## Troubleshooting

### 1. 斷線後無法重新連線

#### 執行下列步驟後，再重新連線

1. 關閉本地環境與 k8s 的連線

   ```
   kde telepresence clear
   ```

2. 停止代理狀態，讓 Pod 恢復原狀

   ```
   kde telepresence uninstall
   ```

### 2. 如果環境變數設定成多行模式，可能會造成本地環境啟動失敗
