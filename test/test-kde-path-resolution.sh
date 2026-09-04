#!/bin/bash
set -eo pipefail

# 測試 kde.sh 如何定位 workspace 根目錄（KDE_PATH）
#
# 觀察點刻意是「有沒有印出『kde.env 不存在』」，而不是去讀 KDE_PATH 變數：
# kde.sh 是獨立行程，變數拿不出來，而那句錯誤訊息正是定位失敗唯一的外顯行為。
# 它也正是這個測試要防的回歸 —— OpenClaw 的 agent 家目錄是 ~/.openclaw/workspace，
# 在那裡跑 kde 會被那句話引導去 kde init，而 kde init 會把整套 workspace 模板
# 灌進 agent 自己的家目錄。
#
# 探測用的指令刻意是不存在的 __probe__：它會走完設定載入（含 kde.env 檢查）
# 才顯示說明，所以「有沒有那句錯誤」剛好能區分定位成功與失敗；而 version
# 之類的指令在檢查之前就 exit，測不到東西。

echo "===== kde.sh workspace 定位測試 ====="
echo ""

KDE_SH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../kde.sh"

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "${TMP_ROOT}"' EXIT

# 有 kde.env 的 workspace，含一層子目錄（測往上找）
WS="${TMP_ROOT}/workspace"
mkdir -p "${WS}/sub"
touch "${WS}/kde.env"
# 沒有 kde.env 的目錄，且其所有上層（mktemp -d 底下）也都沒有
OUTSIDE="${TMP_ROOT}/outside"
mkdir -p "${OUTSIDE}"
# 另一個「不是 workspace」的目錄，用來驗證帶入值勝過 $PWD 推導
NOT_WS="${TMP_ROOT}/not-a-workspace"
mkdir -p "${NOT_WS}"

TOTAL=0; PASS=0; FAIL=0
check() { # $1=描述 $2=條件結果(0/1)
    TOTAL=$((TOTAL+1))
    if [[ "$2" -eq 0 ]]; then echo "✅ $1"; PASS=$((PASS+1));
    else echo "❌ $1"; FAIL=$((FAIL+1)); fi
}
assert_true()  { local d="$1"; shift; if "$@" >/dev/null 2>&1; then check "${d}" 0; else check "${d}" 1; fi; }
assert_false() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then check "${d}" 1; else check "${d}" 0; fi; }

# 在指定 cwd 與環境下跑 kde.sh，把輸出收進 OUT。
# 本檔開了 set -e，故用 || true 承接非零回傳（定位失敗時 kde.sh 會 exit 1）。
OUT=""
run_kde() { # $1=cwd  $2=KDE_PATH（空字串代表不設）
    if [[ -n "$2" ]]; then
        OUT=$(cd "$1" && KDE_PATH="$2" bash "${KDE_SH}" __probe__ 2>&1 || true)
    else
        OUT=$(cd "$1" && env -u KDE_PATH bash "${KDE_SH}" __probe__ 2>&1 || true)
    fi
}
# 定位失敗有兩種訊息，刻意分開：$PWD 推導不到時建議 kde init（NOT_FOUND），
# 明確指定（-C 或帶入 KDE_PATH）卻不是 workspace 時指出那個路徑（GIVEN_BAD）。
NOT_FOUND="kde.env 不存在"
GIVEN_BAD="沒有 kde.env"
out_has() { echo "${OUT}" | grep -q -- "$1"; }
assert_located()   { if out_has "${NOT_FOUND}" || out_has "${GIVEN_BAD}"; then check "$1" 1; else check "$1" 0; fi; }
assert_not_found() { if out_has "${NOT_FOUND}"; then check "$1" 0; else check "$1" 1; fi; }
assert_out()       { if out_has "$2"; then check "$1" 0; else check "$1" 1; fi; }
assert_no_out()    { if out_has "$2"; then check "$1" 1; else check "$1" 0; fi; }

echo "--- 未帶入 KDE_PATH：維持原本的 \$PWD 往上找 ---"
run_kde "${WS}" ""
assert_located "cwd 就是 workspace 時定位成功"

run_kde "${WS}/sub" ""
assert_located "cwd 在子目錄時往上找到 workspace"

run_kde "${OUTSIDE}" ""
assert_not_found "cwd 與其上層都沒有 kde.env 時報錯"
echo ""

echo "--- 帶入 KDE_PATH：直接採用，不再推導 ---"
run_kde "${OUTSIDE}" "${WS}"
assert_located "cwd 在 workspace 外，帶入 KDE_PATH 仍定位成功"

# 這是給容器內 agent 用的關鍵情境：cwd 是它自己的家目錄，與 workspace 無關
run_kde "${HOME}" "${WS}"
assert_located "cwd 是任意無關目錄（如 agent 家目錄）時仍定位成功"

# 帶入值必須勝過 $PWD 推導，否則「明確指定」形同虛設。
# 觀察法：cwd 在真 workspace 裡，但 KDE_PATH 指向一個沒有 kde.env 的目錄，
# 若帶入值生效就會報錯 —— 這比讀變數更能證明優先序。
run_kde "${WS}/sub" "${NOT_WS}"
assert_out "帶入值勝過 \$PWD 推導（指向非 workspace 時如實報錯）" "${GIVEN_BAD}"

# 空字串等同未帶入：避免 KDE_PATH= 這種空值把定位整個廢掉
OUT=$(cd "${WS}/sub" && KDE_PATH="" bash "${KDE_SH}" __probe__ 2>&1 || true)
assert_located "KDE_PATH 為空字串時視為未帶入，退回 \$PWD 推導"
echo ""

echo "--- -C / --workspace 全域旗標 ---"
# 旗標一律在子命令之前。跑法與 run_kde 相同，只是參數不同，故另寫一個。
run_kde_flag() { # $1=cwd  其餘=傳給 kde.sh 的參數
    local cwd="$1"; shift
    OUT=$(cd "${cwd}" && env -u KDE_PATH bash "${KDE_SH}" "$@" 2>&1 || true)
}
run_kde_flag "${OUTSIDE}" -C "${WS}" __probe__
assert_located "-C <ws> 從 workspace 外也能定位"

run_kde_flag "${OUTSIDE}" --workspace "${WS}" __probe__
assert_located "--workspace 是等效的長旗標"

# 明確指定要勝過環境變數：兩者同時存在時以旗標為準
OUT=$(cd "${OUTSIDE}" && KDE_PATH="${NOT_WS}" bash "${KDE_SH}" -C "${WS}" __probe__ 2>&1 || true)
assert_located "-C 勝過帶入的 KDE_PATH"

# 相對路徑要被絕對化：KDE_PATH 會被烤進 docker 的 -v/--workdir，相對路徑會讓
# Docker 直接失敗。用「錯誤訊息裡印的是絕對路徑」來觀察 readlink -f 有沒有跑。
run_kde_flag "${TMP_ROOT}" -C ./workspace __probe__
assert_located "-C 接受相對路徑"
run_kde_flag "${TMP_ROOT}" -C ./nope __probe__
assert_out "-C 的路徑會被絕對化（錯誤訊息印絕對路徑）" "${TMP_ROOT}/nope"

# -C 不往上找：明確指定就照字面採用。否則 kde -C <ws>/sub init 會往上找到 <ws>，
# 把模板灌進父目錄——init 是往 ${KDE_PATH} 灌東西，走錯目錄代價很高。
run_kde_flag "${OUTSIDE}" -C "${WS}/sub" __probe__
assert_out "-C 不往上找，指到非 workspace 就如實報錯" "沒有 kde.env"
assert_no_out "明確指定時不再叫人跑裸的 kde init" "請先執行 kde init"

run_kde_flag "${OUTSIDE}" -C "${TMP_ROOT}/nonexistent" __probe__
assert_out "-C 指到不存在的目錄時明確報錯" "目錄不存在"

run_kde_flag "${OUTSIDE}" -C
assert_out "-C 沒帶路徑時報錯" "需要"

# 帶入 KDE_PATH（容器的情況）同樣算明確指定，錯誤訊息要一致地指出路徑本身
OUT=$(cd "${OUTSIDE}" && KDE_PATH="${WS}/sub" bash "${KDE_SH}" __probe__ 2>&1 || true)
assert_out "帶入 KDE_PATH 但那裡沒有 kde.env 時，訊息指出路徑" "沒有 kde.env"
assert_no_out "帶入 KDE_PATH 時也不叫人跑裸的 kde init" "請先執行 kde init"
echo ""

echo "--- -C 搭配 init：可在任意路徑初始化 ---"
FRESH="${TMP_ROOT}/fresh"
mkdir -p "${FRESH}"
run_kde_flag "${OUTSIDE}" -C "${FRESH}" init
assert_true "kde -C <dir> init 建出 kde.env" test -f "${FRESH}/kde.env"
assert_true "kde -C <dir> init 帶進 templates/init 的內容" test -f "${FRESH}/.gitignore"
assert_false "init 不會誤灌到 cwd" test -f "${OUTSIDE}/kde.env"
echo ""

echo "總測試數：${TOTAL}  通過：${PASS}  失敗：${FAIL}"
[[ ${FAIL} -eq 0 ]] && echo "🎉 全部通過" || { echo "❌ 有失敗"; exit 1; }
