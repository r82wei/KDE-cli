#!/bin/bash

source ${KDE_SCRIPTS_PATH}/utils/openclaw.sh

# 注意：本檔是被 kde.sh source 進去的，而 kde.sh 開了 set -e，
# 因此必須用 `|| rc=$?` 承接非零回傳，不可寫成 `parse...; rc=$?`
rc=0
parse_openclaw_args "$@" || rc=$?

if [[ ${rc} -eq 2 ]]; then
    exit 0
fi
if [[ ${rc} -ne 0 ]]; then
    exit 1
fi

case "${OPENCLAW_ACTION}" in
    run)
        run_openclaw_gateway
        ;;
    onboard)
        onboard_openclaw
        ;;
    stop)
        stop_openclaw
        ;;
    tui)
        tui_openclaw
        ;;
    exec)
        exec_openclaw
        ;;
    log)
        log_openclaw
        ;;
    token)
        get_openclaw_token
        ;;
    reset)
        reset_openclaw
        ;;
esac
