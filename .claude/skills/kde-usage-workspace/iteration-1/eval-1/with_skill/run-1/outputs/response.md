# 除錯 myapp 專案 Pod CrashLoopBackOff

你的 `myapp` 專案 Pod 出現 CrashLoopBackOff，以下是完整的除錯步驟，依序執行。

---

## 步驟 1：確認當前環境是否正確

```bash
kde current
```

確認輸出是 `dev-env`。如果不是，先切換：

```bash
kde use dev-env
```

---

## 步驟 2：列出 myapp 的 Pod 狀態

```bash
kde proj pod myapp
```

這會列出 `myapp` 專案 namespace 下所有 Pod，以及它們的狀態（可以看到哪個 Pod 是 CrashLoopBackOff）。

範例輸出：
```
NAME                     READY   STATUS             RESTARTS   AGE
myapp-7d6b9f8c4-xk2pq    0/1     CrashLoopBackOff   5          10m
```

記下那個 Pod 名稱（例如 `myapp-7d6b9f8c4-xk2pq`）。

---

## 步驟 3：查看 Pod 的 log

先用預設方式查看最近 100 行 log：

```bash
kde proj tail myapp
```

如果想看更多行，或是指定特定 Pod：

```bash
kde proj tail myapp myapp-7d6b9f8c4-xk2pq 200
```

> 將 `myapp-7d6b9f8c4-xk2pq` 替換成步驟 2 中看到的實際 Pod 名稱。

這是最重要的一步 — log 通常會直接告訴你 crash 的原因（例如環境變數缺少、port 衝突、程式 exception 等）。

---

## 步驟 4：進入 Pod 內部查看

如果 log 不夠清楚，直接 exec 進去 Pod 的 shell 做互動式診斷：

```bash
kde proj pod-exec myapp
```

這會讓你進入 Pod 的 shell 環境，你可以在裡面執行：

```bash
# 查看環境變數
env

# 查看檔案系統
ls /app

# 手動執行程式看錯誤
./your-entrypoint.sh

# 查看系統 log
cat /var/log/app.log
```

> 注意：CrashLoopBackOff 的 Pod 可能啟動後馬上 crash，導致 `pod-exec` 無法進入。如果遇到這個情況，請看步驟 5。

---

## 步驟 5：（選用）開啟 K9s 圖形介面做全面檢查

如果想要圖形化介面一次看所有資源（Pod、Event、ConfigMap 等）：

```bash
kde k9s
```

在 K9s 裡可以：
- 按 `l` 看 log
- 按 `s` 進入 shell
- 按 `d` 看 describe（顯示 Events，通常有 crash 原因）
- 輸入 `:events` 看 namespace 內所有 Event

---

## 完整指令總結（依序執行）

```bash
# 1. 確認環境
kde current

# 2. 切換到正確環境（如果需要）
kde use dev-env

# 3. 查看 Pod 狀態
kde proj pod myapp

# 4. 查看 log（將 <pod_name> 替換為實際 Pod 名稱）
kde proj tail myapp
# 或指定 pod 名稱與行數
kde proj tail myapp <pod_name> 200

# 5. 進入 Pod 內部
kde proj pod-exec myapp

# 6. 開啟 K9s（選用）
kde k9s
```

---

## 常見 CrashLoopBackOff 原因與對應處理

| 症狀（從 log 看到）| 可能原因 | 處理方式 |
|---|---|---|
| `Error: Cannot find module '...'` | 依賴未安裝 | 重新跑 build pipeline |
| `EADDRINUSE` / `port already in use` | port 衝突 | 檢查 service 設定 |
| `missing env variable` | 環境變數缺少 | 在 `project.env` 或 `.env` 補上 |
| `ImagePullBackOff` | image 不存在 | 執行 `kde load-image <image>` (Kind/K3D 環境) |
| 程式啟動後立即結束 | entrypoint 設定錯誤 | 查看 Dockerfile CMD/ENTRYPOINT |
