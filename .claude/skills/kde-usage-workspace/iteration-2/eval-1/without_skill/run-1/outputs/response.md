# KDE-CLI: 診斷 myapp 專案 CrashLoopBackOff

當前環境：`dev-env`，專案名稱：`myapp`

---

## 步驟一：列出目前的 Pod 名稱

```bash
kde proj pod myapp
```

這會列出 `myapp` namespace 下所有的 Pod 名稱，例如：

```
myapp-deployment-7d9f8b-xkj2p
```

---

## 步驟二：查看 Pod Log

拿到 Pod 名稱後，用 `tail` 指令查看最近的 log（預設最後 100 行，持續追蹤）：

```bash
kde proj tail myapp <pod-name>
```

例如：

```bash
kde proj tail myapp myapp-deployment-7d9f8b-xkj2p
```

若要看更多行（例如最後 500 行）：

```bash
kde proj tail myapp myapp-deployment-7d9f8b-xkj2p 500
```

如果不提供 Pod 名稱，KDE 會跳出互動式選單讓你選擇：

```bash
kde proj tail myapp
```

---

## 步驟三：進入 Pod 內部排查

確認 Pod 正在運行後（CrashLoopBackOff 的 Pod 可能短暫進入 Running 狀態），用 `pod-exec` 進入：

```bash
kde proj pod-exec myapp <pod-name>
```

例如：

```bash
kde proj pod-exec myapp myapp-deployment-7d9f8b-xkj2p
```

同樣，若不提供 Pod 名稱，會出現互動式選單。

KDE 會依序嘗試 `bash` 再 fallback 到 `sh`，所以不需要手動指定 shell。

---

## 完整執行流程（依序執行）

```bash
# 1. 列出 Pod 名稱
kde proj pod myapp

# 2. 查看 log（將 <pod-name> 替換為上一步看到的名稱）
kde proj tail myapp <pod-name>

# 3. 進入 Pod 排查
kde proj pod-exec myapp <pod-name>
```

或者，若想要圖形化介面一次看清楚，也可以啟動 K9s：

```bash
kde k9s
```

---

## 注意事項

- CrashLoopBackOff 的 Pod 會不斷重啟，`tail` 加上 `-f` 會持續追蹤 log，按 `Ctrl+C` 離開。
- `pod-exec` 只能在 Pod 處於 Running 狀態時使用。若 Pod 一直 crash，可以考慮暫時修改 Deployment 的 command 為 `sleep 9999` 以讓 container 保持啟動，再進去排查。
- 如果 `kde proj pod myapp` 沒有輸出任何 Pod，代表 Deployment 或 ReplicaSet 可能有問題，建議用 `kde k9s` 或 `kde headlamp` 進一步排查。
