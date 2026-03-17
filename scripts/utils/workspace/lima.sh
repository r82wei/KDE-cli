#!/bin/bash

# Lima backend for workspace management.
# Refactored from scripts/utils/sandbox/lima.sh — function names follow workspace_* convention.

LIMA_TEMPLATE_PATH=${KDE_TEMPLATES_PATH}/lima/kde-sandbox.yaml

WORKSPACE_DATA_DIR="${KDE_PATH}/.workspace"
export LIMA_HOME="${WORKSPACE_DATA_DIR}/lima"
mkdir -p "${LIMA_HOME}"

get_workspace_instance_name() {
    local workspace_dir
    workspace_dir=$(basename "${KDE_PATH}")
    echo "kde-workspace-${workspace_dir}"
}

detect_lima_vm_type() {
    local os
    os=$(uname -s)

    case "${os}" in
        Darwin)
            local macos_major
            macos_major=$(sw_vers -productVersion | cut -d. -f1)
            if [[ ${macos_major} -ge 13 ]]; then
                LIMA_VM_TYPE="vz"
                LIMA_MOUNT_TYPE="virtiofs"
            else
                LIMA_VM_TYPE="qemu"
                LIMA_MOUNT_TYPE="reverse-sshfs"
            fi
            ;;
        Linux)
            LIMA_VM_TYPE="qemu"
            local _virtiofsd_ok=false
            if [[ -e /dev/kvm ]]; then
                # Lima 優先使用 /usr/lib/qemu/virtiofsd，需確認該路徑也能正常執行
                local _virtiofsd_bin="/usr/lib/qemu/virtiofsd"
                if [[ -x "${_virtiofsd_bin}" ]] && "${_virtiofsd_bin}" --version &>/dev/null; then
                    _virtiofsd_ok=true
                elif command -v virtiofsd &>/dev/null && virtiofsd --version &>/dev/null; then
                    _virtiofsd_ok=true
                fi
            fi
            if [[ "${_virtiofsd_ok}" == "true" ]]; then
                LIMA_MOUNT_TYPE="virtiofs"
            else
                LIMA_MOUNT_TYPE="reverse-sshfs"
            fi
            ;;
        *)
            echo "警告：未知作業系統 '${os}'，使用 QEMU 作為後備方案"
            LIMA_VM_TYPE="qemu"
            LIMA_MOUNT_TYPE="reverse-sshfs"
            ;;
    esac

    export LIMA_VM_TYPE
    export LIMA_MOUNT_TYPE
}

detect_lima_vm_type

_check_kvm_available() {
    [[ "$(uname -s)" != "Linux" ]] && return 0

    if [[ ! -e /dev/kvm ]]; then
        echo "錯誤：/dev/kvm 不存在，Linux 上 QEMU 需要 KVM 加速"
        echo ""
        echo "請嘗試以下步驟："
        echo "  1. 載入 KVM 核心模組："
        echo "     sudo modprobe kvm_intel  # Intel CPU"
        echo "     sudo modprobe kvm_amd    # AMD CPU"
        echo ""
        echo "  2. 確認 /dev/kvm 已建立："
        echo "     ls -la /dev/kvm"
        echo ""
        echo "  3. 若仍無法使用，將使用者加入 kvm 群組："
        echo "     sudo usermod -aG kvm \$USER"
        echo "     # 重新登入後生效"
        return 1
    fi

    if [[ ! -r /dev/kvm ]] || [[ ! -w /dev/kvm ]]; then
        echo "錯誤：/dev/kvm 權限不足"
        echo ""
        echo "目前權限："
        ls -la /dev/kvm
        echo ""
        echo "請將使用者加入 kvm 群組："
        echo "  sudo usermod -aG kvm \$USER"
        echo "  # 重新登入後生效"
        return 1
    fi

    return 0
}

workspace_create() {
    local instance_name=$1
    local workspace_path=$2
    local cpus=${KDE_SANDBOX_CPUS:-2}
    local memory=${KDE_SANDBOX_MEMORY:-4GiB}
    local disk=${KDE_SANDBOX_DISK:-50GiB}

    if [[ "${LIMA_VM_TYPE}" == "qemu" ]]; then
        _check_kvm_available || exit 1
    fi

    # 若 VM 已存在，報錯並返回
    local status
    status=$(limactl list --json 2>/dev/null | grep -o "\"name\":\"${instance_name}\"" || true)

    if [[ -n "${status}" ]]; then
        echo "錯誤：Workspace '${instance_name}' 已存在，請使用 workspace start 啟動"
        return 1
    fi

    echo "建立並啟動 Workspace '${instance_name}'..."
    echo "  VM 類型: ${LIMA_VM_TYPE}, 掛載方式: ${LIMA_MOUNT_TYPE}"
    echo "  CPU: ${cpus}, 記憶體: ${memory}, 磁碟: ${disk}"
    echo "  掛載目錄: ${workspace_path} -> /workspace"

    local tmp_template
    tmp_template=$(mktemp /tmp/kde-workspace-XXXXXX.yaml)

    sed \
        -e "s|{{WORKSPACE_PATH}}|${workspace_path}|g" \
        -e "s|{{CPUS}}|${cpus}|g" \
        -e "s|{{MEMORY}}|${memory}|g" \
        -e "s|{{DISK}}|${disk}|g" \
        -e "s|{{KDE_CLI_PATH}}|${KDE_CLI_PATH}|g" \
        -e "s|{{VM_TYPE}}|${LIMA_VM_TYPE}|g" \
        -e "s|{{MOUNT_TYPE}}|${LIMA_MOUNT_TYPE}|g" \
        -e "s|{{HOME_PATH}}|${HOME}|g" \
        "${LIMA_TEMPLATE_PATH}" > "${tmp_template}"

    limactl start --name="${instance_name}" "${tmp_template}" --tty=false
    rm -f "${tmp_template}"

    echo "Workspace '${instance_name}' 已建立並啟動"

    # 執行 workspace hooks
    source "${KDE_SCRIPTS_PATH}/utils/workspace/hooks.sh"
    run_workspace_hooks "init" "$workspace_path"
    run_workspace_hooks "start" "$workspace_path"
}

workspace_start() {
    local instance_name=$1
    local workspace_path=$2

    if [[ $(_workspace_lima_is_running "${instance_name}") == "true" ]]; then
        echo "Workspace '${instance_name}' 已經在運行中"
        return 0
    fi

    local status
    status=$(limactl list --json 2>/dev/null | grep -o "\"name\":\"${instance_name}\"" || true)

    if [[ -z "${status}" ]]; then
        echo "錯誤：Workspace '${instance_name}' 不存在，請先使用 workspace create 建立"
        return 1
    fi

    echo "啟動已存在的 Workspace '${instance_name}'..."
    limactl start "${instance_name}"
    echo "Workspace '${instance_name}' 已啟動"

    # 執行 workspace hooks
    source "${KDE_SCRIPTS_PATH}/utils/workspace/hooks.sh"
    run_workspace_hooks "start" "$workspace_path"
}

workspace_stop() {
    local instance_name=$1

    if [[ $(_workspace_lima_is_running "${instance_name}") == "false" ]]; then
        echo "Workspace '${instance_name}' 未在運行中"
        return 0
    fi

    # 停止前清理所有 port 轉發
    _workspace_lima_expose_stop_all

    # 停止前自動保存 tmux session
    _workspace_lima_tmux_save "${instance_name}"

    echo "停止 Workspace '${instance_name}'..."
    limactl stop "${instance_name}"
    echo "Workspace '${instance_name}' 已停止"
}

workspace_delete() {
    local instance_name=$1
    local force=$2

    local exists
    exists=$(limactl list --json 2>/dev/null | python3 -c "
import sys, json
for line in sys.stdin:
    obj = json.loads(line)
    if obj.get('name') == '${instance_name}':
        print('yes')
        sys.exit(0)
print('no')
" 2>/dev/null)

    if [[ "${exists}" != "yes" ]]; then
        echo "Workspace '${instance_name}' 不存在"
        return 1
    fi

    if [[ "${force}" != "true" ]]; then
        read -p "確定要刪除 Workspace '${instance_name}'？此操作無法復原 [y/N]: " confirm
        if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
            echo "已取消刪除"
            return 0
        fi
    fi

    if [[ $(_workspace_lima_is_running "${instance_name}") == "true" ]]; then
        workspace_stop "${instance_name}"
    fi

    echo "刪除 Workspace '${instance_name}'..."
    limactl delete "${instance_name}" --force
    rm -rf "${WORKSPACE_DATA_DIR}/expose"
    echo "Workspace '${instance_name}' 已刪除"
}

workspace_exec() {
    local instance_name=$1
    shift

    local use_tmux=false
    local args=()
    for arg in "$@"; do
        if [[ "$arg" == "--tmux" ]]; then
            use_tmux=true
        else
            args+=("$arg")
        fi
    done
    local command="${args[*]}"

    if [[ $(_workspace_lima_is_running "${instance_name}") == "false" ]]; then
        echo "錯誤：Workspace '${instance_name}' 未在運行中"
        echo "請先執行 kde workspace start"
        exit 1
    fi

    if [[ -n "${command}" ]]; then
        limactl shell --workdir /workspace "${instance_name}" ${command}
    elif [[ "${use_tmux}" == "true" ]]; then
        limactl shell --workdir /workspace "${instance_name}" \
            bash -c 'if tmux has-session -t kde 2>/dev/null; then
                tmux attach-session -t kde
            else
                tmux new-session -s kde
            fi'
    else
        limactl shell --workdir /workspace "${instance_name}"
    fi
}

workspace_info() {
    local instance_name=$1

    local info
    info=$(limactl list --json 2>/dev/null | python3 -c "
import sys, json
for line in sys.stdin:
    obj = json.loads(line)
    if obj.get('name') == '${instance_name}':
        status = obj.get('status', 'Unknown')
        cpus = obj.get('cpus', 'N/A')
        memory = obj.get('memory', 0)
        disk = obj.get('disk', 0)
        mem_gib = memory // (1024**3) if memory else 'N/A'
        disk_gib = disk // (1024**3) if disk else 'N/A'
        arch = obj.get('arch', 'N/A')
        vm_type = obj.get('vmType', 'N/A')
        print(f'名稱:       {obj[\"name\"]}')
        print(f'狀態:       {status}')
        print(f'架構:       {arch}')
        print(f'VM 類型:    {vm_type}')
        print(f'CPU:        {cpus}')
        print(f'記憶體:     {mem_gib} GiB')
        print(f'磁碟:       {disk_gib} GiB')
        sys.exit(0)
print('NOT_FOUND')
" 2>/dev/null)

    if [[ "${info}" == "NOT_FOUND" || -z "${info}" ]]; then
        echo "Workspace '${instance_name}' 不存在"
        echo "請執行 kde workspace create 建立"
        return 1
    fi

    echo "${info}"
}

workspace_connect() {
    local instance_name="$1"
    workspace_exec "$instance_name"
}

workspace_status() {
    local instance_name="$1"
    if [[ $(_workspace_lima_is_running "$instance_name") == "true" ]]; then
        echo "reachable"
    else
        echo "unreachable"
    fi
}

workspace_snapshot() {
    local instance_name="$1"
    local subcmd="$2"
    shift 2
    case "$subcmd" in
        create)  _workspace_lima_snapshot_create "$instance_name" "$@" ;;
        list)    _workspace_lima_snapshot_list "$instance_name" ;;
        restore) _workspace_lima_snapshot_restore "$instance_name" "$@" ;;
        *)       echo "usage: workspace_snapshot <instance> <create|list|restore> [tag]"; return 1 ;;
    esac
}

workspace_expose() {
    local instance_name="$1"
    local subcmd_or_port="$2"
    shift 2
    case "$subcmd_or_port" in
        list)     _workspace_lima_expose_list ;;
        stop)     _workspace_lima_expose_stop "$1" ;;
        stop-all) _workspace_lima_expose_stop_all ;;
        *)        _workspace_lima_expose_forward "$instance_name" "$subcmd_or_port" "$@" ;;
    esac
}

_workspace_lima_is_running() {
    local instance_name=$1

    local status
    status=$(limactl list --json 2>/dev/null | python3 -c "
import sys, json
for line in sys.stdin:
    obj = json.loads(line)
    if obj.get('name') == '${instance_name}':
        print(obj.get('status', ''))
        sys.exit(0)
print('')
" 2>/dev/null)

    if [[ "${status}" == "Running" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

_workspace_lima_snapshot_create() {
    local instance_name=$1
    local tag=$2

    if [[ -z "${tag}" ]]; then
        echo "錯誤：請指定快照名稱"
        echo "用法：kde workspace snapshot create <tag>"
        exit 1
    fi

    if [[ $(_workspace_lima_is_running "${instance_name}") == "true" ]]; then
        echo "建立快照前先停止 Workspace..."
        workspace_stop "${instance_name}"
    fi

    echo "建立快照 '${tag}'..."
    limactl snapshot create "${instance_name}" --tag "${tag}"
    echo "快照 '${tag}' 已建立"

    echo "重新啟動 Workspace..."
    limactl start "${instance_name}"
}

_workspace_lima_snapshot_list() {
    local instance_name=$1

    local exists
    exists=$(limactl list --json 2>/dev/null | python3 -c "
import sys, json
for line in sys.stdin:
    obj = json.loads(line)
    if obj.get('name') == '${instance_name}':
        print('yes')
        sys.exit(0)
print('no')
" 2>/dev/null)

    if [[ "${exists}" != "yes" ]]; then
        echo "Workspace '${instance_name}' 不存在"
        return 1
    fi

    limactl snapshot list "${instance_name}"
}

_workspace_lima_snapshot_restore() {
    local instance_name=$1
    local tag=$2

    if [[ -z "${tag}" ]]; then
        echo "錯誤：請指定快照名稱"
        echo "用法：kde workspace snapshot restore <tag>"
        exit 1
    fi

    if [[ $(_workspace_lima_is_running "${instance_name}") == "true" ]]; then
        echo "還原快照前先停止 Workspace..."
        workspace_stop "${instance_name}"
    fi

    echo "還原快照 '${tag}'..."
    limactl snapshot apply "${instance_name}" --tag "${tag}"
    echo "快照 '${tag}' 已還原"

    echo "重新啟動 Workspace..."
    limactl start "${instance_name}"
}

_workspace_lima_expose_forward() {
    local instance_name=$1
    local guest_port=$2
    local host_port=${3:-${guest_port}}
    local expose_dir="${WORKSPACE_DATA_DIR}/expose"
    local pid_file="${expose_dir}/${host_port}.pid"
    local ssh_config="${LIMA_HOME}/${instance_name}/ssh.config"

    if [[ $(_workspace_lima_is_running "${instance_name}") == "false" ]]; then
        echo "錯誤：Workspace '${instance_name}' 未在運行中"
        exit 1
    fi

    if [[ ! -f "${ssh_config}" ]]; then
        echo "錯誤：SSH config 不存在：${ssh_config}"
        exit 1
    fi

    if [[ -f "${pid_file}" ]]; then
        local old_pid
        old_pid=$(cat "${pid_file}")
        if kill -0 "${old_pid}" 2>/dev/null; then
            echo "Host port ${host_port} 已有轉發在運行中 (PID: ${old_pid})"
            return 0
        fi
        rm -f "${pid_file}"
    fi

    mkdir -p "${expose_dir}"

    ssh -F "${ssh_config}" \
        -L "${host_port}:localhost:${guest_port}" \
        -N -f "lima-${instance_name}"

    local ssh_pid
    ssh_pid=$(ps aux | grep "ssh.*-L.*${host_port}:localhost:${guest_port}.*lima-${instance_name}" | grep -v grep | awk '{print $2}' | head -1)

    if [[ -n "${ssh_pid}" ]]; then
        echo "${ssh_pid}" > "${pid_file}"
        echo "${guest_port}" > "${expose_dir}/${host_port}.guest"
        echo "已建立轉發：VM:${guest_port} -> Host:${host_port} (PID: ${ssh_pid})"
    else
        echo "錯誤：無法建立 SSH tunnel"
        exit 1
    fi
}

_workspace_lima_expose_list() {
    local expose_dir="${WORKSPACE_DATA_DIR}/expose"

    if [[ ! -d "${expose_dir}" ]] || [[ -z "$(ls -A "${expose_dir}"/*.pid 2>/dev/null)" ]]; then
        echo "目前沒有活躍的 port 轉發"
        return 0
    fi

    printf "%-12s %-12s %-10s\n" "HOST PORT" "GUEST PORT" "PID"
    printf "%-12s %-12s %-10s\n" "---------" "----------" "---"

    for pid_file in "${expose_dir}"/*.pid; do
        local host_port
        host_port=$(basename "${pid_file}" .pid)
        local pid
        pid=$(cat "${pid_file}")
        local guest_port="N/A"
        if [[ -f "${expose_dir}/${host_port}.guest" ]]; then
            guest_port=$(cat "${expose_dir}/${host_port}.guest")
        fi

        if kill -0 "${pid}" 2>/dev/null; then
            printf "%-12s %-12s %-10s\n" "${host_port}" "${guest_port}" "${pid}"
        else
            rm -f "${pid_file}" "${expose_dir}/${host_port}.guest"
        fi
    done
}

_workspace_lima_expose_stop() {
    local host_port=$1
    local expose_dir="${WORKSPACE_DATA_DIR}/expose"
    local pid_file="${expose_dir}/${host_port}.pid"

    if [[ ! -f "${pid_file}" ]]; then
        echo "Host port ${host_port} 沒有活躍的轉發"
        return 1
    fi

    local pid
    pid=$(cat "${pid_file}")

    if kill -0 "${pid}" 2>/dev/null; then
        kill "${pid}"
        echo "已停止轉發：Host:${host_port} (PID: ${pid})"
    fi

    rm -f "${pid_file}" "${expose_dir}/${host_port}.guest"
}

_workspace_lima_expose_stop_all() {
    local expose_dir="${WORKSPACE_DATA_DIR}/expose"

    if [[ ! -d "${expose_dir}" ]]; then
        return 0
    fi

    local has_active=false
    for pid_file in "${expose_dir}"/*.pid; do
        [[ -f "${pid_file}" ]] || continue
        has_active=true
        local host_port
        host_port=$(basename "${pid_file}" .pid)
        _workspace_lima_expose_stop "${host_port}"
    done

    if [[ "${has_active}" == "true" ]]; then
        echo "所有轉發已停止"
    fi
}

_workspace_lima_tmux_save() {
    local instance_name=$1

    local has_tmux
    has_tmux=$(limactl shell "${instance_name}" -- bash -c 'command -v tmux && tmux has-session -t kde 2>/dev/null && echo "yes" || echo "no"' 2>/dev/null)

    if [[ "${has_tmux}" == *"yes"* ]]; then
        echo "保存 tmux session..."
        limactl shell "${instance_name}" -- bash -c '
            if [ -d ~/.tmux/plugins/tmux-resurrect ]; then
                ~/.tmux/plugins/tmux-resurrect/scripts/save.sh
            fi
        ' 2>/dev/null || true
    fi
}
