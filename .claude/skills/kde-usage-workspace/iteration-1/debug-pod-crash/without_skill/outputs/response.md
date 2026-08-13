# 除錯 myapp 專案 Pod CrashLoopBackOff

你的 `myapp` 專案 Pod 出現 CrashLoopBackOff，以下是排查步驟與對應的 `kde` 指令。

---

## 前置確認：切換到正確環境

確保目前使用的是 `dev-env` 環境（若你已在正確環境，可跳過）：

```bash
kde use dev-env
```

---

## 步驟一：列出 Pod，確認狀態

先列出 `myapp` 專案下所有的 Pod，確認哪個 Pod 正在 CrashLoopBackOff：

```bash
kde proj pod myapp
```

這會輸出 `myapp` namespace 下所有 Pod 名稱，例如：

```
myapp-deployment-7d4f9b8c6-xk2p9
```

---

## 步驟二：查看 Pod Log

使用 `tail` 指令查看 Pod 的日誌，找出 crash 原因：

```bash
kde proj tail myapp
```

執行後 KDE 會列出 Pod 讓你選擇（互動式選單），選擇 CrashLoopBackOff 的那個 Pod。

若你已知 Pod 名稱（從步驟一取得），可直接帶入：

```bash
kde proj tail myapp myapp-deployment-7d4f9b8c6-xk2p9
```

預設會顯示最後 100 行並持續追蹤（`-f`）。若想看更多行數，可加第四個參數：

```bash
kde proj tail myapp myapp-deployment-7d4f9b8c6-xk2p9 200
```

---

## 步驟三：進入 Pod 內部排查

若 log 不夠清楚，想直接進入 Pod 的 shell 排查環境、設定、檔案：

```bash
kde proj pod-exec myapp
```

同樣會彈出互動式選單讓你選擇 Pod。若 Pod 持續 crash 無法進入（容器啟動後立刻退出），請先嘗試從 log 分析根本原因。

若 Pod 正在運行（例如是間歇性 crash），直接指定 Pod 名稱進入：

```bash
kde proj pod-exec myapp myapp-deployment-7d4f9b8c6-xk2p9
```

KDE 會自動嘗試 `bash`，若不存在則 fallback 到 `sh`。

---

## 步驟四（選用）：進入開發容器排查

如果你想在專案的 **開發環境容器**（而非 K8s Pod）中排查，例如重現 build 問題：

```bash
kde proj exec myapp dev
```

---

## 完整指令摘要

| 目的 | 指令 |
|------|------|
| 確認使用 dev-env 環境 | `kde use dev-env` |
| 列出 myapp 所有 Pod | `kde proj pod myapp` |
| 查看 Pod Log（互動選擇） | `kde proj tail myapp` |
| 查看 Pod Log（指定 Pod） | `kde proj tail myapp <pod-name>` |
| 進入 Pod Shell（互動選擇） | `kde proj pod-exec myapp` |
| 進入 Pod Shell（指定 Pod） | `kde proj pod-exec myapp <pod-name>` |
| 進入開發容器 | `kde proj exec myapp dev` |

---

## 注意事項

- CrashLoopBackOff 表示容器反覆啟動後退出，Pod 可能在你嘗試 `pod-exec` 時剛好不在 Running 狀態，建議**先看 log**確認 crash 原因（例如：缺少環境變數、設定錯誤、port 衝突、健康檢查失敗等）。
- 若 Pod 一直重啟無法進入，可考慮在 `project.env` 裡暫時修改 entrypoint 或加入 `sleep` 指令，讓容器保持存活以便進入排查。
