#!/bin/bash
set -eo pipefail

# 測試 start_code_server 的多重掛載行為

echo "===== kde code-server 多重掛載測試 ====="
echo ""

export KDE_PATH="/tmp/kde-test-codeserver"
export KDE_CLI_PATH="/tmp/kde-test-codeserver/cli"
export CODE_SERVER_IMAGE="code-server:test"
export PASSWORD="testpass"

rm -rf "${KDE_PATH}"
mkdir -p "${KDE_PATH}/cli"

# 準備掛載目標：兩個目錄 + 一個檔案
mkdir -p "${KDE_PATH}/dir-a" "${KDE_PATH}/dir-b"
touch "${KDE_PATH}/file-c.conf"

source "$(dirname "${BASH_SOURCE[0]}")/../scripts/utils/code-server.sh"

# stub：攔截 docker run，ps 回傳空（無同名容器），stat 回傳固定 gid
docker() {
    case "$1" in
        ps)  return 0 ;;
        run) echo "DOCKER_RUN: $*" ;;
    esac
}
stat() { echo "0"; }

TOTAL=0; PASS=0; FAIL=0
check() { # $1=描述 $2=條件結果(0/1)
    TOTAL=$((TOTAL+1))
    if [[ "$2" -eq 0 ]]; then echo "✅ $1"; PASS=$((PASS+1));
    else echo "❌ $1"; FAIL=$((FAIL+1)); fi
}

# 測試 1：多個目錄 -v 都展開為 host:host
out=$(start_code_server 8080 false cs-1 "" "${KDE_PATH}/dir-a" "${KDE_PATH}/dir-b" 2>&1)
echo "$out" | grep -q -- "-v ${KDE_PATH}/dir-a:${KDE_PATH}/dir-a" \
  && echo "$out" | grep -q -- "-v ${KDE_PATH}/dir-b:${KDE_PATH}/dir-b"
check "多個目錄掛載都展開為 host:host" $?

# 測試 2：檔案也能掛載
out=$(start_code_server 8080 false cs-2 "${KDE_PATH}/dir-a" "${KDE_PATH}/dir-a" "${KDE_PATH}/file-c.conf" 2>&1)
echo "$out" | grep -q -- "-v ${KDE_PATH}/file-c.conf:${KDE_PATH}/file-c.conf"
check "單一檔案可掛載" $?

# 測試 3：未給 workdir 時預設第一個目錄型掛載（跳過檔案）
out=$(start_code_server 8080 false cs-3 "" "${KDE_PATH}/file-c.conf" "${KDE_PATH}/dir-b" 2>&1)
echo "$out" | grep -q -- "--workdir ${KDE_PATH}/dir-b"
check "預設 workdir 為第一個目錄型掛載" $?

# 測試 4：不存在的掛載目標報錯 return 1
if start_code_server 8080 false cs-4 "" "${KDE_PATH}/nope" >/dev/null 2>&1; then r=1; else r=0; fi
check "不存在的掛載目標報錯" $r

# 測試 5：重複路徑去重（只出現一次）
out=$(start_code_server 8080 false cs-5 "" "${KDE_PATH}/dir-a" "${KDE_PATH}/dir-a" 2>&1)
cnt=$(echo "$out" | grep -o -- "-v ${KDE_PATH}/dir-a:${KDE_PATH}/dir-a" | wc -l)
[[ "$cnt" -eq 1 ]]
check "重複掛載路徑去重" $?

# 測試 6：全部為檔案且未給 workdir 時報錯
if start_code_server 8080 false cs-6 "" "${KDE_PATH}/file-c.conf" >/dev/null 2>&1; then r=1; else r=0; fi
check "全為檔案且無 workdir 時報錯" $r

rm -rf "${KDE_PATH}"

echo ""
echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
