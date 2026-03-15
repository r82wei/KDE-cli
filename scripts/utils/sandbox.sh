#!/bin/bash

SANDBOX_BACKEND=${KDE_SANDBOX_BACKEND:-lima}
SANDBOX_DATA_DIR=${KDE_PATH}/.sandbox

check_sandbox_backend() {
    case "${SANDBOX_BACKEND}" in
        lima)
            if ! command -v limactl &> /dev/null; then
                echo "錯誤：limactl 未安裝。請先安裝 Lima："
                echo "  brew install lima"
                echo "  或參考 https://lima-vm.io/docs/installation/"
                exit 1
            fi
            export LIMA_HOME="${SANDBOX_DATA_DIR}/lima"
            mkdir -p "${LIMA_HOME}"
            ;;
        *)
            echo "錯誤：不支援的 sandbox 後端 '${SANDBOX_BACKEND}'"
            echo "目前支援的後端：lima"
            exit 1
            ;;
    esac
}

get_sandbox_instance_name() {
    local workspace_dir
    workspace_dir=$(basename "${KDE_PATH}")
    echo "kde-sandbox-${workspace_dir}"
}

check_sandbox_backend
source ${KDE_SCRIPTS_PATH}/utils/sandbox/${SANDBOX_BACKEND}.sh
