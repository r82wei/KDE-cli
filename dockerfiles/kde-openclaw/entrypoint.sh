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


# 只 chown home 與 OpenClaw 的狀態目錄。
# 絕不遞迴 chown 掛進來的 workspace：那可能很大，而且會改動主機端檔案的擁有者。
#
# 只有 .openclaw 一個狀態目錄：實測（見 task-5-report.md Finding 1）確認 OpenClaw
# 的設定與 auth 密鑰全部寫進 ~/.openclaw/openclaw.json，~/.config/openclaw 從未
# 被寫入，故不再另建/另 chown 該目錄。
chown "${PUID}:${PGID}" \
    "${OPENCLAW_HOME_DIR}" \
    "${OPENCLAW_HOME_DIR}/.openclaw"

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
