#!/bin/bash
set -eo pipefail

# 測試 kde openclaw 的備份/還原與映像釘選（upgrade / downgrade）
#
# 這支測試刻意讓 tar 真的執行、檔案真的落地：備份與還原的價值全在檔案系統的
# 實際結果上，把 tar stub 掉就只是在測試自己寫的字串。只有 docker 用 stub。
#
# 本檔開了 set -eo pipefail，所以「取第一行」一律用 sed -n 1p 而不是 head -1：
# head 拿到想要的行就關閉管線，上游（tar、ls）於是收到 SIGPIPE 回傳 141，
# 被 pipefail 放大成整行失敗、再被 set -e 變成靜默中止。輸出夠小時上游剛好在
# head 關閉前寫完就不會觸發，所以它是偶發的——實測六次跑會中一次，
# 而中止時 FAIL 仍是 0，看起來像「測試沒跑完」而不是「測試失敗」。

echo "===== kde openclaw 備份/還原測試 ====="
echo ""

export KDE_PATH="/tmp/kde-test-openclaw-backup"
export KDE_CLI_PATH="${KDE_PATH}/cli"
export OPENCLAW_IMAGE="docker.io/r82wei/kde-openclaw:5e990b9-2026.8.2"
export OPENCLAW_HEALTH_WAIT=0

rm -rf "${KDE_PATH}"
mkdir -p "${KDE_PATH}/cli"

source "$(dirname "${BASH_SOURCE[0]}")/../scripts/utils/openclaw.sh"

stat_real=$(command -v stat)
stat() { echo "999"; }

HOME_DIR="${KDE_PATH}/.openclaw-home"
BACKUP_DIR="${KDE_PATH}/.openclaw-backups"
NAME="openclaw-kde-test-openclaw-backup"

# ---- docker stub ----
STUB_EXISTING=""; STUB_RUNNING=""; STUB_MODE="local"; STUB_AUTH_MODE="token"
STUB_INSPECT="true"; STUB_RESTARTS="0"; STUB_PORT_MAP="0.0.0.0:18789"
STUB_IMAGE_ID="sha256:oldoldold"; STUB_IMAGE_VERSION="2026.8.2"
STUB_IMAGE_ID_AFTER=""; STUB_IMAGE_VERSION_AFTER=""
STUB_PULL_FAIL=""; STUB_STOP_FAIL=""

DOCKER_LOG_FILE="${KDE_PATH}/docker.log"
: > "${DOCKER_LOG_FILE}"

docker() {
    echo "docker $*" >> "${DOCKER_LOG_FILE}"
    case "$1" in
        ps)
            if [[ "$*" == *"-a"* ]]; then
                [[ -n "${STUB_EXISTING}" ]] && echo "${STUB_EXISTING}"
            else
                [[ -n "${STUB_RUNNING}" ]] && echo "${STUB_RUNNING}"
            fi
            return 0 ;;
        run)
            if [[ "$*" == *"config get gateway.mode"* ]]; then echo "${STUB_MODE}"; fi
            if [[ "$*" == *"config get gateway.auth.mode"* ]]; then echo "${STUB_AUTH_MODE}"; fi
            return 0 ;;
        image)
            if [[ "$*" == *"Config.Labels"* ]]; then echo "${STUB_IMAGE_VERSION}"; else echo "${STUB_IMAGE_ID}"; fi
            return 0 ;;
        pull)
            if [[ "${STUB_PULL_FAIL}" == "true" ]]; then return 1; fi
            if [[ -n "${STUB_IMAGE_ID_AFTER}" ]]; then
                STUB_IMAGE_ID="${STUB_IMAGE_ID_AFTER}"
                STUB_IMAGE_VERSION="${STUB_IMAGE_VERSION_AFTER}"
            fi
            return 0 ;;
        port) echo "${STUB_PORT_MAP}"; return 0 ;;
        inspect) echo "${STUB_INSPECT} ${STUB_RESTARTS}"; return 0 ;;
        stop)
            if [[ "${STUB_STOP_FAIL}" == "true" ]]; then return 1; fi
            return 0 ;;
        rm)
            STUB_EXISTING=""; STUB_RUNNING=""
            return 0 ;;
        *) return 0 ;;
    esac
}

TOTAL=0; PASS=0; FAIL=0
check() { TOTAL=$((TOTAL+1)); if [[ "$2" -eq 0 ]]; then echo "✅ $1"; PASS=$((PASS+1)); else echo "❌ $1"; FAIL=$((FAIL+1)); fi; }
assert_true()  { local d="$1"; shift; if "$@" >/dev/null 2>&1; then check "$d" 0; else check "$d" 1; fi; }
assert_false() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then check "$d" 1; else check "$d" 0; fi; }
assert_eq()    { TOTAL=$((TOTAL+1)); if [[ "$3" == "$2" ]]; then echo "✅ $1：'$3'"; PASS=$((PASS+1)); else echo "❌ $1：預期 '$2'，實際 '$3'"; FAIL=$((FAIL+1)); fi; }
logged()  { grep -q -- "$1" "${DOCKER_LOG_FILE}"; }
out_has() { echo "${OUT}" | grep -q -- "$1"; }

# 造一份有內容的容器 home
seed_home() { # $1=標記字串
    rm -rf "${HOME_DIR}"
    mkdir -p "${HOME_DIR}/.openclaw/agents" "${HOME_DIR}/.codex"
    echo "$1" > "${HOME_DIR}/.openclaw/marker"
    echo "$1" > "${HOME_DIR}/.codex/creds"
    dd if=/dev/zero of="${HOME_DIR}/.openclaw/agents/db.sqlite" bs=1k count=8 2>/dev/null
}

reset_all() {
    rm -rf "${HOME_DIR}" "${BACKUP_DIR}" "${KDE_PATH}/.openclaw-image"
    : > "${DOCKER_LOG_FILE}"
    STUB_EXISTING=""; STUB_RUNNING=""; STUB_MODE="local"; STUB_INSPECT="true"; STUB_RESTARTS="0"
    STUB_IMAGE_ID="sha256:oldoldold"; STUB_IMAGE_VERSION="2026.8.2"
    STUB_IMAGE_ID_AFTER=""; STUB_IMAGE_VERSION_AFTER=""
    STUB_PULL_FAIL=""; STUB_STOP_FAIL=""; OUT=""
    OPENCLAW_PORT=18789; OPENCLAW_PORT_GIVEN=false; OPENCLAW_FORCE=false
    OPENCLAW_BACKUP_CHOICE=""; OPENCLAW_LIST=false
    export OPENCLAW_IMAGE="docker.io/r82wei/kde-openclaw:5e990b9-2026.8.2"
}

# ---------------------------------------------------------------------------
echo "--- 備份檔名與 manifest ---"
reset_all; seed_home "v1"
create_openclaw_backup >/dev/null 2>&1
mapfile -t files < <(ls -A "${BACKUP_DIR}" 2>/dev/null)
assert_eq "產生一份備份" "1" "${#files[@]}"
f="${BACKUP_DIR}/${files[0]}"

# 檔名要能讓人一眼看出對應哪個 image，時間戳讓多份備份可排序
case "${files[0]}" in
    openclaw-backup-*-r82wei_kde-openclaw_5e990b9-2026.8.2.tar.gz) check "檔名含清洗後的 image tag" 0 ;;
    *) check "檔名含清洗後的 image tag（實際 ${files[0]}）" 1 ;;
esac
if [[ "${files[0]}" =~ ^openclaw-backup-[0-9]{8}-[0-9]{6}- ]]; then
    check "檔名含 YYYYMMDD-HHMMSS 時間戳" 0
else
    check "檔名含 YYYYMMDD-HHMMSS 時間戳" 1
fi

# 檔名清洗過會失真（/ 與 : 都變成 _），無法反推原始 tag，
# 所以精確值一律從 manifest 讀——downgrade 靠它還原 image。
assert_eq "manifest 記錄完整 image" \
    "docker.io/r82wei/kde-openclaw:5e990b9-2026.8.2" \
    "$(read_openclaw_backup_manifest "${f}" OPENCLAW_BACKUP_IMAGE)"
assert_eq "manifest 記錄 image ID" "sha256:oldoldold" \
    "$(read_openclaw_backup_manifest "${f}" OPENCLAW_BACKUP_IMAGE_ID)"
assert_eq "manifest 記錄 openclaw 版本" "2026.8.2" \
    "$(read_openclaw_backup_manifest "${f}" OPENCLAW_BACKUP_VERSION)"
assert_true "manifest 記錄備份時間" test -n "$(read_openclaw_backup_manifest "${f}" OPENCLAW_BACKUP_AT)"

# manifest 放在 tar 的最前面，列表才不必解開整包（實測 147MB 級別的差別）
first_member=$(tar -tzf "${f}" | sed -n 1p)
assert_eq "manifest 位於 tar 最前面" "openclaw-backup-manifest" "${first_member}"
assert_true "備份含 home 內容" bash -c "tar -tzf '${f}' | grep -q '.openclaw-home/.openclaw/marker'"
echo ""

# ---------------------------------------------------------------------------
echo "--- 保留份數（預設 3）---"
reset_all; seed_home "v1"
mkdir -p "${BACKUP_DIR}"
# 造五份假備份，mtime 由舊到新
for i in 1 2 3 4 5; do
    fn="${BACKUP_DIR}/openclaw-backup-2026090${i}-000000-img.tar.gz"
    echo x > "${fn}"
    touch -d "2026-09-0${i} 00:00:00" "${fn}"
done
prune_openclaw_backups >/dev/null 2>&1
remaining=$(ls -A "${BACKUP_DIR}" | wc -l)
assert_eq "只留下 3 份" "3" "${remaining}"
assert_false "最舊的被刪除" test -f "${BACKUP_DIR}/openclaw-backup-20260901-000000-img.tar.gz"
assert_true  "最新的保留" test -f "${BACKUP_DIR}/openclaw-backup-20260905-000000-img.tar.gz"

reset_all; seed_home "v1"; mkdir -p "${BACKUP_DIR}"
for i in 1 2 3 4 5; do
    fn="${BACKUP_DIR}/openclaw-backup-2026090${i}-000000-img.tar.gz"
    echo x > "${fn}"; touch -d "2026-09-0${i} 00:00:00" "${fn}"
done
OPENCLAW_BACKUP_KEEP=2 prune_openclaw_backups >/dev/null 2>&1
assert_eq "份數可用 OPENCLAW_BACKUP_KEEP 調整" "2" "$(ls -A "${BACKUP_DIR}" | wc -l)"
echo ""

# ---------------------------------------------------------------------------
echo "--- 還原 ---"
reset_all; seed_home "old"
create_openclaw_backup >/dev/null 2>&1
backup_file="${BACKUP_DIR}/$(ls -A "${BACKUP_DIR}" | sed -n 1p)"
# 之後把 home 改成新內容，還原應該把它換回 old
seed_home "new"
echo "leftover" > "${HOME_DIR}/should-be-gone"

# 探針：一個 cwd 停在 .openclaw-home 的背景行程。
# 還原若用 rm -rf 目錄再重建，探針的 cwd 會變成 deleted——而 .openclaw-home 是
# named volume (local driver + o=bind) 綁著的路徑，那正是 cdb2e58 踩過的坑。
# 不比對 inode：實測過那是假守衛，ext4 會立刻重用剛釋放的 inode number。
( cd "${HOME_DIR}" && exec sleep 20 ) &
probe=$!
sleep 0.3

restore_openclaw_backup "${backup_file}" >/dev/null 2>&1

assert_eq "還原回備份當時的內容" "old" "$(cat "${HOME_DIR}/.openclaw/marker" 2>/dev/null)"
assert_false "還原會清掉備份中不存在的檔案" test -f "${HOME_DIR}/should-be-gone"
probe_cwd=$("${stat_real}" -c '%N' /proc/${probe}/cwd 2>/dev/null || readlink /proc/${probe}/cwd 2>/dev/null || echo "")
if [[ "${probe_cwd}" == *"(deleted)"* ]]; then
    check "還原保留目錄本身（未 rm -rf 再重建）" 1
else
    check "還原保留目錄本身（未 rm -rf 再重建）" 0
fi
kill ${probe} 2>/dev/null || true
assert_false "還原不把 manifest 留在 home 裡" test -f "${HOME_DIR}/../openclaw-backup-manifest"
assert_false "還原不把 manifest 留進 home" test -f "${HOME_DIR}/openclaw-backup-manifest"
echo ""

# ---------------------------------------------------------------------------
echo "--- 映像釘選 (pin) ---"
reset_all
assert_eq "預設沒有 pin" "" "$(read_openclaw_image_pin)"

write_openclaw_image_pin "docker.io/r82wei/kde-openclaw:pinned-1"
assert_eq "寫入後讀得到" "docker.io/r82wei/kde-openclaw:pinned-1" "$(read_openclaw_image_pin)"
assert_true "pin 檔以 .openclaw 開頭（會被 /.openclaw* 忽略）" test -f "${KDE_PATH}/.openclaw-image"

# run/restart 要遵守 pin，否則 downgrade 之後一次 restart 就跳回新版
OPENCLAW_ACTION=run
apply_openclaw_image_pin >/dev/null 2>&1
assert_eq "run 套用 pin" "docker.io/r82wei/kde-openclaw:pinned-1" "${OPENCLAW_IMAGE}"

reset_all
write_openclaw_image_pin "docker.io/r82wei/kde-openclaw:pinned-1"
OPENCLAW_ACTION=run
OUT=$(apply_openclaw_image_pin 2>&1 || true)
assert_true "套用 pin 時明確告知（否則是無聲的版本歪掉）" out_has "pinned-1"

# upgrade 的語意是「回到 kde.env 指定的映像的最新版」，所以它不吃 pin
reset_all
write_openclaw_image_pin "docker.io/r82wei/kde-openclaw:pinned-1"
OPENCLAW_ACTION=upgrade
apply_openclaw_image_pin >/dev/null 2>&1
assert_eq "upgrade 不套用 pin" "docker.io/r82wei/kde-openclaw:5e990b9-2026.8.2" "${OPENCLAW_IMAGE}"

clear_openclaw_image_pin
assert_eq "清除後讀不到" "" "$(read_openclaw_image_pin)"
assert_false "清除後 pin 檔不存在" test -f "${KDE_PATH}/.openclaw-image"
echo ""

# ---------------------------------------------------------------------------
echo "--- upgrade 的備份時機 ---"
# 備份要在 stop 之後、新版啟動之前：那時沒有行程在寫 sqlite。
# 容器還在跑時打包 sqlite + WAL 會拿到不一致的快照，而問題要到還原那天才浮現。
reset_all; seed_home "v1"
STUB_EXISTING="${NAME}"; STUB_RUNNING="${NAME}"
STUB_IMAGE_ID_AFTER="sha256:newnewnew"; STUB_IMAGE_VERSION_AFTER="2026.9.1"
upgrade_openclaw >/dev/null 2>&1
assert_eq "有新版時產生一份備份" "1" "$(ls -A "${BACKUP_DIR}" 2>/dev/null | wc -l)"
# 備份的 image 必須是「舊的那個」——備份對應的是被換掉的那一版
bf="${BACKUP_DIR}/$(ls -A "${BACKUP_DIR}" | sed -n 1p)"
assert_eq "備份記錄的是換掉前的版本" "2026.8.2" \
    "$(read_openclaw_backup_manifest "${bf}" OPENCLAW_BACKUP_VERSION)"

reset_all; seed_home "v1"
STUB_EXISTING="${NAME}"; STUB_RUNNING="${NAME}"
STUB_PULL_FAIL=true
upgrade_openclaw >/dev/null 2>&1 || true
assert_eq "pull 失敗不備份" "0" "$(ls -A "${BACKUP_DIR}" 2>/dev/null | wc -l)"

reset_all; seed_home "v1"
STUB_EXISTING="${NAME}"; STUB_RUNNING="${NAME}"
upgrade_openclaw >/dev/null 2>&1
assert_eq "已是最新版不備份" "0" "$(ls -A "${BACKUP_DIR}" 2>/dev/null | wc -l)"

# upgrade 成功要放開 pin，讓 downgrade/upgrade 對稱
reset_all; seed_home "v1"
write_openclaw_image_pin "docker.io/r82wei/kde-openclaw:pinned-1"
STUB_EXISTING="${NAME}"; STUB_RUNNING="${NAME}"
STUB_IMAGE_ID_AFTER="sha256:newnewnew"; STUB_IMAGE_VERSION_AFTER="2026.9.1"
upgrade_openclaw >/dev/null 2>&1
assert_eq "upgrade 成功後清除 pin" "" "$(read_openclaw_image_pin)"
echo ""

# ---------------------------------------------------------------------------
echo "--- downgrade ---"
# 造兩份可選的備份
prepare_two_backups() {
    reset_all; seed_home "first"
    export OPENCLAW_IMAGE="docker.io/r82wei/kde-openclaw:aaa-2026.8.1"
    STUB_IMAGE_VERSION="2026.8.1"
    create_openclaw_backup >/dev/null 2>&1
    sleep 1.1   # 讓兩份的時間戳不同，排序才有意義
    seed_home "second"
    export OPENCLAW_IMAGE="docker.io/r82wei/kde-openclaw:bbb-2026.8.2"
    STUB_IMAGE_VERSION="2026.8.2"
    create_openclaw_backup >/dev/null 2>&1
    seed_home "current"
    : > "${DOCKER_LOG_FILE}"
    STUB_EXISTING="${NAME}"; STUB_RUNNING="${NAME}"; STUB_MODE="local"
}

prepare_two_backups
OPENCLAW_LIST=true
OUT=$(downgrade_openclaw 2>&1 || true)
assert_true  "--list 列出兩份備份的版本" out_has "2026.8.1"
assert_true  "--list 也列出另一份" out_has "2026.8.2"
assert_false "--list 不動容器" logged "stop ${NAME}"
assert_eq    "--list 不改動 home" "current" "$(cat "${HOME_DIR}/.openclaw/marker")"

# 指定編號還原：1 是最舊的那份
prepare_two_backups
OPENCLAW_LIST=false; OPENCLAW_BACKUP_CHOICE=1; OPENCLAW_FORCE=true
downgrade_openclaw >/dev/null 2>&1
assert_eq "還原指定的備份內容" "first" "$(cat "${HOME_DIR}/.openclaw/marker" 2>/dev/null)"
assert_eq "寫入該備份對應的 image pin" "docker.io/r82wei/kde-openclaw:aaa-2026.8.1" "$(read_openclaw_image_pin)"
assert_true "還原後啟動容器" logged "gateway run"
assert_true "還原前先停止容器" logged "stop ${NAME}"

# downgrade 會覆蓋現有資料，不先備份的話它自己就不可逆
prepare_two_backups
before=$(ls -A "${BACKUP_DIR}" | wc -l)
OPENCLAW_LIST=false; OPENCLAW_BACKUP_CHOICE=1; OPENCLAW_FORCE=true
downgrade_openclaw >/dev/null 2>&1
after=$(ls -A "${BACKUP_DIR}" | wc -l)
if [[ "${after}" -gt "${before}" ]]; then check "downgrade 前先備份現有狀態" 0; else check "downgrade 前先備份現有狀態（${before} → ${after}）" 1; fi

# 編號錯誤要明確報錯，不能靜默還原錯的那份
prepare_two_backups
OPENCLAW_LIST=false; OPENCLAW_BACKUP_CHOICE=99; OPENCLAW_FORCE=true
assert_false "編號超出範圍時報錯" downgrade_openclaw
assert_eq "報錯時不動 home" "current" "$(cat "${HOME_DIR}/.openclaw/marker")"

prepare_two_backups
OPENCLAW_LIST=false; OPENCLAW_BACKUP_CHOICE=abc; OPENCLAW_FORCE=true
assert_false "非數字編號報錯" downgrade_openclaw

# 沒有任何備份時要說清楚，而不是拋出 tar 的錯誤
reset_all; seed_home "current"
STUB_RUNNING="${NAME}"; OPENCLAW_LIST=false; OPENCLAW_BACKUP_CHOICE=1; OPENCLAW_FORCE=true
assert_false "沒有備份可還原時報錯" downgrade_openclaw
echo ""

# ---------------------------------------------------------------------------
rm -rf "${KDE_PATH}"

echo "===== 測試結果 ====="
echo "總計: ${TOTAL}, 通過: ${PASS}, 失敗: ${FAIL}"
if [[ ${FAIL} -gt 0 ]]; then exit 1; fi
echo "✓ 全部通過"
