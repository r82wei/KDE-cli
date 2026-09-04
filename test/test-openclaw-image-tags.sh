#!/bin/bash
set -eo pipefail

# 檢查 kde-openclaw 的映像 tag 策略。這兩件事都實際踩過：
#
# 1. build.sh 曾經也打 latest tag。docker run 的預設 pull policy 是 missing——
#    本地只要有該 tag 就直接用，永遠不會回頭問 registry。於是本機跑一次 build.sh
#    就會讓 latest 指向那個一次性的測試映像，之後該機器上所有
#    kde openclaw run/restart 都沉默地跑它。症狀是「明明 release 了新版，
#    容器卻一直是舊的」，而且沒有任何徵兆——實際發生過，查了兩層才找到。
#
# 2. release.sh 曾經跑兩次獨立的 buildx build（第二次還漏了 --no-cache），
#    因此 <hash>-<version> 與 latest 是兩個 manifest digest 不同的映像，
#    內容「應該」相同但沒有任何保證。一次 build 兩個 tag 才有保證，也省一半時間。
#
# 這支測試只做靜態檢查（不真的建映像），成本近乎零，但守住的是兩個安靜的坑。

echo "===== kde-openclaw 映像 tag 策略測試 ====="
echo ""

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${ROOT}/dockerfiles/kde-openclaw/build.sh"
RELEASE="${ROOT}/dockerfiles/kde-openclaw/release.sh"

TOTAL=0; PASS=0; FAIL=0
check() { # $1=描述 $2=條件結果(0/1)
    TOTAL=$((TOTAL+1))
    if [[ "$2" -eq 0 ]]; then echo "✅ $1"; PASS=$((PASS+1));
    else echo "❌ $1"; FAIL=$((FAIL+1)); fi
}

# 本檔開了 set -e，裸露的失敗 grep 會直接中止腳本，讓失敗變成「後面沒跑」
# 而不是「回報失敗」。所有斷言一律走這兩個 helper。
has()        { grep -q -- "$2" "$1"; }
assert_has()   { if has "$2" "$3"; then check "$1" 0; else check "$1" 1; fi; }
assert_lacks() { if has "$2" "$3"; then check "$1" 1; else check "$1" 0; fi; }

# 兩支腳本都存在且語法正確
for f in "${BUILD}" "${RELEASE}"; do
    if [[ -f "$f" ]]; then check "$(basename "$f") 存在" 0; else check "$(basename "$f") 存在" 1; continue; fi
    if bash -n "$f" 2>/dev/null; then check "$(basename "$f") 語法正確" 0; else check "$(basename "$f") 語法正確" 1; fi
done

echo ""
echo "--- build.sh：本機建置不得冒用 latest ---"
assert_lacks "不打 latest tag" "${BUILD}" "kde-openclaw:latest"
assert_has   "仍打版本 tag" "${BUILD}" 'kde-openclaw:${KDE_CLI_VERSION}-${OPENCLAW_VERSION}'
assert_has   "--load 進本機" "${BUILD}" "--load"
# 建置失敗時不該還印出成功訊息，否則使用者會拿一個不存在的 tag 去啟動
assert_has   "建置失敗會中止" "${BUILD}" "exit 1"
# 不再自動被 run 撿到，所以必須告訴使用者怎麼用剛建好的映像
assert_has   "印出如何使用該映像" "${BUILD}" "OPENCLAW_IMAGE="

echo ""
echo "--- release.sh：一次 build、兩個 tag ---"
build_count=$(grep -cE '^[[:space:]]*docker buildx build' "${RELEASE}")
if [[ "${build_count}" -eq 1 ]]; then check "只有一次 buildx build（實際 ${build_count}）" 0
else check "只有一次 buildx build（實際 ${build_count}）" 1; fi

tag_count=$(grep -cE '^[[:space:]]*-t ' "${RELEASE}")
if [[ "${tag_count}" -eq 2 ]]; then check "同一次 build 打兩個 tag（實際 ${tag_count}）" 0
else check "同一次 build 打兩個 tag（實際 ${tag_count}）" 1; fi

assert_has "打版本 tag" "${RELEASE}" 'kde-openclaw:${KDE_CLI_VERSION}-${OPENCLAW_VERSION}'
assert_has "打 latest tag" "${RELEASE}" "kde-openclaw:latest"
assert_has "帶 --no-cache" "${RELEASE}" "--no-cache"
assert_has "推上 registry" "${RELEASE}" "--push"

echo ""
echo "===== 測試結果 ====="
echo "總計: ${TOTAL}, 通過: ${PASS}, 失敗: ${FAIL}"
if [[ ${FAIL} -gt 0 ]]; then
    exit 1
fi
echo "✓ 全部通過"
