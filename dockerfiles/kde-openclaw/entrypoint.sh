#!/bin/bash

# kde-openclaw 容器的 entrypoint，以 root 進入、降權後把控制權交給實際指令。
#
# 刻意使用 set -e：這裡每一步（使用者重映射、目錄建立、chown）失敗都代表
# 容器之後必然會出權限問題，繼續執行只會把錯誤延後到更難診斷的地方。
# 這與 dockerfiles/code-server/entrypoint.d/10-ai-agents.sh 的取捨相反——
# 那支是「單一 agent 安裝失敗不該擋住 code-server 啟動」，這支沒有那種餘裕。
set -e

# 官方 OpenClaw 映像的使用者是 node，uid/gid 皆為 1000
PUID=${PUID:-1000}
PGID=${PGID:-1000}

# 容器內 home。正式執行時固定為 /home/node，開放覆寫是為了讓測試不需要 root。
OPENCLAW_HOME_DIR=${OPENCLAW_HOME_DIR:-/home/node}

# 只在 uid/gid 與映像內建值不同時才重映射，多數情況（主機使用者也是 1000）完全不動
if [[ "${PGID}" != "1000" ]]; then
    groupmod -g "${PGID}" node
fi
if [[ "${PUID}" != "1000" ]]; then
    usermod -u "${PUID}" node
fi

mkdir -p "${OPENCLAW_HOME_DIR}/.openclaw"

# .cache 也要一併確保存在且屬於目標使用者。
#
# 官方 -browser 變體的 playwright 安裝步驟是以 root 建出 /home/node/.cache 的
# （只有裡面的 ms-playwright 被 chown 給 node），於是那層目錄在映像裡是
# root:root 0755。OpenClaw 啟動時要在 ~/.cache 底下建 openclaw-<uid> 當
# SQLite worker 的 temp dir，降權後寫不進去，容器就會 restart loop 並只留下
#   SQLite read-only worker Unable to create fallback OpenClaw temp dir:
#   /home/node/.cache/openclaw-<uid>
# 這條訊息（實測踩過）。與 PUID 是多少無關，1000 也一樣失敗。
#
# 只有全新 workspace 會踩到：home 是 named volume，Docker 只在目錄為空的首次
# 掛載把映像的 /home/node 預先複製進去，那次會把 root 所有的 .cache 一起帶進
# volume。既有 workspace 沿用的是 OpenClaw 自己建的 .cache（屬 node），所以
# 換基底映像後照樣能跑 —— 症狀只在 onboard 新 workspace 時出現。
mkdir -p "${OPENCLAW_HOME_DIR}/.cache"


# 只 chown home 與 OpenClaw 實際要寫入的兩個目錄（.openclaw、.cache）。
# 絕不遞迴 chown 掛進來的 workspace：那可能很大，而且會改動主機端檔案的擁有者。
#
# 狀態目錄只有 .openclaw：實測（見 task-5-report.md Finding 1）確認 OpenClaw
# 的設定與 auth 密鑰全部寫進 ~/.openclaw/openclaw.json，~/.config/openclaw 從未
# 被寫入，故不再另建/另 chown 該目錄。.cache 不是狀態目錄，純粹是啟動時要在裡面
# 建 temp dir，理由見上面 mkdir 那段。
# 刻意不遞迴 .cache：裡面的 ms-playwright 動輒數百 MB，每次啟動遞迴一次會明顯
# 拖慢啟動，而瀏覽器只需要能讀能執行。要修的只是「在 .cache 底下建目錄」的權限，
# 那取決於 .cache 自己這一層。
chown "${PUID}:${PGID}" \
    "${OPENCLAW_HOME_DIR}" \
    "${OPENCLAW_HOME_DIR}/.openclaw" \
    "${OPENCLAW_HOME_DIR}/.cache"

# setpriv 只切換 uid/gid，不會連帶更新 HOME：容器起始環境的 HOME 繼承自映像
# 設定的 root（/root），降權後若不手動改寫，後續指令（含 openclaw 本身）會去
# 讀寫 /root 而非目標使用者的 home，導致每次啟動都讀不到既有設定、且必然權限
# 不足。這裡明確改寫成目標 home，讓 setpriv 之後的行程看到正確的 $HOME。
export HOME="${OPENCLAW_HOME_DIR}"

# setpriv --init-groups 會用 /etc/group 裡 node 現有的附加群組「重建」整個
# 附加群組集合，而不是沿用 docker run 當下的行程群組——換句話說，host 端
# 用 --group-add 加進來的 docker.sock gid（讓容器內能操作 DooD）會在這裡
# 被整組蓋掉、直接消失，之後任何 docker 指令都會因權限不足失敗。
# 修法是在 setpriv 之前，把該 gid 實際寫進 /etc/group 並掛到 node 身上，
# 這樣 --init-groups 重建出來的集合裡就會包含它，而不是繞過 --init-groups
# 改用 --keep-groups（那會連 gid 0 一起帶進來，權限反而更大，不能接受）。
SOCK_GID=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || true)
if [[ -n "${SOCK_GID}" ]]; then
    getent group "${SOCK_GID}" >/dev/null || groupadd -g "${SOCK_GID}" hostdocker
    usermod -aG "${SOCK_GID}" node
fi

# 用 setpriv 而非 gosu/sudo：util-linux 內建、零額外套件，
# 且 exec 取代自身，降權後的行程直接成為 tini 的子行程並承接訊號。
exec setpriv --reuid "${PUID}" --regid "${PGID}" --init-groups --inh-caps=-all "$@"
