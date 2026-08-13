# 診斷 myapp 服務未啟動

## 步驟 1：確認當前環境與專案狀態

先確認 dev-env 是否為當前啟用的環境，以及 myapp 專案是否存在：

```bash
kde current
kde proj ls
```

若當前環境不是 dev-env，先切換：

```bash
kde use dev-env
```

---

## 步驟 2：列出 Pod 名稱

```bash
kde proj pod myapp
```

這會列出 myapp namespace 下的所有 pod 名稱，用來確認有哪些 pod、以及稍後指定 pod 查 log。

**注意：** `kde proj pod` 只顯示名稱，不顯示狀態。若要看 pod 狀態（Running / CrashLoopBackOff / Pending 等），請用 `kde k9s` 或 `kde headlamp`。

---

## 步驟 3：查看 Pod Log

用剛才列出的 pod 名稱查 log：

```bash
# 互動式選擇 pod
kde proj tail myapp

# 或直接指定 pod，取最後 200 行
kde proj tail myapp <pod_name> 200
```

Log 是最直接的線索，常見錯誤包括：
- 應用程式啟動失敗（設定錯誤、缺少環境變數）
- Port 綁定失敗
- 依賴服務連不到（DB、Redis 等）
- Image pull 失敗

---

## 步驟 4：用 k9s 看完整狀態（推薦）

```bash
kde k9s
```

在 k9s 中：
- 找到 myapp 的 pod，按 `d` 看 describe（**Events 區段非常重要**，會顯示 image pull 失敗、OOMKilled、liveness probe 失敗等原因）
- 按 `l` 看 log
- 按 `s` 進入 shell 互動調查
- 輸入 `:events` 查看 namespace 事件

---

## 步驟 5：進入 Pod Shell 深入調查（若需要）

```bash
# 互動式選擇 pod
kde proj pod-exec myapp

# 或指定 pod
kde proj pod-exec myapp <pod_name>
```

---

## 常見問題快速對照

| 症狀 | 可能原因 | 建議動作 |
|------|----------|----------|
| Pod 狀態 `CrashLoopBackOff` | 應用程式 crash | `kde proj tail myapp` 看 log |
| Pod 狀態 `ImagePullBackOff` | Image 找不到或拉取失敗 | 確認 image 名稱；若是本地 image，執行 `kde load-image <image>` |
| Pod 狀態 `Pending` | 資源不足或 node 問題 | `kde k9s` 看 Events |
| Pod 正常但服務無回應 | Port 設定或 Service 設定錯誤 | `kde k9s` 查 Service / Endpoints |

---

## 建議執行順序

1. `kde use dev-env`（確認環境正確）
2. `kde proj pod myapp`（確認 pod 存在）
3. `kde proj tail myapp`（看 log，通常能找到直接原因）
4. `kde k9s`（看完整狀態與 Events，特別是 describe pod 的 Events 區段）
