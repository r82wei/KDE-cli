#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/code-server.sh

# 注意：本檔是被 kde.sh source 進去的，而 kde.sh 開了 set -e，
# 因此必須用 `|| rc=$?` 承接非零回傳，不可寫成 `parse...; rc=$?`
rc=0
parse_code_server_args "$@" || rc=$?

if [[ ${rc} -eq 2 ]]; then
    exit 0
fi
if [[ ${rc} -ne 0 ]]; then
    exit 1
fi

read -p "請輸入 code-server 的 password: " PASSWORD

start_code_server "${CODE_SERVER_PORT}" "${CODE_SERVER_DAEMON}" "${CODE_SERVER_NAME}" \
                  "${CODE_SERVER_OPEN_PATH}" "${CODE_SERVER_AGENTS_CSV}" \
                  "${CODE_SERVER_MOUNTS[@]}"
