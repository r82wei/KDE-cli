# 遷移變更日誌

## 2026-02-02：函式遷移完成

### 變更摘要

將所有使用 `exec_script_in_container_with_project_for_stage` 包裝函式的地方改為直接使用 `exec_script_in_container_with_project`。

### 修改的檔案

| 檔案 | 修改處數 | 狀態 |
|-----|---------|------|
| `scripts/utils/pipeline.sh` | 2 | ✅ 完成 |
| `test/test-exec-integration.sh` | 1 | ✅ 完成 |

### 函式呼叫變更

#### 修改前
```bash
exec_script_in_container_with_project_for_stage PROJECT_NAME STAGE IMAGE SCRIPT
```

#### 修改後
```bash
exec_script_in_container_with_project PROJECT_NAME IMAGE SCRIPT STAGE
```

### 測試結果

```
總測試數：5
通過：5
失敗：0
🎉 所有測試都通過了！
```

### 向後相容性

✅ **完全相容**

包裝函式 `exec_script_in_container_with_project_for_stage` 仍然保留在程式碼中，確保外部腳本和插件的相容性。

### 相關文件

- 整合說明：`docs/dev/function-integration.md`
- 遷移報告：`docs/dev/migration-complete.md`
- 整合總結：`INTEGRATION_SUMMARY.md`

---

## 2026-02-02：函式整合

### 變更摘要

整合 `exec_script_in_container_with_project` 和 `exec_script_in_container_with_project_for_stage` 兩個函式。

### 整合方式

將 `STAGE` 參數作為第 4 個可選參數加入 `exec_script_in_container_with_project`：

```bash
exec_script_in_container_with_project() {
    PROJECT_NAME=$1
    DOCKER_IMAGE=$2
    SCRIPT=$3
    STAGE=$4  # 可選參數
    # ...
}
```

### 優點

- 消除 95% 的程式碼重複
- 程式碼從 ~120 行減少到 ~70 行
- 維護成本降低
- 功能更靈活

### 測試

新增測試檔案：`test/test-exec-integration.sh`

### 相關文件

- 整合說明：`docs/dev/function-integration.md`
- 整合總結：`INTEGRATION_SUMMARY.md`

