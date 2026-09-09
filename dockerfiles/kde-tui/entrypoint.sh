#!/bin/bash
set -e

USER_NAME=${USER_NAME:-user}
PGID=${PGID:-1000}
PUID=${PUID:-1000}

if ! getent group ${USER_NAME} >/dev/null; then
  groupadd -g ${PGID} ${USER_NAME}
fi

if ! getent passwd ${USER_NAME} >/dev/null; then
  useradd --shell /bin/bash -u ${PUID} -g ${PGID} -m ${USER_NAME}
fi

adduser ${USER_NAME} sudo >/dev/null 2>&1 || true

exec /usr/sbin/gosu ${USER_NAME} "$@"
