# 自訂 CI/CD 腳本功能測試指南

本文檔說明如何測試新增的自訂 CI/CD 腳本功能。

## 測試環境準備

1. 確保 KDE 環境已啟動：
   ```bash
   kde start test-env kind
   ```

2. 建立測試專案：
   ```bash
   kde project create test-custom-scripts
   # 選擇 "n" (不使用 git remote repo)
   # DEVELOP_IMAGE: node:20
   # DEPLOY_IMAGE: r82wei/deploy-env:1.0.0
   ```

## 測試案例

### 測試 1: 基本功能測試 - 自訂 build 腳本

**目的**：驗證自訂腳本能被正確執行

**步驟**：

1. 進入專案目錄：
   ```bash
   cd environments/test-env/namespaces/test-custom-scripts/
   ```

2. 建立自訂 build 腳本：
   ```bash
   cat > build-custom.sh << 'EOF'
   #!/bin/bash
   echo "=== 執行自訂 build 腳本 ==="
   echo "這是 build-custom.sh"
   EOF
   chmod +x build-custom.sh
   ```

3. 在 project.env 中設定使用自訂腳本：
   ```bash
   echo "KDE_PROJECT_BUILD_SCRIPT=build-custom.sh" >> project.env
   ```

4. 執行 build：
   ```bash
   kde project build test-custom-scripts
   ```

**預期結果**：
- 應該看到輸出 "=== 執行自訂 build 腳本 ==="
- 應該看到輸出 "這是 build-custom.sh"

---

### 測試 2: 向後相容性測試

**目的**：確保未設定環境變數時，使用標準腳本

**步驟**：

1. 確保 project.env 中沒有 `KDE_PROJECT_BUILD_SCRIPT` 設定

2. 編輯標準 build.sh：
   ```bash
   cat > build.sh << 'EOF'
   #!/bin/bash
   echo "=== 執行標準 build.sh ==="
   EOF
   chmod +x build.sh
   ```

3. 執行 build：
   ```bash
   kde project build test-custom-scripts
   ```

**預期結果**：
- 應該看到輸出 "=== 執行標準 build.sh ==="
- 不應該執行 build-custom.sh

---

### 測試 3: 警告機制測試

**目的**：驗證同時存在標準腳本和自訂腳本時顯示警告

**步驟**：

1. 確保 build.sh 和 build-custom.sh 都存在

2. 在 project.env 中設定：
   ```bash
   echo "KDE_PROJECT_BUILD_SCRIPT=build-custom.sh" >> project.env
   ```

3. 執行 build：
   ```bash
   kde project build test-custom-scripts
   ```

**預期結果**：
- 應該看到警告訊息：
  ```
  ⚠️  警告：檢測到同時存在 build.sh 和 build-custom.sh
      將使用 project.env 中指定的: build-custom.sh
      如果這不是預期行為，請移除 project.env 中的相關環境變數設定
  ```
- 執行的應該是 build-custom.sh

---

### 測試 4: 錯誤處理測試

**目的**：驗證自訂腳本不存在時回退到標準腳本

**步驟**：

1. 在 project.env 中設定不存在的腳本：
   ```bash
   echo "KDE_PROJECT_BUILD_SCRIPT=build-nonexistent.sh" >> project.env
   ```

2. 確保 build.sh 存在

3. 執行 build：
   ```bash
   kde project build test-custom-scripts
   ```

**預期結果**：
- 應該看到錯誤訊息：
  ```
  ❌ 錯誤：自訂腳本 build-nonexistent.sh 不存在
      將回退到使用標準腳本: build.sh
  ```
- 執行的應該是 build.sh

---

### 測試 5: 所有 CI/CD 階段測試

**目的**：驗證所有 7 個階段都支援自訂腳本

**步驟**：

1. 建立所有自訂腳本：
   ```bash
   for script in pre-build build post-build pre-deploy deploy post-deploy undeploy; do
     cat > ${script}-custom.sh << EOF
   #!/bin/bash
   echo "=== 執行自訂 ${script} 腳本 ==="
   EOF
     chmod +x ${script}-custom.sh
   done
   ```

2. 在 project.env 中設定所有自訂腳本：
   ```bash
   cat >> project.env << 'EOF'
   KDE_PROJECT_PRE_BUILD_SCRIPT=pre-build-custom.sh
   KDE_PROJECT_BUILD_SCRIPT=build-custom.sh
   KDE_PROJECT_POST_BUILD_SCRIPT=post-build-custom.sh
   KDE_PROJECT_PRE_DEPLOY_SCRIPT=pre-deploy-custom.sh
   KDE_PROJECT_DEPLOY_SCRIPT=deploy-custom.sh
   KDE_PROJECT_POST_DEPLOY_SCRIPT=post-deploy-custom.sh
   KDE_PROJECT_UNDEPLOY_SCRIPT=undeploy-custom.sh
   EOF
   ```

3. 執行完整部署流程：
   ```bash
   kde project deploy test-custom-scripts
   ```

**預期結果**：
- 應該依序看到所有自訂腳本的輸出：
  - "=== 執行自訂 pre-build 腳本 ==="
  - "=== 執行自訂 build 腳本 ==="
  - "=== 執行自訂 post-build 腳本 ==="
  - "=== 執行自訂 pre-deploy 腳本 ==="
  - "=== 執行自訂 deploy 腳本 ==="
  - "=== 執行自訂 post-deploy 腳本 ==="

4. 測試 undeploy：
   ```bash
   kde project undeploy test-custom-scripts
   ```

**預期結果**：
- 應該看到輸出 "=== 執行自訂 undeploy 腳本 ==="

---

### 測試 6: 環境變數替換測試

**目的**：驗證可以使用環境變數來動態指定腳本

**步驟**：

1. 在 project.env 中設定：
   ```bash
   cat >> project.env << 'EOF'
   BUILD_ENV=production
   KDE_PROJECT_BUILD_SCRIPT=build-${BUILD_ENV}.sh
   EOF
   ```

2. 建立對應的腳本：
   ```bash
   cat > build-production.sh << 'EOF'
   #!/bin/bash
   echo "=== 執行生產環境 build ==="
   EOF
   chmod +x build-production.sh
   ```

3. 執行 build：
   ```bash
   kde project build test-custom-scripts
   ```

**預期結果**：
- 應該看到輸出 "=== 執行生產環境 build ==="

---

### 測試 7: .env 覆寫測試

**目的**：驗證可以在 .env 中覆寫自訂腳本設定

**步驟**：

1. 在 project.env 中設定：
   ```bash
   echo "KDE_PROJECT_BUILD_SCRIPT=build-production.sh" >> project.env
   ```

2. 在 .env 中覆寫：
   ```bash
   echo "KDE_PROJECT_BUILD_SCRIPT=build-debug.sh" >> .env
   ```

3. 建立 debug 腳本：
   ```bash
   cat > build-debug.sh << 'EOF'
   #!/bin/bash
   echo "=== 執行 DEBUG build ==="
   EOF
   chmod +x build-debug.sh
   ```

4. 執行 build：
   ```bash
   kde project build test-custom-scripts
   ```

**預期結果**：
- 應該看到輸出 "=== 執行 DEBUG build ==="
- .env 的設定應該覆寫 project.env 的設定

---

## 測試結果記錄

執行完所有測試後，請填寫以下表格：

| 測試案例 | 狀態 | 備註 |
|---------|------|------|
| 測試 1: 基本功能 | ⬜ 通過 / ⬜ 失敗 | |
| 測試 2: 向後相容性 | ⬜ 通過 / ⬜ 失敗 | |
| 測試 3: 警告機制 | ⬜ 通過 / ⬜ 失敗 | |
| 測試 4: 錯誤處理 | ⬜ 通過 / ⬜ 失敗 | |
| 測試 5: 所有階段 | ⬜ 通過 / ⬜ 失敗 | |
| 測試 6: 環境變數替換 | ⬜ 通過 / ⬜ 失敗 | |
| 測試 7: .env 覆寫 | ⬜ 通過 / ⬜ 失敗 | |

## 清理測試環境

測試完成後，清理測試專案：

```bash
kde project remove test-custom-scripts
```

## 已知限制

1. 環境變數替換需要在 `source project.env` 時進行，確保變數已經被展開
2. 自訂腳本路徑必須相對於專案目錄
3. 自訂腳本必須有執行權限

## 疑難排解

如果遇到問題：

1. 檢查腳本是否有執行權限：`ls -la *.sh`
2. 檢查 project.env 中的環境變數設定：`cat project.env | grep KDE_PROJECT`
3. 檢查 .env 中是否有覆寫設定：`cat .env | grep KDE_PROJECT`
4. 啟用 debug 模式：在 kde.env 中設定 `KDE_DEBUG=true`

