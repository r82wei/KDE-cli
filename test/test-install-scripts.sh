#!/bin/bash

# 測試 agents/install-*.sh 的錯誤傳遞
#
# 重點：這些腳本都是 `curl ... | bash` 形式。沒有 set -o pipefail 時，
# curl 失敗（斷網 / 404）的退出碼會被 pipeline 末端的 bash 吞掉而回傳 0，
# 導致 entrypoint 把安裝失敗誤判為成功。本測試以假的 curl 驗證這件事。
#
# 注意：測試完全不連網——PATH 前置一個假的 curl。

echo "===== install 腳本錯誤傳遞測試 ====="
echo ""

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_DIR="${REPO_ROOT}/dockerfiles/code-server/agents"
TMP_ROOT="/tmp/kde-test-install-scripts"

TOTAL=0; PASS=0; FAIL=0
check() { # $1=描述 $2=條件結果(0/1)
    TOTAL=$((TOTAL+1))
    if [[ "$2" -eq 0 ]]; then echo "✅ $1"; PASS=$((PASS+1));
    else echo "❌ $1"; FAIL=$((FAIL+1)); fi
}

# 準備假的 curl：一律失敗且不輸出任何內容（模擬斷網 / 404）
rm -rf "${TMP_ROOT}"
mkdir -p "${TMP_ROOT}/fakebin"
cat > "${TMP_ROOT}/fakebin/curl" <<'EOS'
#!/bin/bash
echo "curl: (6) Could not resolve host" >&2
exit 6
EOS
chmod +x "${TMP_ROOT}/fakebin/curl"

# 逐一驗證每支 install 腳本
for script in "${AGENT_DIR}"/install-*.sh; do
    name=$(basename "${script}")

    # 斷言 1：語法正確
    bash -n "${script}"
    check "${name} 語法正確" $?

    # 斷言 2：有開 pipefail（靜態檢查，讓失敗訊息更好懂）
    grep -qE '^set .*pipefail' "${script}"
    check "${name} 有 set -o pipefail" $?

    # 斷言 3：curl 失敗時腳本必須回傳非零
    if PATH="${TMP_ROOT}/fakebin:${PATH}" bash "${script}" >/dev/null 2>&1; then
        r=1
    else
        r=0
    fi
    check "${name} 在 curl 失敗時回傳非零" $r
done

rm -rf "${TMP_ROOT}"

echo ""
echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
