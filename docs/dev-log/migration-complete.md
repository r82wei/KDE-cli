# 函式遷移完成報告

## 遷移概述

已將所有使用 `exec_script_in_container_with_project_for_stage` 包裝函式的地方改為直接使用 `exec_script_in_container_with_project`。

## 修改的檔案

### 1. scripts/utils/pipeline.sh

#### 修改 1：手動模式（行 195）

**修改前**:
```bash
exec_script_in_container_with_project_for_stage ${PROJECT_NAME} ${STAGE} ${IMAGE} "bash"
```

**修改後**:
```bash
exec_script_in_container_with_project ${PROJECT_NAME} ${IMAGE} "bash" ${STAGE}
```

#### 修改 2：執行腳本（行 210）

**修改前**:
```bash
exec_script_in_container_with_project_for_stage ${PROJECT_NAME} ${STAGE} ${IMAGE} "${LOAD_PIPELINE_ENV}./${SCRIPT}"
```

**修改後**:
```bash
exec_script_in_container_with_project ${PROJECT_NAME} ${IMAGE} "${LOAD_PIPELINE_ENV}./${SCRIPT}" ${STAGE}
```

### 2. test/test-exec-integration.sh

#### 修改：測試案例 4

**修改前**:
```bash
# 測試 4：exec_script_in_container_with_project_for_stage 包裝函式
output=$(exec_script_in_container_with_project_for_stage "test-project" "build" "test-image" "echo test" 2>&1)
```

**修改後**:
```bash
# 測試 4：直接使用新的呼叫方式（推薦）
output=$(exec_script_in_container_with_project "test-project" "test-image" "echo test" "build" 2>&1)
```

## 參數順序對比

### 舊的包裝函式

```bash
exec_script_in_container_with_project_for_stage PROJECT_NAME STAGE IMAGE SCRIPT
#                                                 $1          $2    $3    $4
```

### 新的直接呼叫

```bash
exec_script_in_container_with_project PROJECT_NAME IMAGE SCRIPT STAGE
#                                      $1           $2    $3     $4 (可選)
```

## 測試結果

```bash
$ ./test/test-exec-integration.sh

===== exec_script_in_container_with_project 整合測試 =====

測試 1：不帶 STAGE 參數（應該只有全局掛載）
✅ 通過：只包含全局掛載

測試 2：帶 STAGE 參數 'build'（應該包含全局 + build 階段掛載）
✅ 通過：包含全局掛載 + build 階段掛載

測試 3：帶 STAGE 參數 'test'（應該包含全局 + test 階段掛載）
✅ 通過：包含全局掛載 + test 階段掛載

測試 4：直接使用新的呼叫方式（推薦）
✅ 通過：新的呼叫方式正確

測試 5：階段名稱包含連字號 'pre-build'
✅ 通過：連字號正確轉換為底線

===== 測試完成 =====
總測試數：5
通過：5
失敗：0
🎉 所有測試都通過了！
```

## 包裝函式狀態

`exec_script_in_container_with_project_for_stage` 包裝函式**仍然保留**在 `scripts/utils/environment/k8s.sh` 中，以確保：

1. **向後相容性**：如果有外部腳本或插件使用這個函式，它們仍然可以正常工作
2. **平滑過渡**：給其他開發者時間適應新的呼叫方式

### 包裝函式實作

```bash
exec_script_in_container_with_project_for_stage() {
    # 直接呼叫整合後的函式，傳入 STAGE 參數
    exec_script_in_container_with_project "$1" "$3" "$4" "$2"
}
```

## 優點

### 1. 程式碼一致性
- 所有 Pipeline 相關的程式碼現在都使用統一的函式
- 參數順序更符合邏輯（STAGE 作為可選參數放在最後）

### 2. 可讀性提升
```bash
# 新的呼叫方式更清楚地表達意圖
exec_script_in_container_with_project ${PROJECT_NAME} ${IMAGE} "${SCRIPT}" ${STAGE}
#                                      專案名稱        映像     腳本        階段(可選)
```

### 3. 維護性
- 減少了一層間接呼叫
- 更容易追蹤和除錯

## 檢查清單

- [x] 修改 `scripts/utils/pipeline.sh` 中的兩處呼叫
- [x] 更新測試檔案 `test/test-exec-integration.sh`
- [x] 執行測試驗證所有測試通過
- [x] 檢查 linter 錯誤（無錯誤）
- [x] 保留包裝函式確保向後相容
- [x] 撰寫遷移文件

## 後續建議

### 1. 文件更新
更新使用者文件和開發者指南，推薦使用新的呼叫方式。

### 2. 棄用計畫（可選）
在未來的主要版本中，可以考慮：
- 在包裝函式中加入棄用警告
- 在文件中明確標記為 deprecated
- 設定移除時間表

### 3. 程式碼審查
建議在 code review 時檢查是否有新的程式碼使用舊的包裝函式，並建議改用新的呼叫方式。

## 影響範圍

### 直接影響
- ✅ `scripts/utils/pipeline.sh`：2 處修改
- ✅ `test/test-exec-integration.sh`：1 處修改

### 間接影響
- ✅ 無破壞性變更
- ✅ 所有測試通過
- ✅ 向後相容性保持

## 結論

✅ **遷移成功完成！**

- 所有核心程式碼已遷移到新的呼叫方式
- 測試全部通過
- 保持向後相容性
- 程式碼品質提升

遷移工作已完成，系統現在使用更簡潔、更一致的函式呼叫方式。

