# KDE 除錯：myapp 專案 CrashLoopBackOff

## 情境摘要

- 當前環境：`dev-env`
- 問題專案：`myapp`
- 症狀：Pod 持續 CrashLoopBackOff

---

## 步驟 1：確認當前狀態

首先確認環境與專案狀態：

```bash
kde current
kde proj ls
```

---

## 步驟 2：確認目標環境

若當前環境不是 `dev-env`，先切換：

```bash
kde use dev-env
```

---

## 步驟 3：列出 myapp 的 Pod 名稱

```bash
kde proj pod myapp
```

這會列出 `myapp` 專案的所有 Pod 名稱（僅名稱，無狀態欄位）。

範例輸出：
```
myapp-deployment-6d8f9b7c4-xk9qp
myapp-deployment-6d8f9b7c4-zr2mn
```

---

## 步驟 4：查看 Pod Log

**方式 A：互動式選擇 Pod（推薦）**

```bash
kde proj tail myapp
```

執行後會出現選單讓你選擇要看哪個 Pod 的 log。

**方式 B：指定 Pod 名稱，顯示最後 200 行**

```bash
kde proj tail myapp myapp-deployment-6d8f9b7c4-xk9qp 200
```

CrashLoopBackOff 時，log 通常會顯示應用程式啟動失敗的錯誤訊息（例如設定檔缺失、連線失敗、啟動指令錯誤等）。

---

## 步驟 5：進入 Pod 互動式 Shell

**方式 A：互動式選擇 Pod**

```bash
kde proj pod-exec myapp
```

**方式 B：指定特定 Pod**

```bash
kde proj pod-exec myapp myapp-deployment-6d8f9b7c4-xk9qp
```

進入後可以執行：
```bash
ls /                          # 確認檔案結構
env                           # 查看環境變數
cat /etc/hosts                # 查看網路設定
<your-app-binary> --help      # 測試啟動指令
```

> **注意**：CrashLoopBackOff 時 Pod 可能立即重啟，`pod-exec` 可能無法成功連線。建議先用 `kde proj tail` 取得 log，再嘗試 exec。

---

## 步驟 6：使用視覺化工具取得完整全貌（強烈建議）

```bash
kde k9s
```

在 k9s 介面中：
- 按 `d` → describe Pod（查看 Events、資源限制、Volume 掛載）
- 按 `l` → 查看 log
- 按 `s` → 進入 shell
- 輸入 `:events` → 查看所有事件（CrashLoopBackOff 的根因通常在此）

```bash
kde headlamp
```

瀏覽器開啟 `http://localhost:4466`，提供完整的 K8s 視覺化介面。

---

## 完整執行順序（總結）

```bash
# 1. 確認環境
kde current

# 2. 切換至目標環境（若尚未是 dev-env）
kde use dev-env

# 3. 列出 Pod 名稱
kde proj pod myapp

# 4. 查看 log（互動式）
kde proj tail myapp

# 5. 進入 Pod shell（互動式）
kde proj pod-exec myapp

# 6. 使用 k9s 取得完整畫面（Events 尤其重要）
kde k9s
```

---

## CrashLoopBackOff 常見根因提示

| 根因 | 如何從 log/events 判斷 |
|------|----------------------|
| 應用程式啟動指令錯誤 | log 顯示 `exec: not found` 或 `permission denied` |
| 設定檔/環境變數缺失 | log 顯示 `config not found`、`env var not set` 等 |
| 連線失敗（DB/API） | log 顯示 `connection refused`、`dial tcp: ...` |
| OOMKilled（記憶體不足） | k9s events 顯示 `OOMKilled`，exit code 137 |
| Liveness probe 失敗 | k9s events 顯示 `Liveness probe failed` |
| Image pull 失敗 | k9s events 顯示 `ErrImagePull` 或 `ImagePullBackOff` |

若 image 是本地 build 的，記得用 `kde load-image <image>` 將 image 推入 Kind/K3D cluster。
