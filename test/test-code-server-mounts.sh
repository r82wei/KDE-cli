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

# 準備給 $PWD 預設掛載測試用的目錄
mkdir -p "${KDE_PATH}/pwd-test"

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

# 測試 7（FIX 1 回歸測試）：中間路徑不存在時，readlink -f 失敗也不應讓整個
# 程序在 set -e 下靜默中止，而是要落到「掛載目標不存在」的檢查並印出錯誤
# 注意：不可寫成 out=$(start_code_server ...) 這種「純賦值」形式，因為
# start_code_server 預期回傳非 0，該寫法在 set -e 下會直接中止整支測試腳本；
# 改用 if/then/else（其在 set -e 下不會觸發中止）並把輸出導向暫存檔案檢查。
test7_out="${KDE_PATH}/test7.out"
if start_code_server 8080 false cs-7 "" "${KDE_PATH}/no-such-dir/app" >"${test7_out}" 2>&1; then
    ok7=false
else
    ok7=true
fi
grep -q "掛載來源不存在" "${test7_out}" || ok7=false
[[ "${ok7}" == "true" ]]
check "中間路徑不存在時不會靜默中止，且回報錯誤" $?

# 測試 8：未給任何掛載參數時，預設掛載 $PWD 且 workdir 為 $PWD
( cd "${KDE_PATH}/pwd-test" && out=$(start_code_server 8080 false cs-8 "" 2>&1)
  echo "$out" | grep -q -- "-v ${PWD}:${PWD}" \
    && echo "$out" | grep -q -- "--workdir ${PWD}" )
check "未給掛載目標時預設掛載並開啟 \$PWD" $?

# 測試 9：明確指定的開啟資料夾不在任何目錄型掛載底下時報錯
if start_code_server 8080 false cs-9 "${KDE_PATH}/dir-b" "${KDE_PATH}/dir-a" >/dev/null 2>&1; then r=1; else r=0; fi
check "開啟資料夾不在掛載目錄底下時報錯" $r

# ===== src:dst[:ro|rw] 顯式對映擴充 =====

# 測試 10：src:dst 形式，container 路徑與 host 不同
out=$(start_code_server 8080 false cs-10 "" "${KDE_PATH}/dir-a:/mnt/a" 2>&1)
echo "$out" | grep -q -- "-v ${KDE_PATH}/dir-a:/mnt/a" \
  && echo "$out" | grep -q -- "--workdir /mnt/a"
check "src:dst 形式掛載並以 dst 為 workdir" $?

# 測試 11：src:dst:ro 形式，唯讀選項要傳給 docker
out=$(start_code_server 8080 false cs-11 "" "${KDE_PATH}/dir-a" "${KDE_PATH}/file-c.conf:/etc/x.conf:ro" 2>&1)
echo "$out" | grep -q -- "-v ${KDE_PATH}/file-c.conf:/etc/x.conf:ro"
check "src:dst:ro 形式帶唯讀選項" $?

# 測試 12：dst 非絕對路徑時報錯
if start_code_server 8080 false cs-12 "" "${KDE_PATH}/dir-a:relative" >/dev/null 2>&1; then r=1; else r=0; fi
check "dst 非絕對路徑報錯" $r

# 測試 13：無效 opt（非 ro/rw）時報錯
if start_code_server 8080 false cs-13 "" "${KDE_PATH}/dir-a:/mnt/a:xx" >/dev/null 2>&1; then r=1; else r=0; fi
check "無效掛載選項報錯" $r

# 測試 14：欄位過多（>3）時報錯
if start_code_server 8080 false cs-14 "" "${KDE_PATH}/dir-a:/a:/b:ro" >/dev/null 2>&1; then r=1; else r=0; fi
check "掛載欄位過多報錯" $r

# 測試 15：混合檔案(帶 dst)與目錄(帶 dst)時，預設 workdir 為第一個目錄型掛載的 dst
out=$(start_code_server 8080 false cs-15 "" "${KDE_PATH}/file-c.conf:/etc/c" "${KDE_PATH}/dir-b:/work" 2>&1)
echo "$out" | grep -q -- "--workdir /work"
check "預設 workdir 為第一個目錄型掛載的 dst" $?

# 測試 16：以 dst 去重（兩個不同 src 對映同一 container 路徑只掛一次）
out=$(start_code_server 8080 false cs-16 "" "${KDE_PATH}/dir-a:/mnt/x" "${KDE_PATH}/dir-b:/mnt/x" 2>&1)
cnt=$(echo "$out" | grep -o -- "-v [^ ]*:/mnt/x" | wc -l)
[[ "$cnt" -eq 1 ]]
check "以 dst 去重（同一 container 路徑只掛一次）" $?

# 測試 17：明確給定但為空的 dst（src:）時報錯
if start_code_server 8080 false cs-17 "" "${KDE_PATH}/dir-a:" >/dev/null 2>&1; then r=1; else r=0; fi
check "空的 dst 欄位報錯" $r

# 測試 18：rw 選項也能傳給 docker
out=$(start_code_server 8080 false cs-18 "" "${KDE_PATH}/dir-a:/mnt/a:rw" 2>&1)
echo "$out" | grep -q -- "-v ${KDE_PATH}/dir-a:/mnt/a:rw"
check "src:dst:rw 形式帶讀寫選項" $?

# 測試 19：相對路徑 -w 的向後相容（plain-form 下 dst=host 絕對路徑）
mkdir -p "${KDE_PATH}/dir-a/sub"
( cd "${KDE_PATH}/dir-a" && out=$(start_code_server 8080 false cs-19 "./sub" "${KDE_PATH}/dir-a" 2>&1)
  echo "$out" | grep -q -- "--workdir ${KDE_PATH}/dir-a/sub" )
check "相對路徑 -w 向後相容" $?

rm -rf "${KDE_PATH}"

echo ""
echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
