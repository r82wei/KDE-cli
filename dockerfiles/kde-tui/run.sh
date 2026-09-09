#!/bin/bash
set -euo pipefail

IMAGE=${IMAGE:-r82wei/kde-tui:latest}
WORKDIR="${PWD}"
WS="${WORKDIR}"

while [[ "${WS}" != "/" && ! -f "${WS}/kde.env" ]]; do
  WS="$(dirname "${WS}")"
done

if [[ ! -f "${WS}/kde.env" ]]; then
  echo "找不到 workspace（kde.env）。請在 workspace 內執行。"
  exit 1
fi

echo "Workspace: ${WS}"
echo "Workdir:   ${WORKDIR}"

docker run --rm -it \
  -v "${WS}:${WS}" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -w "${WORKDIR}" \
  -e PUID="${UID}" \
  -e PGID="$(id -g)" \
  -e USER_NAME="${USER}" \
  "${IMAGE}" \
  bash -lc 'kde tui2'
