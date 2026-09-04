#!/bin/bash

# 測試 dockerfiles/kde-openclaw/kde-wrapper.sh
#
# 這支 wrapper 是容器內 /usr/local/bin/kde 的實體。映像刻意不內建 kde-cli，
# CLI 全部來自主機端的唯讀 bind mount，因此 wrapper 只有兩件事要做對：
#   1. 掛載存在時，把參數原封不動轉交給掛進來的 kde.sh
#   2. 掛載缺席時，給出指向真正原因的錯誤訊息（而不是 symlink 的 ENOENT）
#
# 測試不需要 Docker、也不需要 root：wrapper 的 lib 路徑可用 KDE_LIB_DIR 覆寫。

echo "===== openclaw kde wrapper 測試 ====="
echo ""

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRAPPER="${REPO_ROOT}/dockerfiles/kde-openclaw/kde-wrapper.sh"
TMP_ROOT="/tmp/kde-test-openclaw-wrapper"

TOTAL=0; PASS=0; FAIL=0
check() { # $1=描述 $2=條件結果(0/1)
    TOTAL=$((TOTAL+1))
    if [[ "$2" -eq 0 ]]; then echo "✅ $1"; PASS=$((PASS+1));
    else echo "❌ $1"; FAIL=$((FAIL+1)); fi
}

rm -rf "${TMP_ROOT}"
mkdir -p "${TMP_ROOT}/empty-lib" "${TMP_ROOT}/good-lib"

# ---- 斷言 1：語法 ----
bash -n "${WRAPPER}"
check "wrapper 語法正確" $?

# ---- 斷言 2：lib 目錄是空的（掛載缺席／守著已刪除的 inode）----
out=$(KDE_LIB_DIR="${TMP_ROOT}/empty-lib" bash "${WRAPPER}" 2>&1); rc=$?
[[ ${rc} -ne 0 ]]
check "lib 目錄為空時回傳非零" $?

grep -q "kde openclaw stop && kde openclaw run" <<< "${out}"
check "錯誤訊息給出重建容器的修法" $?

grep -q "刻意不內建" <<< "${out}"
check "錯誤訊息說明為何映像內沒有 kde" $?

# 錯誤訊息必須全部走 stderr：stdout 是資料通道（例如 kde openclaw token 會被管線接走）
out_stdout=$(KDE_LIB_DIR="${TMP_ROOT}/empty-lib" bash "${WRAPPER}" 2>/dev/null)
[[ -z "${out_stdout}" ]]
check "錯誤訊息不汙染 stdout" $?

# ---- 斷言 3：kde.sh 存在但不可執行，同樣要報錯 ----
# bind mount 是唯讀的，權限出錯時 exec 會失敗，提前擋掉比讓它爆在 exec 好懂
echo '#!/bin/bash' > "${TMP_ROOT}/good-lib/kde.sh"
chmod -x "${TMP_ROOT}/good-lib/kde.sh"
KDE_LIB_DIR="${TMP_ROOT}/good-lib" bash "${WRAPPER}" >/dev/null 2>&1
[[ $? -ne 0 ]]
check "kde.sh 不可執行時回傳非零" $?

# ---- 斷言 4：掛載正常時原封不動轉交 ----
cat > "${TMP_ROOT}/good-lib/kde.sh" <<'EOS'
#!/bin/bash
echo "argc=$#"
for a in "$@"; do echo "arg=[$a]"; done
exit 7
EOS
chmod +x "${TMP_ROOT}/good-lib/kde.sh"

out=$(KDE_LIB_DIR="${TMP_ROOT}/good-lib" bash "${WRAPPER}" proj exec "ls -la" 2>&1); rc=$?
grep -qx 'argc=3' <<< "${out}"
check "參數個數正確轉交（含空白的參數不被拆開）" $?

grep -qx 'arg=\[ls -la\]' <<< "${out}"
check "含空白的參數原封不動轉交" $?

[[ ${rc} -eq 7 ]]
check "轉交後的離開碼原樣回傳（exec 取代自身）" $?

# ---- 斷言 5：Dockerfile 確實把 wrapper 放到 /usr/local/bin/kde，且不再內建 CLI ----
DOCKERFILE="${REPO_ROOT}/dockerfiles/kde-openclaw/Dockerfile"
grep -q 'kde-wrapper.sh /usr/local/bin/kde' "${DOCKERFILE}"
check "Dockerfile 把 wrapper 複製為 /usr/local/bin/kde" $?

grep -q 'local-install.sh' "${DOCKERFILE}"
[[ $? -ne 0 ]]
check "Dockerfile 不再於映像內安裝 kde-cli" $?

rm -rf "${TMP_ROOT}"

echo ""
echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
