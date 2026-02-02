# Pipeline 參數解析修正

## 問題描述

原本的實現中，`--only`、`--from`、`--to` 等參數無法正確從命令行傳遞到 Pipeline 執行邏輯。

## 根本原因

### 問題 1：子 Shell 執行導致變數丟失

在 `scripts/project/command.sh` 中：

```bash
# ❌ 錯誤的方式
REMAINING_ARGS=$(parse_pipeline_args "$@")
```

使用 `$()` 會在**子 shell**中執行函數，導致：
- 函數內設置的全局變數（如 `PIPELINE_ONLY_STAGE`）不會影響父 shell
- 即使設置了變數，在 `execute_pipeline` 中也讀取不到

### 問題 2：可能受環境變數污染

如果環境中已經存在 `PIPELINE_ONLY_STAGE` 等變數，可能會影響參數解析。

## 修正方案

### 1. 直接調用函數（不使用子 shell）

```bash
# ✅ 正確的方式
parse_pipeline_args "$@"
PARSE_EXIT_CODE=$?
```

直接調用函數，讓全局變數能夠在當前 shell 中生效。

### 2. 使用全局變數存儲剩餘參數

將 `REMAINING_ARGS` 改為全局變數：

```bash
# 在 pipeline.sh 頂部宣告
REMAINING_ARGS=()

# 在 parse_pipeline_args 中設置
parse_pipeline_args() {
    REMAINING_ARGS=()  # 重置
    # ... 解析邏輯 ...
}
```

### 3. 在解析前重置所有變數

```bash
parse_pipeline_args() {
    # 重置所有 Pipeline 選項變數，確保不會從環境變數繼承
    PIPELINE_FROM_STAGE=""
    PIPELINE_TO_STAGE=""
    PIPELINE_ONLY_STAGE=""
    PIPELINE_MANUAL_MODE=false
    REMAINING_ARGS=()
    # ... 解析邏輯 ...
}
```

### 4. 支援等號語法

同時支援空格和等號兩種語法：

```bash
case "$1" in
    --only=*)
        PIPELINE_ONLY_STAGE="${1#*=}"
        shift
        ;;
    --only)
        PIPELINE_ONLY_STAGE="$2"
        shift 2
        ;;
esac
```

## 修正後的執行流程

```bash
# 1. 使用者執行
kde proj pipeline myapp --only test

# 2. command.sh 處理
parse_pipeline_args "$@"  # 直接調用，不用 $()
# 此時全局變數已設置：
#   PIPELINE_ONLY_STAGE="test"
#   REMAINING_ARGS=("myapp")

# 3. 取得專案名稱
PROJECT_NAME="${REMAINING_ARGS[0]}"  # "myapp"

# 4. 執行 Pipeline
execute_pipeline "${PROJECT_NAME}" "pipeline"

# 5. 在 execute_custom_pipeline 中
STAGES=$(filter_pipeline_stages "${ALL_STAGES}")

# 6. filter_pipeline_stages 檢查全局變數
if [[ -n "${PIPELINE_ONLY_STAGE}" ]]; then
    echo "${PIPELINE_ONLY_STAGE}"  # 返回 "test"
    return 0
fi
```

## 測試驗證

執行測試腳本：

```bash
cd /home/maxime/data/KDE-cli
chmod +x test-pipeline-args.sh
./test-pipeline-args.sh
```

測試案例包括：
1. `--only test` - 只執行 test 階段
2. `--only=test` - 等號語法
3. `--from test --to deploy` - 範圍執行
4. `--manual` - 手動模式
5. 錯誤檢測：`--only` 與 `--from` 同時使用
6. 環境變數污染測試

## 支援的語法

### 空格語法

```bash
kde proj pipeline myapp --only test
kde proj pipeline myapp --from test
kde proj pipeline myapp --to deploy
kde proj pipeline myapp --from test --to deploy
kde proj pipeline myapp --manual
```

### 等號語法

```bash
kde proj pipeline myapp --only=test
kde proj pipeline myapp --from=test
kde proj pipeline myapp --to=deploy
kde proj pipeline myapp --from=test --to=deploy
```

### 混合使用

```bash
kde proj pipeline myapp --from=test --to deploy --manual
```

## 修改的檔案

1. `scripts/utils/pipeline.sh`
   - 新增 `REMAINING_ARGS` 全局變數
   - 修改 `parse_pipeline_args` 在函數開頭重置變數
   - 支援等號語法（`--only=test`）
   - 移除 `echo` 返回，改用全局變數

2. `scripts/project/command.sh`
   - 直接調用 `parse_pipeline_args`（不使用 `$()`）
   - 從全局變數 `REMAINING_ARGS` 讀取專案名稱

## 確認修正成功

執行以下命令驗證：

```bash
# 應該只執行 build 階段
kde proj pipeline myapp --only build

# 應該從 test 開始執行
kde proj pipeline myapp --from test

# 應該報錯（不能同時使用）
kde proj pipeline myapp --only test --from build
```

檢查輸出中的階段列表是否符合預期。

## 總結

**核心問題**：使用子 shell (`$()`) 導致全局變數無法傳遞

**解決方案**：
1. ✅ 直接調用函數（不用 `$()`）
2. ✅ 使用全局變數存儲所有狀態
3. ✅ 在解析前重置變數，防止污染
4. ✅ 支援空格和等號兩種語法

**結果**：參數現在可以正確從命令行傳遞到 Pipeline 執行邏輯！🎉

