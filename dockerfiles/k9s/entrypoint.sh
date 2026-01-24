#!/bin/bash
set -e

# 設定使用者名稱
USER_NAME=${USER_NAME:-user}

# 如果傳入的 PGID/PUID 是空值，就使用預設值 1000
PGID=${PGID:-1000}
PUID=${PUID:-1000}

# 建立與指定 PGID 相同的群組
if ! getent group ${USER_NAME} >/dev/null; then
    groupadd -g ${PGID} ${USER_NAME}
fi

# 建立與指定 PUID 相同的使用者，並指定其家目錄和主要群組
if ! getent passwd ${USER_NAME} >/dev/null; then
    useradd --shell /bin/bash -u ${PUID} -g ${PGID} -m ${USER_NAME}
fi

# 將新建立的使用者加入 sudo 和 docker 群組
adduser ${USER_NAME} sudo
adduser ${USER_NAME} docker

echo "
使用者 '${USER_NAME}' 已建立，UID=${PUID}, GID=${PGID}
"

# 以 'user' 的身份執行傳遞給容器的任何後續指令
exec /usr/sbin/gosu ${USER_NAME} "$@"