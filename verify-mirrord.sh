#!/bin/bash
# Mirrord 功能驗證腳本

echo "======================================"
echo "Mirrord 功能驗證"
echo "======================================"
echo ""

# 設定臨時環境變數
export KDE_CLI_PATH=$(dirname $(readlink -f "$0"))
export KDE_SCRIPTS_PATH=${KDE_CLI_PATH}/scripts

echo "1. 檢查檔案存在性"
echo "--------------------------------------"

files=(
    "dockerfiles/mirrord/Dockerfile"
    "dockerfiles/mirrord/entrypoint.sh"
    "dockerfiles/mirrord/build.sh"
    "dockerfiles/mirrord/run.sh"
    "scripts/utils/mirrord.sh"
    "scripts/mirrord/command.sh"
    "docs/core/dev-tools/mirrord.md"
)

for file in "${files[@]}"; do
    if [[ -f "${file}" ]]; then
        echo "  ✅ ${file}"
    else
        echo "  ❌ ${file} - 檔案不存在"
    fi
done

echo ""
echo "2. 檢查腳本執行權限"
echo "--------------------------------------"

scripts=(
    "dockerfiles/mirrord/entrypoint.sh"
    "dockerfiles/mirrord/build.sh"
    "dockerfiles/mirrord/run.sh"
    "scripts/utils/mirrord.sh"
    "scripts/mirrord/command.sh"
)

for script in "${scripts[@]}"; do
    if [[ -x "${script}" ]]; then
        echo "  ✅ ${script} - 可執行"
    else
        echo "  ⚠️  ${script} - 無執行權限"
    fi
done

echo ""
echo "3. 檢查 kde.sh 整合"
echo "--------------------------------------"

if grep -q "mirrord" kde.sh; then
    echo "  ✅ kde.sh 包含 mirrord 指令"
    echo ""
    echo "  找到的 mirrord 相關行："
    grep -n "mirrord" kde.sh | sed 's/^/    /'
else
    echo "  ❌ kde.sh 未整合 mirrord"
fi

echo ""
echo "4. 檢查函式定義"
echo "--------------------------------------"

if [[ -f "scripts/utils/mirrord.sh" ]]; then
    echo "  核心函式："
    grep "^[a-z_]*() {" scripts/utils/mirrord.sh | sed 's/() {//' | sed 's/^/    - /'
fi

echo ""
echo "5. 檢查指令結構"
echo "--------------------------------------"

if [[ -f "scripts/mirrord/command.sh" ]]; then
    echo "  指令參數解析："
    grep -A 5 "case.*COMMAND.*in" scripts/mirrord/command.sh | head -10 | sed 's/^/    /'
fi

echo ""
echo "======================================"
echo "驗證完成！"
echo "======================================"
echo ""
echo "下一步："
echo "1. 初始化環境: ./kde.sh init"
echo "2. 建置映像: cd dockerfiles/mirrord && ./build.sh"
echo "3. 測試指令: ./kde.sh mirrord --help"
echo ""
