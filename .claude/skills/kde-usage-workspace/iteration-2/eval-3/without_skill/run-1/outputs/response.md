# 排查 myapp 服務無法啟動

你好，我來幫你排查 `myapp` 在 `dev-env` 環境中無法啟動的問題。以下是我建議的排查步驟與使用的 KDE-CLI 指令。

---

## 第一步：確認目前使用的環境

先確認你正在使用 `dev-env` 環境：

```bash
kde use dev-env
```

---

## 第二步：列出 myapp 的 Pod 狀態

```bash
kde proj pod myapp
```

這會列出 `myapp` namespace 下所有的 Pod 名稱與狀態。重點觀察：

- Pod 是否存在？如果沒有任何 pod，表示部署可能根本沒有成功建立資源。
- Pod 的狀態是什麼？常見問題狀態：
  - `CrashLoopBackOff` — 容器反覆崩潰，通常是應用程式本身錯誤或設定問題
  - `ImagePullBackOff` / `ErrImagePull` — 拉取 Docker image 失敗，可能是 image 名稱錯誤或沒有 pull 權限
  - `Pending` — Pod 卡在排程階段，可能是資源不足（CPU/Memory）或 node 有問題
  - `OOMKilled` — 記憶體不足被 kill
  - `Error` — 啟動時發生錯誤

---

## 第三步：查看 Pod 日誌

取得 pod 名稱後，查看日誌（預設最後 100 行）：

```bash
kde proj tail myapp
```

這會讓你選擇要查看哪個 pod，然後輸出日誌。日誌通常是最直接的線索，能告訴你：

- 應用程式啟動失敗的錯誤訊息（例如 config 讀取失敗、port 衝突、DB 連線失敗）
- 程式的 stack trace 或 panic 訊息

如果想看更多行：

```bash
kde proj tail myapp <pod-name> 500
```

---

## 第四步：進入 Pod 做進一步診斷（選擇性）

如果日誌不夠清楚，可以直接進入 pod 的 shell：

```bash
kde proj pod-exec myapp
```

在 pod 內可以：

- 檢查環境變數：`env | grep -i app`
- 測試網路連線：`curl http://localhost:<port>/health`
- 查看設定檔是否正確掛載

---

## 第五步：使用 K9s 取得完整的 Kubernetes 事件與資訊

如果以上步驟還不夠，`k9s` 提供更完整的 K8s 視覺化介面：

```bash
kde k9s
```

在 k9s 裡可以：

- 按 `:events` 查看 Kubernetes 事件（`Events`），這是排查 pod 無法啟動的關鍵，會顯示例如 image pull 失敗、liveness probe 失敗、OOM 等系統層級事件
- 導航到 `myapp` namespace，直接看 pod 狀態、describe pod、查看 log
- 查看 Deployment / ReplicaSet 的 rollout 狀態

---

## 常見問題快速對照表

| 症狀 | 可能原因 | 建議行動 |
|------|---------|---------|
| `CrashLoopBackOff` | 應用啟動失敗 | `kde proj tail myapp` 看錯誤訊息 |
| `ImagePullBackOff` | Image 拉不下來 | 確認 image 名稱與 registry 設定 |
| `Pending` 超過數分鐘 | 資源不足或 node 問題 | k9s 看 Events |
| Pod 存在但服務無回應 | Liveness/Readiness probe 失敗 | 進 pod 確認服務有在監聽正確 port |
| Pod 不存在 | 部署根本沒成功 | 檢查 pipeline 執行結果、deploy.sh |

---

## 建議排查順序總結

```bash
# 1. 確認環境
kde use dev-env

# 2. 看 pod 狀態
kde proj pod myapp

# 3. 看 log（最重要！）
kde proj tail myapp

# 4. 需要時進入 pod 診斷
kde proj pod-exec myapp

# 5. 需要完整 K8s 視角時
kde k9s
```

請先執行 `kde proj pod myapp` 和 `kde proj tail myapp`，把輸出結果告訴我，我可以進一步幫你分析問題所在。
