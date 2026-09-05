#!/bin/bash

# kde openclaw 子命令的實作邏輯。
#
# 注意：本檔會被 scripts/openclaw/command.sh source，而該檔又被 kde.sh source，
# kde.sh 開了 set -eo pipefail，因此所有可能回傳非零的呼叫都必須用 `|| rc=$?`
# 或包在 if 條件中承接，不可裸呼叫。

# gateway 對外發布 port 的內建預設值。
# 刻意不寫進 kde.env：kde.env 是版控檔案，會隨 workspace 同步到每個人的機器上，
# 而 port 是每台開發機各自的環境條件，同步只會互相干擾。
OPENCLAW_PORT_DEFAULT=18789

# log 預設顯示的行數。與 run 健康檢查用的 50 行刻意分開：
# 那是失敗時的自動摘要，這是使用者主動查閱，看得多一點比較有用。
OPENCLAW_TAIL_DEFAULT=100

# 容器內 OpenClaw 使用者的 home。官方映像的使用者是 node（uid 1000），
# 只有 uid/gid 會隨 PUID/PGID 變動，路徑本身固定。
OPENCLAW_CONTAINER_HOME=/home/node

# upgrade 換版本時自動保留的備份份數。每份是整個 .openclaw-home 的壓縮包
# （實測 374MB 的 home 壓縮後 147MB、耗時約 9 秒），所以刻意有上限而不是無限累積。
OPENCLAW_BACKUP_KEEP_DEFAULT=3

# 備份包內描述檔的名稱。它記錄該備份對應的 image，是 downgrade 還原版本的依據
# ——檔名裡的 tag 經過清洗（/ 與 : 都變 _），無法反推原始值。
#
# 備份檔與這個描述檔刻意「不」以 . 開頭：外層目錄 .openclaw-backups 已經落在
# .gitignore 的 /.openclaw* 規則裡，裡面再隱藏一次只會讓使用者用 ls 看不到
# 數百 MB 的佔用（ls 預設不列隱藏檔）。
OPENCLAW_BACKUP_MANIFEST_NAME=openclaw-backup-manifest

# 顯示 kde openclaw 的使用說明
show_openclaw_help() {
    echo "usage: kde openclaw <action> [option]"
    echo ""
    echo "action:"
    echo "  run     [-p port]               背景常駐啟動 OpenClaw gateway"
    echo "  onboard [-f]                    執行初始化精靈 (一次性互動容器，不需 gateway 已啟動)"
    echo "  stop                            停止並移除 gateway 容器"
    echo "  restart [-p port]               先 stop 再 run (未指定 port 時沿用現有容器的 port)"
    echo "  backup  [-f]                    手動備份 .openclaw-home (會短暫停止容器)"
    echo "  upgrade [-p port]               拉取映像的最新版本，映像真的變了才重啟容器"
    echo "  downgrade [<n>] [--list] [-f]   從備份還原資料與映像版本 (不改 kde.env)"
    echo "  tui                             互動進入 openclaw TUI"
    echo "  exec    [<cmd>]                 進入容器的 bash；帶指令則非互動執行 (指令含空白請用引號包起來)"
    echo "  log     [-f] [--tail <n>]       查看 gateway 容器日誌 (預設最後 ${OPENCLAW_TAIL_DEFAULT} 行，不跟隨)"
    echo "  token                           印出 gateway 的 auth token (僅 token 本身，可被管線接走)"
    echo "  dashboard [--json]              鑄一次性的 owner 配對連結，用於瀏覽器首次連上 dashboard"
    echo "  reset   [-f]                    刪除 workspace 的 .openclaw (容器運行中則拒絕)"
    echo ""
    echo "option:"
    echo "  -p, --port      gateway 對外發布的 port (預設 ${OPENCLAW_PORT_DEFAULT}，亦可用環境變數 OPENCLAW_PORT)"
    echo "  -f, --force     略過確認提示 (onboard、reset)"
    echo "  -f, --follow    跟隨日誌輸出 (log)"
    echo "      --tail <n>  log 顯示的行數 (預設 ${OPENCLAW_TAIL_DEFAULT})"
    echo "      --command   exec 時執行指定指令 (不配置 TTY，等同直接寫成位置參數)"
    echo "      --json      dashboard 時輸出原始 JSON 而非人類可讀的指引"
    echo "  -h, --help      顯示此幫助訊息"
}

# 解析 kde openclaw 的參數，結果回填到 OPENCLAW_* 全域變數
# 回傳 0=成功、1=參數錯誤、2=已顯示說明應結束
parse_openclaw_args() {
    OPENCLAW_ACTION=""
    # 使用者是否明確表態過 port（-p 旗標或環境變數 OPENCLAW_PORT）。
    # 必須在套用內建預設「之前」判斷：套完之後 OPENCLAW_PORT=18789 有三個可能
    # 來源（-p 18789、環境變數 18789、什麼都沒給），單看值完全分不出來。
    # restart 需要這個區別——沒表態時它要沿用現有容器的 port 而不是退回預設，
    # 但明確打的 -p 18789 必須勝出。此旗標純粹是 parse 期的記憶體變數，
    # 與 OPENCLAW_PORT 一樣不寫進 kde.env。
    if [[ -n "${OPENCLAW_PORT}" ]]; then
        OPENCLAW_PORT_GIVEN=true
    else
        OPENCLAW_PORT_GIVEN=false
    fi
    # 環境變數有值就沿用，否則套用內建預設；-p 會在下面覆寫
    OPENCLAW_PORT="${OPENCLAW_PORT:-${OPENCLAW_PORT_DEFAULT}}"
    OPENCLAW_FORCE=false
    OPENCLAW_COMMAND=""
    OPENCLAW_FOLLOW=false
    OPENCLAW_TAIL="${OPENCLAW_TAIL_DEFAULT}"
    OPENCLAW_JSON=false
    OPENCLAW_LIST=false
    OPENCLAW_BACKUP_CHOICE=""

    if [[ $# -eq 0 ]]; then
        show_openclaw_help
        return 2
    fi

    case "$1" in
        -h|--help)
            show_openclaw_help
            return 2
            ;;
        run|onboard|stop|restart|backup|upgrade|downgrade|tui|exec|log|token|dashboard|reset)
            OPENCLAW_ACTION="$1"
            shift
            ;;
        *)
            echo "未知的 action：$1" >&2
            show_openclaw_help >&2
            return 1
            ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --port|-p)
                OPENCLAW_PORT="$2"
                if [[ -z "${OPENCLAW_PORT}" || ! ${OPENCLAW_PORT} =~ ^[0-9]+$ ]]; then
                    echo "無效的 port：$2" >&2
                    return 1
                fi
                OPENCLAW_PORT_GIVEN=true
                shift 2
                ;;
            # -f 依 action 分流：對 onboard/reset 是「略過確認」，對 log 是「跟隨」。
            # 這兩件事不可能同時適用於同一個 action（log 沒有確認提示可略過，
            # onboard/reset 也沒有日誌可跟隨），所以共用 -f 不會產生歧義；
            # 要明確表達時仍有 --force / --follow 兩個長旗標。
            --force)
                OPENCLAW_FORCE=true
                shift
                ;;
            --follow)
                OPENCLAW_FOLLOW=true
                shift
                ;;
            -f)
                if [[ "${OPENCLAW_ACTION}" == "log" ]]; then
                    OPENCLAW_FOLLOW=true
                else
                    OPENCLAW_FORCE=true
                fi
                shift
                ;;
            --tail)
                OPENCLAW_TAIL="$2"
                if [[ -z "${OPENCLAW_TAIL}" || ! ${OPENCLAW_TAIL} =~ ^[0-9]+$ ]]; then
                    echo "無效的 tail 行數：$2" >&2
                    return 1
                fi
                shift 2
                ;;
            --json)
                OPENCLAW_JSON=true
                shift
                ;;
            --list)
                OPENCLAW_LIST=true
                shift
                ;;
            --command)
                if [[ -z "$2" ]]; then
                    echo "錯誤：--command 需要一個指令參數" >&2
                    return 1
                fi
                if [[ -n "${OPENCLAW_COMMAND}" ]]; then
                    echo "❌ 錯誤：指令只能指定一次 (--command 與位置參數擇一)" >&2
                    return 1
                fi
                OPENCLAW_COMMAND="$2"
                shift 2
                ;;
            --help|-h)
                show_openclaw_help
                return 2
                ;;
            *)
                # 位置參數只有 exec 收：exec 就是 bash，指令原封不動交給 bash -c，
                # 所以 `kde openclaw exec "openclaw dashboard"` 打的字跟容器裡實際
                # 跑的一致，不必為了跑 openclaw 的子指令把 openclaw 這個字拿掉。
                # 其他 action 一律報錯，錯字不會被靜默吃掉。
                # 開頭是 - 的一律當未知旗標，否則 `exec -x` 會被誤收成指令。
                # downgrade 的位置參數是備份編號。給了就不互動詢問，
                # 讓它能寫進腳本；沒給才進互動選單。
                if [[ "${OPENCLAW_ACTION}" == "downgrade" && "$1" != -* ]]; then
                    if [[ -n "${OPENCLAW_BACKUP_CHOICE}" ]]; then
                        echo "❌ 錯誤：備份編號只能指定一次" >&2
                        return 1
                    fi
                    OPENCLAW_BACKUP_CHOICE="$1"
                    shift
                elif [[ "${OPENCLAW_ACTION}" == "exec" && "$1" != -* ]]; then
                    if [[ -n "${OPENCLAW_COMMAND}" ]]; then
                        echo "❌ 錯誤：指令只能指定一次 (--command 與位置參數擇一)" >&2
                        echo "   含空白的指令請用引號包成一個參數，例如：kde openclaw exec \"ls -la\"" >&2
                        return 1
                    fi
                    OPENCLAW_COMMAND="$1"
                    shift
                else
                    echo "未知參數：$1" >&2
                    show_openclaw_help >&2
                    return 1
                fi
                ;;
        esac
    done

    return 0
}

# 由 KDE_PATH 的 basename 推導容器名稱
# 非 [a-zA-Z0-9_.-] 的字元一律換成 -，避免目錄名含空白時 docker run --name 失敗
get_openclaw_container_name() {
    local ws
    ws=$(basename "${KDE_PATH}")
    ws=$(echo "${ws}" | sed 's/[^a-zA-Z0-9_.-]/-/g')
    echo "openclaw-${ws}"
}

# 容器 home 用的 named volume 名稱，與容器同樣由 workspace 推導
get_openclaw_home_volume_name() {
    echo "$(get_openclaw_container_name)-home"
}

# 確保容器 home 的 named volume 存在。
#
# 用 local driver + o=bind 指向 ${KDE_PATH}/.openclaw-home，而不是直接 bind mount
# 該目錄：兩者的內容都落在同一個主機路徑，差別在於 named volume 在首次掛載
# （目錄為空）時，Docker 會把映像裡 /home/node 的內容預先複製進去。直接 bind
# mount 一個空目錄則會把映像原有內容整個遮蔽掉——包括 .bashrc/.profile，以及
# 未來版本可能烤進 home 的東西（映像已設 PLAYWRIGHT_BROWSERS_PATH 指向
# ~/.cache/ms-playwright），那會變成安靜失效而不是明確錯誤。
#
# 但書：預先複製只在目錄為空時發生一次。既有 workspace 升級 base image 時，
# 新版映像新增在 home 的內容不會被補進來（這是 Docker named volume 的既定行為，
# 官方的 OPENCLAW_HOME_VOLUME 做法亦同）。
# docker volume create 本身是冪等的（同名已存在時直接回傳成功），
# 所以不需要先 inspect 再決定要不要建。
ensure_openclaw_home_volume() {
    mkdir -p "${KDE_PATH}/.openclaw-home"
    docker volume create --driver local \
        --opt type=none \
        --opt "device=${KDE_PATH}/.openclaw-home" \
        --opt o=bind \
        "$(get_openclaw_home_volume_name)" >/dev/null
}

# 確認 OPENCLAW_IMAGE 真的能用：本機有就直接過，沒有才嘗試 pull。
#
# 為什麼需要一道獨立的前置檢查：所有 action 的第一步都是在一次性容器裡讀
# gateway.mode，而那個讀取把 docker 的 stderr 丟掉（見 get_openclaw_config）。
# 映像不存在時 docker 連容器都建不起來、輸出是空的，於是「讀不到設定」被誤判成
# 「gateway.mode 不是 local」，畫面上變成「OpenClaw 尚未初始化，請先 onboard」——
# 一個完全指錯方向的診斷：照著跑 onboard 會用同一個壞映像再失敗一次，而
# onboard -f 甚至會覆寫掉本來好好的設定。實際踩過（kde.env 的 OPENCLAW_IMAGE
# 打成不存在的 tag，症狀就是這句「尚未初始化」）。
#
# 本機已有就不 pull：那是 upgrade 的職責。每個 action 都打 registry 會讓離線環境
# 直接不能用，也讓每次操作多一次網路往返。
ensure_openclaw_image_available() {
    if docker image inspect "${OPENCLAW_IMAGE}" >/dev/null 2>&1; then
        return 0
    fi

    echo "↓ 本機沒有 ${OPENCLAW_IMAGE}，嘗試拉取 ..." >&2
    if docker pull "${OPENCLAW_IMAGE}" >&2; then
        return 0
    fi

    echo "❌ 取得映像失敗：${OPENCLAW_IMAGE}" >&2
    echo "   本機沒有這個映像，registry 也拉不到" >&2
    echo "   （tag 打錯，或那是只在別台機器上 build 過、從未推上 registry 的映像）" >&2
    echo "   設定來源：$(describe_openclaw_image_source)" >&2
    return 1
}

# 映像設定到底來自哪個檔案。釘選檔會蓋掉 kde.env，只講其中一個會讓人改錯地方。
describe_openclaw_image_source() {
    local pin_file
    pin_file=$(get_openclaw_image_pin_file)
    if [[ -f "${pin_file}" ]]; then
        echo "${pin_file}（映像釘選，覆蓋 kde.env；kde openclaw upgrade 可解除）"
    else
        echo "${KDE_ENV_FILE:-${KDE_PATH}/kde.env} 的 OPENCLAW_IMAGE"
    fi
}

# 組出三種容器（狀態檢查、onboard、gateway）共用的 docker run 參數。
# bash 陣列無法用回傳值傳遞，結果放在全域陣列 OPENCLAW_DOCKER_ARGS。
#
# 只放三者都需要的東西：掛載、身分、工作目錄。
# port、-d/-it、--name、--restart 由各 action 自行附加。
build_openclaw_docker_args() {
    ensure_openclaw_image_available || return 1
    ensure_openclaw_home_volume

    # docker.sock 的 gid，用來 --group-add 讓容器內能操作 Docker。
    # 取法與 scripts/utils/code-server.sh 一致：Linux 用 stat -c，macOS 退回 stat -f。
    local sock_gid
    sock_gid=$( (stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock 2>/dev/null) ) || true

    local puid="${PUID:-$(id -u)}"
    local pgid="${PGID:-$(id -g)}"

    OPENCLAW_DOCKER_ARGS=(
        --workdir "${KDE_PATH}"
        -e "PUID=${puid}"
        -e "PGID=${pgid}"
        # --workdir 只決定容器的「起始」cwd，管不到之後 cd 走的行程。OpenClaw agent
        # 執行工具時的 cwd 是它自己的 workspace（~/.openclaw/workspace，即
        # agents.defaults.workspace），在那裡跑 kde 只會得到「kde.env 不存在，請先
        # 執行 kde init」—— 而 kde init 是 touch kde.env + cp -r templates/init/.，
        # 照做等於把整套 workspace 模板灌進 agent 自己的家目錄。
        #
        # 帶入 KDE_PATH 讓 kde 在任何 cwd 下都指向掛進來的那個 workspace
        # （kde.sh 優先採用帶入值，只在缺席時才由 $PWD 往上找 kde.env）。
        # 這刻意不改 agents.defaults.workspace：那個目錄同時是 agent 的「家」——
        # AGENTS.md、SOUL.md、USER.md、memory/ 與它自己的 .git 都在裡面，指到
        # KDE workspace 會把這些全部倒進使用者版控的目錄。
        -e "KDE_PATH=${KDE_PATH}"
        # workspace 以相同絕對路徑掛入，容器內外路徑一致
        -v "${KDE_PATH}:${KDE_PATH}"
        # 掛「整個容器 home」而非只掛 ~/.openclaw。
        #
        # OpenClaw 的狀態並不只在 ~/.openclaw：codex 憑證在 ~/.codex、hermes 在
        # ~/.hermes、Claude CLI 整合要 ~/.claude、~/.claude.json 與
        # ~/.local/share/claude、legacy OAuth 的加密金鑰在 ~/.config/openclaw、
        # 個人 skills 在 ~/.agents，另有 ~/.npm 與 ~/.cache。逐個用環境變數覆寫
        # (CODEX_HOME、HERMES_HOME、CLAUDE_CONFIG_DIR、GEMINI_CLI_HOME…) 是追不完的:
        # 每新增一個 provider plugin 就要再補一行，且硬寫路徑、未提供覆寫的 plugin
        # 根本救不了。
        #
        # 官方 docker 指引本身就是這個做法 (OPENCLAW_HOME_VOLUME 持久化整個
        # /home/node，其 compose 範例即 ./openclaw-home -> /home/node)，理由相同。
        # 這樣 ~/.openclaw 自然位於 ${KDE_PATH}/.openclaw-home/.openclaw。
        -v "$(get_openclaw_home_volume_name):${OPENCLAW_CONTAINER_HOME}"
        -v "${KDE_CLI_PATH}:/usr/local/lib/kde:ro"
        -v /var/run/docker.sock:/var/run/docker.sock:ro
    )

    if [[ -n "${sock_gid}" ]]; then
        OPENCLAW_DOCKER_ARGS+=(--group-add "${sock_gid}")
    fi

    # CLI 自帶的 skill（目前是 kde-usage）以唯讀掛進 OpenClaw 會掃的 skill 根目錄，
    # 讓 agent 一啟動就懂 kde 指令，不必事先手動安裝任何東西。
    #
    # 為什麼是掛載而不是複製進容器 home：skill 內容講的是 kde 的旗標與流程，
    # 跟 CLI 版本強耦合。複製一份進去，CLI 一升級那份就過期，而且沒有任何機制
    # 會告知 —— 後果是 agent 拿過期旗標去操作叢集。掛載讓它永遠等於主機端掛進來
    # 的那份 CLI，與 /usr/local/lib/kde 只信掛載、刻意不內建副本的理由完全相同
    # （見 dockerfiles/kde-openclaw/kde-wrapper.sh 的檔頭）。
    #
    # 為什麼是 ~/.agents/skills 而不是 ~/.openclaw/skills：兩者都是 OpenClaw 會掃的
    # 全域 skill 根目錄（source 分別為 agents-skills-personal 與 openclaw-managed），
    # 對所有 agent 一樣可見，差別在後者是 OpenClaw 自己管的目錄 ——
    # openclaw skills install --global 的安裝目標、update/uninstall 的操作對象。
    # 把唯讀掛載點放進那裡，那些指令碰到它就會失敗。~/.agents/skills 不被 OpenClaw
    # 的 skill 管理指令碰，且該目錄本身仍可寫，使用者要放自己的 personal skill 不受影響。
    #
    # 但書：agents-skills-personal 這個 source 只在 OPENCLAW_STATE_DIR 未被覆寫
    # （OpenClaw 的 isDefaultStateDir()）時才載入。kde openclaw 不設那個變數，
    # 所以成立；哪天要設，這個掛載就會安靜失效。
    #
    # 唯讀：容器沒有任何理由改寫主機端的 CLI 安裝內容。
    #
    # 掛哪些目錄是「掃出來」的，不寫死 kde-usage：寫死的話，資料夾一改名、或日後
    # 在 .claude/skills 下新增第二個 skill，都會變成 skill 靜默不見/靜默漏掉，而
    # 唯一的線索是使用者自己發現 agent 不懂 kde 指令。掃 */SKILL.md 讓改名與新增
    # 都自動生效，也自然排除 kde-usage-workspace 那種沒有頂層 SKILL.md 的
    # skill 開發/eval 資料目錄（掛進去只是讓 OpenClaw 白掃一趟）。
    #
    # .openclaw-home 為空時整段不做：那代表 home volume 還沒被掛載過，Docker 會在
    # 首次掛載時把映像的 /home/node 預先複製進來，而預先複製只在目錄為空時發生
    # （見 ensure_openclaw_home_volume 的註解）—— 先在裡面建掛載點會讓它整個不發生。
    # 錯過的只有「第一個一次性狀態檢查容器」：它跑完 home 就被填充，同一次
    # run/onboard 接下來真正要用的容器（onboard 精靈、gateway）就都帶上掛載了。
    # 這是正常的一次性狀態，故此處不警告。
    local skills_root="${KDE_CLI_PATH}/.claude/skills"
    local home_dir="${KDE_PATH}/.openclaw-home"
    if [[ -n "$(ls -A "${home_dir}" 2>/dev/null)" ]]; then
        local skill_md skill_dir skill_name
        local mounted=false
        # 無匹配時 glob 保持字面值，靠 -f 過濾，不需要 nullglob
        for skill_md in "${skills_root}"/*/SKILL.md; do
            [[ -f "${skill_md}" ]] || continue
            skill_dir=$(dirname "${skill_md}")
            skill_name=$(basename "${skill_dir}")
            # 掛載點刻意由主機端先建好，不讓 Docker 代建：Docker 建的掛載點屬 root
            # （發生在 entrypoint 降權之前），而它落在 .openclaw-home 裡面 ——
            # kde openclaw reset 是以主機使用者 rm -rf 整個 .openclaw-home，遇到 root
            # 所有的中間目錄會「拒絕不符權限的操作」而刪不掉（實測確認）。由主機端建立
            # 則屬使用者本人，reset 刪得掉，使用者也仍能把自己的 personal skill
            # 放進 ~/.agents/skills。
            mkdir -p "${home_dir}/.agents/skills/${skill_name}"
            OPENCLAW_DOCKER_ARGS+=(
                -v "${skill_dir}:${OPENCLAW_CONTAINER_HOME}/.agents/skills/${skill_name}:ro"
            )
            mounted=true
        done
        # 一個都掃不到代表 CLI 安裝不完整（例如 local-install.sh 不再複製 .claude）。
        # 刻意出聲：靜默失效的症狀是「agent 突然不懂 kde 指令」，從那裡回推到這裡太遠。
        if [[ "${mounted}" != "true" ]]; then
            echo "⚠️  ${skills_root} 底下找不到任何 SKILL.md，OpenClaw agent 不會有 kde skill" >&2
        fi
    fi
}

# 容器是否存在（含已停止者）
is_openclaw_container_exist() {
    if docker ps -a --format '{{.Names}}' | grep -qx "$(get_openclaw_container_name)"; then
        echo "true"
    else
        echo "false"
    fi
}

# 容器是否正在運行
is_openclaw_container_running() {
    if docker ps --format '{{.Names}}' | grep -qx "$(get_openclaw_container_name)"; then
        echo "true"
    else
        echo "false"
    fi
}

# OpenClaw 是否已完成初始化。
#
# 判斷方式是在一次性容器內問 OpenClaw 自己「gateway.mode 是什麼」，
# 而不是看 .openclaw 目錄存不存在或是否為空。理由：
#   1. bind mount 會讓 Docker 自動建立不存在的 host 目錄，跑過任何一次 action
#      之後目錄必然存在，「存在與否」完全沒有鑑別力。
#   2. 目錄非空也不代表可用——onboarding 中途 Ctrl-C 會留下半成品 config，
#      gateway run 依然會拒絕啟動。
# gateway.mode=local 正是 openclaw gateway run 唯一在意的條件。
# 回傳 true / false / unknown。unknown 代表「問不到」而非「沒初始化」——
# 呼叫端要把它當成錯誤直接中止，不可退化成 false 去建議使用者跑 onboard。
is_openclaw_onboarded() {
    local mode rc=0
    mode=$(get_openclaw_config gateway.mode) || rc=$?
    if [[ ${rc} -ne 0 ]]; then
        echo "unknown"
        return 0
    fi
    if [[ "${mode}" == "local" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# 在一次性無 TTY 容器內讀取單一設定值，讀不到時回傳空字串。
# 這是唯一一處直接問 OpenClaw 設定的地方，其他函式都經由它取值。
#
# 回傳值分兩種情形，呼叫端必須分得出來：
#   0 + 空字串 = 容器跑起來了，但沒有這個設定值（真的沒初始化）
#   非 0       = 連容器都跑不起來（映像取不到），原因已由
#                ensure_openclaw_image_available 印在 stderr
# 兩者混為一談正是「映像 tag 打錯卻被告知去跑 onboard」的成因。
get_openclaw_config() {
    build_openclaw_docker_args || return 1
    docker run --rm "${OPENCLAW_DOCKER_ARGS[@]}" "${OPENCLAW_IMAGE}" \
        openclaw config get "$1" 2>/dev/null | tr -d '[:space:]' || true
}

# 執行初始化精靈。走一次性互動容器，不依賴 gateway 已在運行——
# 未初始化時 gateway run 會拒絕啟動，若要求使用者先 run 就會變成死結。
onboard_openclaw() {
    local name onboard_name
    name=$(get_openclaw_container_name)
    onboard_name="${name}-onboard"

    if docker ps -a --format '{{.Names}}' | grep -qx "${onboard_name}"; then
        echo "❌ 容器 ${onboard_name} 已存在，請先移除：docker rm -f ${onboard_name}"
        return 1
    fi

    if [[ "$(is_openclaw_onboarded)" == "true" && "${OPENCLAW_FORCE}" != "true" ]]; then
        echo "⚠️  OpenClaw 已初始化，重跑精靈會覆寫現有設定"
        read -p "確定要繼續嗎？(y/n) " answer
        if [[ "${answer}" != "y" ]]; then
            echo "已取消"
            return 0
        fi
    fi

    build_openclaw_docker_args || return 1
    # --agent-name main 是刻意釘住的，不是預設值的複述：帶了它，精靈就不會問
    # 「What should we call your first agent?」，而那一題填非 main 的名字會壞掉。
    #
    # 實測（OpenClaw 2026.8.2，互動精靈）：填 MaximeDev 時精靈確實建立了 agent
    # maximedev，並把 provider 的 OAuth 憑證寫進該 agent 自己的
    # agents/maximedev/agent/openclaw-agent.sqlite 的 auth_profile_store，
    # 但最後一次寫 config 時把 agents.entries 整段蓋掉了（三份備份都沒有它）。
    # roster 於是退回隱含的預設 agent main，而 main 的 auth store 是空的 ——
    # gateway 跑的是 main，聊天時就打出不帶 Authorization header 的請求，得到
    # 「401 Missing bearer or basic authentication in header」。
    # openclaw doctor 會把它報成「agent directory on disk without a matching
    # agents.list entry」。名字保留 main 時，即使 entries 同樣被蓋掉也無害：
    # 共用 auth store 的正規位置本來就是 agents/main（其他 agent 靠
    # agents.defaults.authInheritance 繼承它），而隱含的預設 agent 剛好是 main。
    #
    # 代價是不能在精靈裡命名第一個 agent，事後仍可用
    # openclaw agents set-identity / openclaw agents add 處理。
    #
    # 精靈被 Ctrl-C 中斷會回傳非零，不當成錯誤：下面統一以 gateway.mode 驗證結果
    docker run -it --rm --name "${onboard_name}" \
        "${OPENCLAW_DOCKER_ARGS[@]}" \
        "${OPENCLAW_IMAGE}" \
        openclaw onboard --mode local --agent-name main || true

    if [[ "$(is_openclaw_onboarded)" != "true" ]]; then
        echo "❌ 初始化未完成 (gateway.mode 仍不是 local)"
        return 1
    fi

    echo "✓ OpenClaw 初始化完成，可執行：kde openclaw run"
}

# 背景常駐啟動 gateway
run_openclaw_gateway() {
    local name
    name=$(get_openclaw_container_name)

    if [[ "$(is_openclaw_container_exist)" == "true" ]]; then
        echo "❌ 容器 ${name} 已存在，請先停止：kde openclaw stop"
        return 1
    fi

    local onboarded
    onboarded=$(is_openclaw_onboarded)
    # unknown = 設定根本讀不到（映像取不到），原因已印在上面。
    # 這裡再說一次「尚未初始化」會把使用者推去 onboard，那是錯的方向。
    if [[ "${onboarded}" == "unknown" ]]; then
        return 1
    fi
    if [[ "${onboarded}" != "true" ]]; then
        echo "❌ OpenClaw 尚未初始化 (gateway.mode 不是 local)"
        echo "   請先執行：kde openclaw onboard"
        return 1
    fi

    # gateway 綁在哪個位址，決定 dashboard 能不能從主機連進來。
    # OpenClaw 偵測到容器環境時預設 bind=auto(0.0.0.0)，但 onboarding 精靈常把
    # gateway.bind 明確寫成 loopback，而明確的 config 值會蓋過那個預設 —— 這時
    # gateway 只聽容器內的 127.0.0.1，-p 永遠轉不進去，dashboard 形同不存在。
    # 實測確認 CLI 的 --bind 旗標優先於 config，故在此覆蓋回來。
    #
    # 但 auth 關閉時不能加：OpenClaw 會以「Refusing to bind gateway to auto
    # without auth」拒絕啟動，硬加旗標等於把「能跑但連不到」變成「根本起不來」。
    # 那種情況改為據實告知，而不是印一個連不上的網址。
    local auth_mode
    auth_mode=$(get_openclaw_config gateway.auth.mode)
    local -a BIND_ARGS=()
    if [[ -n "${auth_mode}" && "${auth_mode}" != "none" ]]; then
        BIND_ARGS=(--bind auto)
    fi

    build_openclaw_docker_args || return 1
    if ! docker run -d --name "${name}" \
        --restart unless-stopped \
        -p "${OPENCLAW_PORT}:18789" \
        "${OPENCLAW_DOCKER_ARGS[@]}" \
        "${OPENCLAW_IMAGE}" \
        openclaw gateway run --port 18789 "${BIND_ARGS[@]}"; then
        echo "❌ gateway 容器啟動失敗"
        return 1
    fi

    # 健康檢查：gateway 設定不完整時容器會立刻退出，背景模式下使用者看不到，
    # 因此這裡主動確認並把日誌吐出來，而不是回報成功。
    # 等待秒數開放覆寫，是為了讓測試不必空等。
    #
    # 只看 State.Running 不夠：套用了 --restart unless-stopped 的容器若設定
    # 有誤會不斷 crash-loop，Docker 的重啟退避從 100ms 起跳，抽查當下極可能
    # 正好落在「剛被重啟、暫時 Running=true」的瞬間，導致健康檢查誤判成功。
    # 因此一併讀 RestartCount：只要曾經重啟過（>0），就代表容器並非穩定運行，
    # 一律視為失敗並吐出日誌，即使抽查當下 Running 剛好是 true。
    sleep "${OPENCLAW_HEALTH_WAIT:-3}"
    local state restarts
    read -r state restarts < <(docker inspect -f '{{.State.Running}} {{.RestartCount}}' "${name}" 2>/dev/null) || true
    if [[ "${state}" != "true" || -z "${restarts}" || "${restarts}" -ne 0 ]]; then
        echo "❌ gateway 啟動失敗，以下為容器日誌："
        docker logs --tail 50 "${name}" || true
        return 1
    fi

    echo "✓ openclaw gateway 已在背景啟動 (${name})"
    if [[ ${#BIND_ARGS[@]} -gt 0 ]]; then
        echo "存取網址: http://localhost:${OPENCLAW_PORT} (已配對過的瀏覽器)"
        # 光給網址是不夠的：新瀏覽器第一次連線還要一次性的裝置配對核准，
        # 直接開會撞上「pairing required」。故一併指向鑄配對連結的 action。
        echo "首次連線: kde openclaw dashboard (鑄一次性的 owner 配對連結)"
    else
        echo "⚠️  gateway 的 auth 為 none，OpenClaw 只允許綁 loopback，"
        echo "   因此 dashboard 僅容器內可達，http://localhost:${OPENCLAW_PORT} 連不到。"
        echo "   要從主機使用 dashboard，請先啟用 auth：kde openclaw exec 後執行 openclaw configure"
    fi
    echo "查看日誌: kde openclaw log -f"
    echo "取得 token: kde openclaw token"
    echo "停止服務: kde openclaw stop"
}

# tui / exec 共用的前置檢查。兩者的條件與錯誤訊息完全相同，
# 抽成一個函式以免同一段話出現三份。
# 回傳 0=容器正在運行、1=否（並已印出錯誤訊息）
require_openclaw_container_running() {
    local name
    name=$(get_openclaw_container_name)

    if [[ "$(is_openclaw_container_running)" != "true" ]]; then
        echo "❌ 容器 ${name} 未在運行，請先執行：kde openclaw run"
        return 1
    fi
    return 0
}

# -u node 的理由（tui / exec 共通）：容器的 image USER 是 root（entrypoint 需要以
# root 身分做 usermod/groupmod/chown），而 docker exec 是直接照 image 設定建立行程、
# 完全繞過 entrypoint，不帶 -u 會以 root、HOME=/root 執行，讀不到 entrypoint 寫進
# /home/node 的設定，workspace 裡新建的檔案也會變成 host 上的 root 擁有。
# -u node 讓 Docker 查 /etc/passwd 解析 uid/gid/HOME，因此仍會正確追隨 entrypoint
# 對 node 做的 usermod -u ${PUID} 重映射。

# 互動進入 OpenClaw TUI
tui_openclaw() {
    local name
    name=$(get_openclaw_container_name)

    require_openclaw_container_running || return 1

    docker exec -u node -it "${name}" openclaw
}

# 進入容器執行 bash。刻意「不」代入 openclaw：
# 指令原封不動交給 bash -c，所以 `kde openclaw exec "openclaw dashboard"` 打的字
# 跟容器裡實際跑的一致。若這裡自動補上 openclaw，就得反過來把 openclaw 這個字
# 拿掉（`kde openclaw exec dashboard`），既反直覺、也跑不了容器內的其他指令
# （kde、git…）。互動的 OpenClaw TUI 改由 tui action 提供。
exec_openclaw() {
    local name
    name=$(get_openclaw_container_name)

    require_openclaw_container_running || return 1

    if [[ -n "${OPENCLAW_COMMAND}" ]]; then
        docker exec -u node "${name}" bash -c "${OPENCLAW_COMMAND}"
    else
        docker exec -u node -it "${name}" bash
    fi
}

# 查看 gateway 容器日誌。
#
# 前置條件刻意用「容器存在」而不是「容器正在運行」：容器因設定有誤而 crash 掉
# 之後，正是最需要看日誌的時候，而 docker logs 對已退出的容器仍讀得到。
log_openclaw() {
    local name
    name=$(get_openclaw_container_name)

    if [[ "$(is_openclaw_container_exist)" != "true" ]]; then
        echo "❌ 容器 ${name} 不存在，請先執行：kde openclaw run"
        return 1
    fi

    # 用陣列組旗標而不是字串內插：跟隨與否是一個旗標的有無，
    # 字串寫法在不跟隨時會多出一個空參數。
    # 這裡不能寫 `[[ ... ]] && args+=(...)`——條件為假時整行回傳非零，
    # 本檔在 set -eo pipefail 下會直接中止。
    local -a args=(logs)
    if [[ "${OPENCLAW_FOLLOW}" == "true" ]]; then
        args+=(-f)
    fi
    args+=(--tail "${OPENCLAW_TAIL}" "${name}")

    local rc=0
    docker "${args[@]}" || rc=$?
    # 跟隨模式下用 Ctrl-C 離開會讓 docker 回 130，那是正常結束而不是失敗
    if [[ "${OPENCLAW_FOLLOW}" == "true" && ${rc} -eq 130 ]]; then
        return 0
    fi
    return ${rc}
}

# 印出 gateway 的 auth token（stdout 只有 token 本身，可被管線接走）。
#
# 為什麼直接讀 openclaw.json，而不是用官方的 openclaw gateway auth-token：
#   1. 那個指令需要 --show，且實測（2026.8.2）會以「Refusing to print the Gateway
#      token outside an interactive terminal」拒絕印到非互動終端機，無法被腳本取用。
#   2. openclaw config get gateway.auth.token 回傳的是 __OPENCLAW_REDACTED__。
# 走一次性容器（與 get_openclaw_config 同一組掛載）而不是 docker exec，
# 因此 gateway 沒在運行也能取。
#
# 本函式是全檔唯一把錯誤訊息送到 stderr 的地方：stdout 是資料通道，
# 混進提示文字會讓 `kde openclaw token | xclip` 夾帶垃圾。
get_openclaw_token() {
    build_openclaw_docker_args || return 1

    local token=""
    token=$(docker run --rm "${OPENCLAW_DOCKER_ARGS[@]}" "${OPENCLAW_IMAGE}" \
        node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync('${OPENCLAW_CONTAINER_HOME}/.openclaw/openclaw.json','utf8'));process.stdout.write(c?.gateway?.auth?.token ?? '')" \
        2>/dev/null | tr -d '[:space:]') || true

    if [[ -z "${token}" ]]; then
        # 讀不到的兩種成因差很多，值得多花一次容器問清楚——反正只發生在失敗路徑
        local auth_mode
        auth_mode=$(get_openclaw_config gateway.auth.mode)
        if [[ "${auth_mode}" == "none" ]]; then
            echo "❌ gateway.auth.mode 為 none，本來就沒有 token" >&2
            echo "   要啟用 auth：kde openclaw exec 後執行 openclaw configure" >&2
        else
            echo "❌ 讀不到 gateway token (openclaw.json 的 gateway.auth.token 為空或檔案不存在)" >&2
            echo "   若尚未初始化，請先執行：kde openclaw onboard" >&2
        fi
        return 1
    fi

    echo "${token}"
}

# 鑄一張一次性的 owner 配對連結，給瀏覽器首次連上 dashboard 用。
#
# 為什麼需要這個 action：gateway 的 token auth 過關之後，**新瀏覽器第一次連線還要
# 一次性的裝置配對核准**（失敗長相是 `disconnected (1008): pairing required`）。
# OpenClaw 對「直接 loopback 連線」有自動核准的例外，但這個容器架構吃不到：
# gateway 在容器內，主機瀏覽器經 -p 轉進來，從 gateway 的角度對端是 Docker bridge
# 而不是 127.0.0.1。官方對這種情形的規則是仍需明確核准。
#
# 官方指定的 owner 路徑就是在 gateway 主機上跑 openclaw dashboard：它會鑄一條
# 短命（實測約 10 分鐘）、單次使用的連結，並讓「redeem 它的那一個瀏覽器」拿到
# 持久的 administrator 憑證。因為短命且綁單一瀏覽器 profile，這件事無法在
# onboard 階段預先做掉，只能在要用的時候現鑄——所以它是獨立 action。
dashboard_openclaw() {
    local name
    name=$(get_openclaw_container_name)

    require_openclaw_container_running || return 1

    # 容器實際輸出前面會有 [state-migrations] 之類的警告行，必須挑出 JSON 那行，
    # 不能整段當結果用。
    local raw json
    raw=$(docker exec -u node "${name}" openclaw dashboard --no-open --json 2>/dev/null) || true
    json=$(printf '%s\n' "${raw}" | grep -m1 '^{' ) || true

    if [[ -z "${json}" ]]; then
        echo "❌ 取不到 dashboard 連結，openclaw dashboard 沒有回傳 JSON" >&2
        echo "   請確認 gateway 是否健康：kde openclaw log --tail 50" >&2
        return 1
    fi

    # openclaw dashboard 印的是容器自己的視角（恆為 127.0.0.1:18789），而主機側的
    # port 由 -p 決定。以 docker port 取容器實際發布的 port 來改寫，才不會讓
    # -p 19000 的人貼到一個連不上的網址。docker port 拿不到時退回 OPENCLAW_PORT。
    local host_port
    host_port=$(docker port "${name}" 18789/tcp 2>/dev/null | sed -n 1p | sed 's/.*://') || true
    host_port="${host_port:-${OPENCLAW_PORT}}"
    json="${json//127.0.0.1/localhost}"
    json="${json//:18789/:${host_port}}"

    if [[ "${OPENCLAW_JSON}" == "true" ]]; then
        echo "${json}"
        return 0
    fi

    local url
    url=$(printf '%s' "${json}" | grep -o '"browserUrl":"[^"]*"' | sed 's/^"browserUrl":"//; s/"$//') || true
    if [[ -z "${url}" ]]; then
        echo "❌ dashboard 的 JSON 裡沒有 browserUrl 欄位" >&2
        echo "   原始輸出：kde openclaw dashboard --json" >&2
        return 1
    fi

    echo "✓ 已鑄出一次性的 owner 配對連結，請在主機的瀏覽器打開："
    echo ""
    echo "  ${url}"
    echo ""
    echo "注意：連結約 10 分鐘後失效，且只能用一次——它只會把「第一個打開它的瀏覽器"
    echo "      profile」配成 administrator。換瀏覽器、清掉 site data 或用無痕視窗，"
    echo "      都要重新執行本指令。"
    echo "已配對過的瀏覽器直接開 http://localhost:${host_port} 即可，token 用 kde openclaw token 取得。"
}

# 停止並移除容器。容器本身是可拋棄的，狀態全在 workspace 的 .openclaw 裡。
# 回傳 0/1
stop_openclaw() {
    local name
    name=$(get_openclaw_container_name)

    if [[ "$(is_openclaw_container_exist)" != "true" ]]; then
        echo "容器 ${name} 不存在，無需停止"
        return 0
    fi

    # docker stop/rm 失敗時要給出本專案的錯誤訊息，而不是讓 set -e 直接中止：
    # 中止會跳過 docker rm 與收尾訊息，留下一個停一半、名稱還佔著的容器。
    if ! docker stop "${name}" >/dev/null; then
        echo "❌ 停止容器 ${name} 失敗，請手動處理：docker rm -f ${name}"
        return 1
    fi
    if ! docker rm "${name}" >/dev/null; then
        echo "❌ 移除容器 ${name} 失敗，請手動處理：docker rm -f ${name}"
        return 1
    fi
    echo "✓ 已停止並移除容器 ${name}"
    return 0
}

# 重啟 gateway：先 stop 再 run。
#
# port 的決定順序是「-p 或環境變數 OPENCLAW_PORT」>「現有容器目前發布的 port」
# >「內建預設」。中間那層是 restart 特有的：用 -p 19000 起的容器若在 restart
# 時退回內建預設，就會悄悄換 port，把已配對的瀏覽器書籤與先前鑄出的 dashboard
# 連結一起弄失效——而使用者的指令裡完全沒有提到 port，不會預期它改變。
# 只在使用者完全沒表態時才動用容器現況，所以明確打的 -p 18789 仍然勝出，
# 不會被沿用的舊 port 蓋掉（這正是需要 OPENCLAW_PORT_GIVEN 的原因）。
#
# 讀 port 的方式與 dashboard_openclaw 相同：問 docker 而不是猜，因為容器實際
# 發布的 port 才是真相。讀不到就維持原值，不讓 restart 因此失敗。
#
# stop 失敗就中止，不繼續 run：run 對同名容器會直接報「已存在」，
# 硬跑下去只是把一個明確的錯誤變成兩個。容器本來就沒在跑時 stop 回傳 0
# （冪等），因此 restart 對未啟動的 workspace 等同 run，這是刻意的。
restart_openclaw() {
    resolve_openclaw_port_from_container
    stop_openclaw || return 1
    run_openclaw_gateway
}

# 未表態 port 時改用現有容器目前發布的 port。restart 與 upgrade 共用：
# 兩者都是「換掉容器但不該換掉對外位址」，理由與細節見 restart_openclaw 的註解。
resolve_openclaw_port_from_container() {
    if [[ "${OPENCLAW_PORT_GIVEN}" == "true" ]]; then
        return 0
    fi
    if [[ "$(is_openclaw_container_running)" != "true" ]]; then
        return 0
    fi
    local name cur_port
    name=$(get_openclaw_container_name)
    # 取第一行用 sed -n 1p 而不是 head -1：docker port 對有 IPv4/IPv6 的容器會印
    # 兩行，head 拿到第一行就關閉管線、上游收到 SIGPIPE 回傳 141，在 pipefail 下
    # 被放大成整行失敗。那樣就得靠 || true 同時吞掉「真的失敗」與 SIGPIPE 兩件事。
    cur_port=$(docker port "${name}" 18789/tcp 2>/dev/null | sed -n 1p | sed 's/.*://') || true
    if [[ -n "${cur_port}" ]]; then
        OPENCLAW_PORT="${cur_port}"
    fi
}

# ---------------------------------------------------------------------------
# 映像釘選
#
# downgrade 要能把容器帶回舊映像，但不該去改 kde.env——那是版控檔案，會隨
# workspace 同步到每個人的機器上，而「我這台暫時停在舊版」純粹是本機狀態。
# 因此用 workspace 底下的 .openclaw-image 記錄，它以 .openclaw 開頭，
# 正好落在 .gitignore 的 /.openclaw* 規則裡。
# ---------------------------------------------------------------------------

get_openclaw_image_pin_file() {
    echo "${KDE_PATH}/.openclaw-image"
}

read_openclaw_image_pin() {
    local f
    f=$(get_openclaw_image_pin_file)
    if [[ -f "${f}" ]]; then
        head -1 "${f}" | tr -d '[:space:]'
    fi
}

write_openclaw_image_pin() {
    echo "$1" > "$(get_openclaw_image_pin_file)"
}

clear_openclaw_image_pin() {
    rm -f "$(get_openclaw_image_pin_file)"
}

# 把釘選套用到 OPENCLAW_IMAGE 上。由 command.sh 在 dispatch 之前呼叫一次，
# 這樣既有的每一處 ${OPENCLAW_IMAGE} 都不必改。
apply_openclaw_image_pin() {
    # upgrade 的語意是「回到 kde.env 指定的映像的最新版」，所以它刻意不吃釘選，
    # 而且成功換版之後會把釘選清掉（見 upgrade_openclaw），讓兩個 action 對稱。
    if [[ "${OPENCLAW_ACTION}" == "upgrade" ]]; then
        return 0
    fi

    local pin
    pin=$(read_openclaw_image_pin)
    if [[ -z "${pin}" ]]; then
        return 0
    fi

    OPENCLAW_IMAGE="${pin}"
    # 一定要說出來，而且要說出釘選檔的路徑。否則實際跑的版本與 kde.env 寫的
    # 不一致卻毫無線索，那正是這個 workspace 已經踩過一次的無聲版本歪掉；
    # 而只說「有釘選」不說路徑，使用者會反覆去改 kde.env——kde.env 在這裡正是
    # 被蓋掉的那一邊，怎麼改都不會生效。
    #
    # 印到 stderr 而非 stdout：token action 的 stdout 是設計成可被管線接走的，
    # 這幾行提示混進去會讓 `kde openclaw token | ...` 拿到一坨垃圾。
    echo "ℹ️  使用釘選映像：${OPENCLAW_IMAGE}" >&2
    echo "   來源：$(get_openclaw_image_pin_file)" >&2
    echo "   此檔覆蓋 kde.env 的 OPENCLAW_IMAGE，改 kde.env 不會生效" >&2
    echo "   解除：kde openclaw upgrade（或刪除上述檔案）" >&2
}

# ---------------------------------------------------------------------------
# 備份與還原
# ---------------------------------------------------------------------------

get_openclaw_backup_dir() {
    echo "${KDE_PATH}/.openclaw-backups"
}

# image reference 含 / 與 :，檔名放不了，一律換成 _。docker.io/ 前綴去掉，
# 否則每個檔名都多一段沒有辨識價值的字。清洗後無法反推原值，精確值在 manifest。
sanitize_openclaw_image_tag() {
    echo "$1" | sed 's#^docker\.io/##; s#[^a-zA-Z0-9._-]#_#g'
}

# 打包 .openclaw-home。
# 可帶入 image / image_id / version 覆寫記錄值：upgrade 必須這樣用，因為
# docker pull 之後同一個 tag 查到的已經是新版，而備份對應的是被換掉的舊版。
create_openclaw_backup() { # [$1=image $2=image_id $3=version]
    local home dir ts tag file tmpdir manifest
    home="${KDE_PATH}/.openclaw-home"

    if [[ ! -d "${home}" ]]; then
        echo "⚠️  ${home} 不存在，略過備份"
        return 0
    fi

    local image image_id version
    image="${1:-${OPENCLAW_IMAGE}}"
    image_id="${2:-$(get_openclaw_image_id)}"
    version="${3:-$(get_openclaw_image_version)}"

    dir=$(get_openclaw_backup_dir)
    mkdir -p "${dir}"
    ts=$(date +%Y%m%d-%H%M%S)
    tag=$(sanitize_openclaw_image_tag "${image}")
    file="${dir}/openclaw-backup-${ts}-${tag}.tar.gz"
    # 時間戳只到秒，同一秒內連續備份會撞到同一個檔名並靜默覆蓋前一份
    # （downgrade 先備份現況、緊接著又有流程觸發備份就會這樣）。加序號避開。
    local n=2
    while [[ -e "${file}" ]]; do
        file="${dir}/openclaw-backup-${ts}-${tag}-${n}.tar.gz"
        n=$((n + 1))
    done

    tmpdir=$(mktemp -d)
    manifest="${tmpdir}/${OPENCLAW_BACKUP_MANIFEST_NAME}"
    {
        echo "OPENCLAW_BACKUP_IMAGE=${image}"
        echo "OPENCLAW_BACKUP_IMAGE_ID=${image_id}"
        echo "OPENCLAW_BACKUP_VERSION=${version}"
        echo "OPENCLAW_BACKUP_AT=$(date -Iseconds)"
    } > "${manifest}"

    echo "↓ 備份 .openclaw-home ..."
    # manifest 刻意排在 tar 的最前面：列表時用 --occurrence=1 抽出它就能停，
    # 不必解開整包。兩個 -C 讓一次 tar 同時收進不同來源目錄的東西。
    if ! tar -czf "${file}" \
        -C "${tmpdir}" "${OPENCLAW_BACKUP_MANIFEST_NAME}" \
        -C "${KDE_PATH}" .openclaw-home; then
        echo "❌ 備份失敗" >&2
        rm -f "${file}"
        rm -rf "${tmpdir}"
        return 1
    fi
    rm -rf "${tmpdir}"

    echo "✓ 已備份 $(basename "${file}") ($(du -h "${file}" | cut -f1))"
    prune_openclaw_backups
}

# 手動備份。
#
# 與 upgrade 內建的那次備份走同一個函式，差別在於它自己負責停止與啟動：手動備份
# 幾乎都在容器運行中執行，正面撞上熱備份 sqlite 的一致性問題（.codex 的 WAL 有
# 未 checkpoint 的交易，而打包實測要 9 秒，期間有寫入就可能備出還原不回來的
# 快照）。停掉再備份是唯一可信的做法，代價是中斷服務——所以先問過再動手。
#
# 容器本來就沒在跑時不問也不啟動：沒有東西要中斷，而把停著的容器叫起來是
# run 的職責，不該由備份順手代辦。
backup_openclaw() {
    local was_running=false
    if [[ "$(is_openclaw_container_running)" == "true" ]]; then
        was_running=true
    fi

    if [[ "${was_running}" == "true" && "${OPENCLAW_FORCE}" != "true" ]]; then
        echo "⚠️  備份期間會短暫停止 gateway（打包實測約 9 秒）"
        echo "   停止之後才沒有行程在寫 sqlite，快照才是一致的"
        # 用 echo -n 而不是 read -p：read 的 prompt 只在 stdin 是終端時才輸出，
        # 在腳本或 CI 裡誤用（又沒帶 -f）就會變成靜默等待輸入，看起來像卡住。
        echo -n "確定要繼續嗎？(y/N) "
        read answer
        if [[ "${answer}" != "y" ]]; then
            echo "已取消"
            return 0
        fi
    fi

    if [[ "${was_running}" == "true" ]]; then
        # 先讀 port 再停：容器沒了就問不到它發布在哪個 port
        resolve_openclaw_port_from_container
        # 停不掉就別繼續：備份會拿到熱快照，而且後面還會試著啟動一個沒停掉的容器
        stop_openclaw || return 1
    fi

    create_openclaw_backup || return 1

    if [[ "${was_running}" == "true" ]]; then
        run_openclaw_gateway
    fi
}

# 依時間由舊到新列出備份檔。編號 1 是最舊的那份，順序與 downgrade 的列表一致。
get_openclaw_backup_files() {
    local dir
    dir=$(get_openclaw_backup_dir)
    if [[ ! -d "${dir}" ]]; then
        return 0
    fi
    ls -1tr "${dir}"/openclaw-backup-*.tar.gz 2>/dev/null || true
}

# 只讀 manifest 裡的一個 key，讀不到回傳空字串
read_openclaw_backup_manifest() { # $1=備份檔 $2=key
    local line=""
    line=$(tar -xzOf "$1" --occurrence=1 "${OPENCLAW_BACKUP_MANIFEST_NAME}" 2>/dev/null | grep -m1 "^$2=") || true
    echo "${line#*=}"
}

# 保留最新 N 份，其餘由舊而新刪除
prune_openclaw_backups() {
    local keep
    keep="${OPENCLAW_BACKUP_KEEP:-${OPENCLAW_BACKUP_KEEP_DEFAULT}}"

    local -a files=()
    mapfile -t files < <(get_openclaw_backup_files)
    local total=${#files[@]}
    if [[ ${total} -le ${keep} ]]; then
        return 0
    fi

    local remove=$((total - keep))
    local i
    for ((i = 0; i < remove; i++)); do
        rm -f "${files[i]}"
        echo "  已刪除較舊的備份 $(basename "${files[i]}")"
    done
}

# 以備份覆蓋現有的 .openclaw-home
restore_openclaw_backup() { # $1=備份檔
    local file="$1" home
    home="${KDE_PATH}/.openclaw-home"

    if [[ ! -f "${file}" ]]; then
        echo "❌ 備份檔不存在：${file}" >&2
        return 1
    fi

    mkdir -p "${home}"
    # 清空「目錄內容」而不是刪掉目錄本身。.openclaw-home 是 named volume
    # （local driver + o=bind）綁著的路徑，把目錄 rm -rf 再重建會讓掛載守著
    # 已刪除的 inode——cdb2e58 在 local-install.sh 上踩過同一個坑。
    find "${home}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

    # tar 內的路徑是 .openclaw-home/...，所以解到 KDE_PATH；
    # 明確只取該目錄，manifest 就不會被解出來留在 workspace 裡。
    if ! tar -xzf "${file}" -C "${KDE_PATH}" .openclaw-home; then
        echo "❌ 還原失敗" >&2
        return 1
    fi
    return 0
}

# 從備份還原資料與映像版本。
#
# 不改 kde.env（版控檔案），改為寫入本機的映像釘選，見 apply_openclaw_image_pin。
downgrade_openclaw() {
    local -a files=()
    mapfile -t files < <(get_openclaw_backup_files)
    local total=${#files[@]}

    if [[ ${total} -eq 0 ]]; then
        echo "❌ 沒有可用的備份（$(get_openclaw_backup_dir) 是空的）" >&2
        echo "   備份會在 kde openclaw upgrade 換版本時自動建立" >&2
        return 1
    fi

    echo "可用的備份（由舊到新）："
    local i f v at
    for ((i = 0; i < total; i++)); do
        f="${files[i]}"
        v=$(read_openclaw_backup_manifest "${f}" OPENCLAW_BACKUP_VERSION)
        at=$(read_openclaw_backup_manifest "${f}" OPENCLAW_BACKUP_AT)
        printf "  %d) OpenClaw %-10s %s  %s\n" "$((i + 1))" "${v}" "${at}" "$(du -h "${f}" | cut -f1)"
        printf "     %s\n" "$(basename "${f}")"
    done

    if [[ "${OPENCLAW_LIST}" == "true" ]]; then
        return 0
    fi

    local choice="${OPENCLAW_BACKUP_CHOICE}"
    if [[ -z "${choice}" ]]; then
        read -p "要還原哪一份？(1-${total}) " choice
    fi

    # 編號錯誤一律報錯而不是猜。還原是破壞性的，猜錯等於用錯的資料蓋掉現況。
    if [[ ! "${choice}" =~ ^[0-9]+$ ]] || [[ "${choice}" -lt 1 || "${choice}" -gt ${total} ]]; then
        echo "❌ 無效的編號：${choice}（可用 1-${total}）" >&2
        return 1
    fi

    local file image
    file="${files[$((choice - 1))]}"
    image=$(read_openclaw_backup_manifest "${file}" OPENCLAW_BACKUP_IMAGE)
    if [[ -z "${image}" ]]; then
        echo "❌ 該備份的 manifest 沒有記錄 image，無法決定要還原到哪個版本" >&2
        return 1
    fi

    if [[ "${OPENCLAW_FORCE}" != "true" ]]; then
        echo ""
        echo "⚠️  將以 $(basename "${file}") 覆蓋現有的 .openclaw-home"
        echo "   並把映像釘選為 ${image}"
        echo "   （寫入 $(get_openclaw_image_pin_file)，不會動到 kde.env）"
        read -p "確定要繼續嗎？(y/n) " answer
        if [[ "${answer}" != "y" ]]; then
            echo "已取消"
            return 0
        fi
    fi

    # 先停容器再備份現況：停掉之後才沒有行程在寫 sqlite，備份才是一致的快照。
    # 而現況一定要備份——還原會覆蓋它，否則 downgrade 自己就不可逆。
    if [[ "$(is_openclaw_container_running)" == "true" ]]; then
        stop_openclaw || return 1
    fi
    create_openclaw_backup || return 1

    restore_openclaw_backup "${file}" || return 1
    write_openclaw_image_pin "${image}"
    OPENCLAW_IMAGE="${image}"

    echo "✓ 已還原 $(basename "${file}")"
    echo "  映像已釘選為 ${image}"
    echo "  釘選檔：$(get_openclaw_image_pin_file)"
    echo "  此檔覆蓋 kde.env 的 OPENCLAW_IMAGE；kde openclaw upgrade 會解除釘選"

    run_openclaw_gateway
}

# 讀取本地 OPENCLAW_IMAGE 的 image ID；映像不存在時回傳空字串。
# upgrade 靠比對這個值判斷 pull 前後映像有沒有真的換掉，而不是去解析
# docker pull 的輸出文字——那是給人看的訊息，格式會隨 Docker 版本變。
get_openclaw_image_id() {
    docker image inspect -f '{{.Id}}' "${OPENCLAW_IMAGE}" 2>/dev/null || true
}

# 讀取映像的 OpenClaw 版本，純粹用於印給人看。
# 值來自官方 base image 的 org.opencontainers.image.version label；判斷「有沒有
# 換版本」一律靠 image ID，不依賴這個 label 存在，取不到就顯示 unknown。
get_openclaw_image_version() {
    local v=""
    v=$(docker image inspect -f '{{index .Config.Labels "org.opencontainers.image.version"}}' "${OPENCLAW_IMAGE}" 2>/dev/null) || true
    v=$(echo "${v}" | tr -d '[:space:]')
    if [[ -z "${v}" || "${v}" == "<novalue>" ]]; then
        echo "unknown"
    else
        echo "${v}"
    fi
}

# 拉取 OPENCLAW_IMAGE 的最新版本，映像真的變了才重啟容器。
#
# 為什麼需要一個獨立的 action：docker run 的預設 pull policy 是 missing——本地
# 只要已有該 tag 就直接用，永遠不會回頭問 registry。所以 registry 上的 latest
# 換了新版之後，run 與 restart 仍會沉默地跑舊映像，而且完全沒有徵兆。
#
# 刻意「不」把 --pull always 加進 run：restart 的語意是重啟而非升級，每次都打
# registry 會讓離線環境直接失敗，也讓每次重啟多一次網路往返。換版本是明確的
# 意圖，值得一個明確的指令。
#
# 沒有新版就不重啟：重啟會中斷 gateway、踢掉進行中的 session，在沒有換到新
# 映像的情況下不值得付這個代價。
#
# 容器未運行時只更新映像、不順便啟動：upgrade 的職責是「把映像更新到最新，
# 並讓正在跑的容器換過去」，沒有東西要重啟時就該把啟動留給 run。
upgrade_openclaw() {
    local before after ver_before ver_after
    before=$(get_openclaw_image_id)
    ver_before=$(get_openclaw_image_version)

    echo "↓ 拉取 ${OPENCLAW_IMAGE} ..."
    # pull 失敗必須在動到容器之前中止：離線時把跑著的 gateway 停掉卻換不到新
    # 映像，會把「沒升級」惡化成「服務不見了」。
    if ! docker pull "${OPENCLAW_IMAGE}"; then
        echo "❌ 拉取映像失敗，容器未受影響" >&2
        return 1
    fi

    after=$(get_openclaw_image_id)
    ver_after=$(get_openclaw_image_version)

    if [[ -n "${before}" && "${before}" == "${after}" ]]; then
        echo "✓ 已是最新版本 (${ver_after})，容器未重啟"
        return 0
    fi

    # 本地原本沒有這個映像時，印「unknown → 2026.9.1」只是雜訊而非資訊
    if [[ -z "${before}" ]]; then
        echo "映像已取得：${ver_after}"
    else
        echo "映像已變更：${ver_before} → ${ver_after}"
    fi

    # upgrade 的語意是「回到 kde.env 指定的映像的最新版」，所以放開 downgrade
    # 設下的釘選，讓兩個 action 對稱。
    if [[ -n "$(read_openclaw_image_pin)" ]]; then
        clear_openclaw_image_pin
        echo "已解除映像釘選，映像來源改回 kde.env 的 OPENCLAW_IMAGE"
    fi

    if [[ "$(is_openclaw_container_running)" != "true" ]]; then
        echo "容器未在運行，啟動請執行：kde openclaw run"
        return 0
    fi

    # 這裡刻意展開 restart 的兩個步驟，而不是呼叫 restart_openclaw：備份必須落在
    # stop 之後、新版啟動之前。那個瞬間「舊版已停、新版未起」，沒有行程在寫
    # sqlite——容器還在跑時打包 sqlite 加 WAL 會拿到不一致的快照，而問題要到
    # 還原那天才會浮現。順帶的好處是 pull 失敗或本來就最新時不會白備份。
    resolve_openclaw_port_from_container
    stop_openclaw || return 1
    # 傳入舊版的 image 資訊：pull 之後同一個 tag 查到的已經是新版，
    # 而這份備份對應的是被換掉的那一版。
    create_openclaw_backup "${OPENCLAW_IMAGE}" "${before}" "${ver_before}" || return 1
    run_openclaw_gateway
}

# 刪除 workspace 的 .openclaw（含 auth 密鑰）
reset_openclaw() {
    local name openclaw_dir
    name=$(get_openclaw_container_name)
    openclaw_dir="${KDE_PATH}/.openclaw-home"

    # 不在容器運行中抽掉設定，避免產生難以診斷的半死狀態
    if [[ "$(is_openclaw_container_running)" == "true" ]]; then
        echo "❌ 容器 ${name} 仍在運行，請先執行：kde openclaw stop"
        return 1
    fi

    if [[ ! -d "${openclaw_dir}" ]]; then
        echo "${openclaw_dir} 不存在，無需重設"
        return 0
    fi

    if [[ "${OPENCLAW_FORCE}" != "true" ]]; then
        echo "⚠️  將刪除 ${openclaw_dir} (含 OpenClaw 設定與 auth 密鑰)"
        read -p "確定要繼續嗎？(y/n) " answer
        if [[ "${answer}" != "y" ]]; then
            echo "已取消"
            return 0
        fi
    fi

    rm -rf "${openclaw_dir}"
    # 目錄刪了還要移除 volume 定義，否則會留下一個指向已不存在路徑的 volume，
    # 下次 run 會沿用它而不是重新建立、也就拿不到映像 home 的預先複製內容。
    docker volume rm "$(get_openclaw_home_volume_name)" >/dev/null 2>&1 || true
    echo "✓ 已刪除 ${openclaw_dir}"
}
