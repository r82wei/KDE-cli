#!/bin/bash

# 測試 local-install.sh / uninstall.sh 的安裝與重裝行為
#
# 核心迴歸：重裝時 lib 目錄的 inode 必須保持不變。
#
# 為什麼這件事值得一支測試釘住：/usr/local/lib/kde 會被 kde openclaw 與
# kde code-server 以 bind mount 掛進容器（唯讀）。bind mount 綁的是 inode，
# 若重裝時把目錄整個 rm -rf 再建回來，運行中的容器會繼續守著那個已刪除的
# inode，容器內看到的是一個空目錄——症狀是 `kde: command not found`，而且
# 無法靠再裝一次修好，只能重建容器。改成「只清內容、保留目錄」之後，重裝
# 對運行中的容器就是即時生效的版本更新。
#
# 測試完全在 /tmp 底下進行，不需要 root、也不會碰到真正的 /usr/local。

echo "===== local-install / uninstall 測試 ====="
echo ""

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="/tmp/kde-test-local-install"
LIB_DIR="${TMP_ROOT}/lib/kde"
BIN_DIR="${TMP_ROOT}/bin"

TOTAL=0; PASS=0; FAIL=0
check() { # $1=描述 $2=條件結果(0/1)
    TOTAL=$((TOTAL+1))
    if [[ "$2" -eq 0 ]]; then echo "✅ $1"; PASS=$((PASS+1));
    else echo "❌ $1"; FAIL=$((FAIL+1)); fi
}

# 以覆寫過的安裝路徑跑一次 local-install.sh。
# 必須從 repo 根目錄執行：腳本裡的來源路徑是 ./scripts 之類的相對路徑。
run_install() {
    (
        cd "${REPO_ROOT}" || exit 1
        KDE_INSTALL_LIB_DIR="${LIB_DIR}" KDE_INSTALL_BIN_DIR="${BIN_DIR}" \
            bash local-install.sh
    ) >/dev/null 2>&1
}

rm -rf "${TMP_ROOT}"
mkdir -p "${BIN_DIR}"

# ---- 斷言 1：語法 ----
bash -n "${REPO_ROOT}/local-install.sh"
check "local-install.sh 語法正確" $?
bash -n "${REPO_ROOT}/uninstall.sh"
check "uninstall.sh 語法正確" $?

# ---- 斷言 2：首次安裝把該有的東西放到位 ----
run_install
check "首次安裝回傳 0" $?

[[ -f "${LIB_DIR}/kde.sh" && -d "${LIB_DIR}/scripts" && -d "${LIB_DIR}/docs" \
   && -d "${LIB_DIR}/templates" && -d "${LIB_DIR}/.claude" ]]
check "首次安裝：kde.sh 與四個目錄都就位" $?

[[ "$(readlink "${BIN_DIR}/kde")" == "${LIB_DIR}/kde.sh" ]]
check "首次安裝：symlink 指向 lib 目錄的 kde.sh" $?

# ---- 斷言 3（核心）：重裝後，既有的目錄參照仍看得到新內容 ----
#
# 這裡刻意「不」比對 lib 目錄的 inode。實測確認那是個假的守衛：rm -rf 之後
# 立刻 mkdir，ext4 會把剛釋放的 inode number 直接重用，前後比對得到相同的值，
# 即使目錄確實被換過一次——把 bug 放回去，inode 斷言照樣通過。
#
# 改為用「cwd 停在該目錄的子行程」當探針，語意與 bind mount 完全對應：目錄被
# rm -rf 掉時，該行程的 cwd 會留在已刪除的 inode 上，從它的視角 `ls .` 是空的；
# 只清內容時則看得到新複製進去的檔案。用 FIFO 當閘門，不依賴 sleep 抓時序。
GATE="${TMP_ROOT}/gate"
SEEN="${TMP_ROOT}/seen.txt"
rm -f "${GATE}" "${SEEN}"
mkfifo "${GATE}"

# 子行程：先進到 lib 目錄，卡在 FIFO 上等安裝跑完，然後從自己的 cwd 視角列出內容
( cd "${LIB_DIR}" && read -r _ < "${GATE}" && ls -A . > "${SEEN}" 2>&1 ) &
probe_pid=$!

run_install
check "重裝回傳 0" $?

echo go > "${GATE}"
wait "${probe_pid}"

grep -qx 'kde.sh' "${SEEN}"
check "重裝後既有的目錄參照仍看得到 kde.sh（bind mount 不會變成空目錄）" $?

grep -qx 'scripts' "${SEEN}"
check "重裝後既有的目錄參照仍看得到 scripts/" $?

# ---- 斷言 4：重裝仍然是「乾淨」安裝，殘留檔案要被清掉 ----
# 模擬上一版留下、新版已不存在的檔案
echo stale > "${LIB_DIR}/stale-from-old-version.txt"
mkdir -p "${LIB_DIR}/stale-dir"
run_install
[[ ! -e "${LIB_DIR}/stale-from-old-version.txt" && ! -e "${LIB_DIR}/stale-dir" ]]
check "重裝清掉舊版殘留的檔案與目錄" $?

[[ -f "${LIB_DIR}/kde.sh" ]]
check "重裝後 kde.sh 仍在（清乾淨不等於清光）" $?

# ---- 斷言 5：重裝後 symlink 仍正確（不會殘留舊的或重複建立而失敗）----
[[ "$(readlink "${BIN_DIR}/kde")" == "${LIB_DIR}/kde.sh" ]]
check "重裝後 symlink 仍正確" $?

# ---- 斷言 6：uninstall.sh 獨立執行時，仍要刪掉整個目錄 ----
# 這是與斷言 3 相反的要求，刻意分開：解除安裝就是要移除目錄本身，
# 「保留目錄」只是重裝路徑上的取捨。
(
    cd "${REPO_ROOT}" || exit 1
    KDE_INSTALL_LIB_DIR="${LIB_DIR}" KDE_INSTALL_BIN_DIR="${BIN_DIR}" \
        bash uninstall.sh
) >/dev/null 2>&1
[[ ! -e "${LIB_DIR}" && ! -e "${BIN_DIR}/kde" ]]
check "uninstall.sh 移除 lib 目錄本身與 symlink" $?

# ---- 斷言 7：安裝路徑未覆寫時，預設值仍是 /usr/local（不靠實際執行驗證）----
grep -q 'KDE_INSTALL_LIB_DIR:-/usr/local/lib/kde' "${REPO_ROOT}/local-install.sh"
check "local-install.sh 預設 lib 路徑為 /usr/local/lib/kde" $?
grep -q 'KDE_INSTALL_BIN_DIR:-/usr/local/bin' "${REPO_ROOT}/local-install.sh"
check "local-install.sh 預設 bin 路徑為 /usr/local/bin" $?

rm -rf "${TMP_ROOT}"

echo ""
echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
