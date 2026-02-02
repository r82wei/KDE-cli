# 函式整合說明：exec_script_in_container_with_project

## 整合概述

將 `exec_script_in_container_with_project` 和 `exec_script_in_container_with_project_for_stage` 兩個函式整合為一個，透過可選參數來支援 Pipeline 階段特定掛載。

## 整合前的問題

### 原有兩個函式

1. **exec_script_in_container_with_project**
   - 用於一般專案操作（build、deploy、exec）
   - 支援全局掛載 `KDE_MOUNT_*`
   - 參數：`PROJECT_NAME`, `DOCKER_IMAGE`, `SCRIPT`

2. **exec_script_in_container_with_project_for_stage**
   - 專門用於 Pipeline 階段執行
   - 支援全局掛載 `KDE_MOUNT_*` + 階段特定掛載 `KDE_PIPELINE_STAGE_{stage}_MOUNT_*`
   - 參數：`PROJECT_NAME`, `STAGE`, `DOCKER_IMAGE`, `SCRIPT`

### 問題

- 兩個函式有 **95% 的程式碼重複**
- 唯一差異在於掛載點的處理邏輯
- 維護成本高，修改需要同步兩處

## 整合方案

### 新的函式簽名

```bash
exec_script_in_container_with_project() {
    PROJECT_NAME=$1
    DOCKER_IMAGE=$2
    SCRIPT=$3
    STAGE=$4  # 可選參數
    # ...
}
```

### 掛載邏輯

```bash
# 1. 全局掛載 KDE_MOUNT_*
DOCKER_VOLUMES=$(env | grep '^KDE_MOUNT_' | cut -d= -f2- | sed 's/^/-v /' | xargs)

# 2. 如果提供了 STAGE 參數，則加入階段特定掛載
if [ -n "${STAGE}" ]; then
    # 將 stage 中的連字號轉換為底線（環境變數命名規則）
    local STAGE_VAR=$(echo "${STAGE}" | tr '-' '_')
    STAGE_VOLUMES=$(env | grep "^KDE_PIPELINE_STAGE_${STAGE_VAR}_MOUNT_" | cut -d= -f2- | sed 's/^/-v /' | xargs)
    DOCKER_VOLUMES="${DOCKER_VOLUMES} ${STAGE_VOLUMES}"
fi
```

### 包裝函式（向後相容）

```bash
exec_script_in_container_with_project_for_stage() {
    # 直接呼叫整合後的函式，傳入 STAGE 參數
    exec_script_in_container_with_project "$1" "$3" "$4" "$2"
}
```

## 使用方式

### 一般專案操作（不需要階段掛載）

```bash
# 原有呼叫方式，完全向後相容
exec_script_in_container_with_project "myapp" "node:18" "./build.sh"
```

### Pipeline 階段執行（需要階段掛載）

```bash
# 方式 1：直接呼叫，傳入 STAGE 參數
exec_script_in_container_with_project "myapp" "node:18" "./build.sh" "build"

# 方式 2：使用包裝函式（向後相容）
exec_script_in_container_with_project_for_stage "myapp" "build" "node:18" "./build.sh"
```

## 環境變數配置

### 全局掛載

```bash
# 在 project.env 或環境配置中設定
export KDE_MOUNT_1="/host/path1:/container/path1"
export KDE_MOUNT_2="/host/path2:/container/path2"
```

### 階段特定掛載

```bash
# build 階段的掛載
export KDE_PIPELINE_STAGE_build_MOUNT_1="/build/cache:/cache"
export KDE_PIPELINE_STAGE_build_MOUNT_2="/build/tools:/tools"

# test 階段的掛載
export KDE_PIPELINE_STAGE_test_MOUNT_1="/test/data:/data"

# 階段名稱包含連字號時，會自動轉換為底線
# 例如：pre-build → pre_build
export KDE_PIPELINE_STAGE_pre_build_MOUNT_1="/prebuild/data:/data"
```

## 測試驗證

### 測試腳本

```bash
./test/test-exec-integration.sh
```

### 測試案例

1. ✅ 不帶 STAGE 參數（向後相容性）
2. ✅ 帶 STAGE 參數 'build'（全局 + build 階段掛載）
3. ✅ 帶 STAGE 參數 'test'（全局 + test 階段掛載）
4. ✅ 包裝函式正確呼叫
5. ✅ 階段名稱包含連字號的處理

### 測試結果

```
總測試數：5
通過：5
失敗：0
🎉 所有測試都通過了！
```

## 向後相容性

### 現有呼叫點

所有現有的呼叫點都**完全向後相容**，不需要修改：

#### pipeline.sh
```bash
# 一般 build/deploy 操作（3 個參數）
exec_script_in_container_with_project ${PROJECT_NAME} ${BUILD_IMAGE} ./${BUILD_SCRIPT}
exec_script_in_container_with_project ${PROJECT_NAME} ${DEPLOY_IMAGE} ./${DEPLOY_SCRIPT}

# Pipeline 階段執行（4 個參數）
exec_script_in_container_with_project_for_stage ${PROJECT_NAME} ${STAGE} ${IMAGE} "${SCRIPT}"
```

#### project.sh
```bash
# 專案 exec 操作（3 個參數）
exec_script_in_container_with_project ${PROJECT_NAME} ${DEVELOP_IMAGE} "cd ${REPO_NAME} && bash"
exec_script_in_container_with_project ${PROJECT_NAME} ${DEPLOY_IMAGE} bash
```

## 優點

### 1. 程式碼簡化
- 消除了 95% 的重複程式碼
- 從 ~120 行減少到 ~70 行（含註解）

### 2. 維護性提升
- 只需要維護一個函式
- 修改邏輯時只需要改一處

### 3. 功能擴展
- 未來如果需要新增功能，只需修改一個函式
- 更容易理解和除錯

### 4. 向後相容
- 所有現有呼叫點都不需要修改
- 包裝函式確保 API 穩定性

## 遷移狀態

### ✅ 遷移已完成

所有核心程式碼已從包裝函式遷移到直接呼叫：

```bash
# 舊寫法（已不再使用）
exec_script_in_container_with_project_for_stage ${PROJECT_NAME} ${STAGE} ${IMAGE} "${SCRIPT}"

# 新寫法（目前使用）
exec_script_in_container_with_project ${PROJECT_NAME} ${IMAGE} "${SCRIPT}" ${STAGE}
```

**遷移完成日期**：2026-02-02

**遷移範圍**：
- ✅ `scripts/utils/pipeline.sh`：2 處
- ✅ `test/test-exec-integration.sh`：1 處

詳細資訊請參閱：`docs/dev/migration-complete.md`

## 未來建議

### 1. 包裝函式保留
包裝函式 `exec_script_in_container_with_project_for_stage` 將繼續保留，以確保：
- 外部腳本的向後相容性
- 第三方插件的正常運作

### 2. 文件更新
更新相關文件，說明 `exec_script_in_container_with_project` 的第 4 個參數用途。

### 3. 棄用通知
在未來的版本中，可以考慮標記 `exec_script_in_container_with_project_for_stage` 為 deprecated，並在文件中建議使用新的呼叫方式。

## 相關檔案

- 函式定義：`scripts/utils/environment/k8s.sh`
- 測試檔案：`test/test-exec-integration.sh`
- 使用範例：
  - `scripts/utils/pipeline.sh`
  - `scripts/utils/project.sh`

## 變更歷史

- **2026-02-02**: 完成函式整合，所有測試通過

