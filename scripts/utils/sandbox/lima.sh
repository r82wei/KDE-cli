#!/bin/bash

LIMA_TEMPLATE_PATH=${KDE_TEMPLATES_PATH}/lima/kde-sandbox.yaml

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
            if [[ -e /dev/kvm ]]; then
                LIMA_MOUNT_TYPE="virtiofs"
            else
                LIMA_MOUNT_TYPE="9p"
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

sandbox_start() {
    local instance_name=$1
    local workspace_path=$2
    local cpus=${KDE_SANDBOX_CPUS:-2}
    local memory=${KDE_SANDBOX_MEMORY:-4GiB}
    local disk=${KDE_SANDBOX_DISK:-50GiB}

    if [[ $(sandbox_is_running "${instance_name}") == "true" ]]; then
        echo "Sandbox '${instance_name}' 已經在運行中"
        return 0
    fi

    local status
    status=$(limactl list --json 2>/dev/null | grep -o "\"name\":\"${instance_name}\"" || true)

    if [[ -n "${status}" ]]; then
        echo "啟動已存在的 Sandbox '${instance_name}'..."
        limactl start "${instance_name}"
    else
        echo "建立並啟動 Sandbox '${instance_name}'..."
        echo "  VM 類型: ${LIMA_VM_TYPE}, 掛載方式: ${LIMA_MOUNT_TYPE}"
        echo "  CPU: ${cpus}, 記憶體: ${memory}, 磁碟: ${disk}"
        echo "  掛載目錄: ${workspace_path} -> /workspace"

        local tmp_template
        tmp_template=$(mktemp /tmp/kde-sandbox-XXXXXX.yaml)

        sed \
            -e "s|{{WORKSPACE_PATH}}|${workspace_path}|g" \
            -e "s|{{CPUS}}|${cpus}|g" \
            -e "s|{{MEMORY}}|${memory}|g" \
            -e "s|{{DISK}}|${disk}|g" \
            -e "s|{{KDE_CLI_PATH}}|${KDE_CLI_PATH}|g" \
            -e "s|{{VM_TYPE}}|${LIMA_VM_TYPE}|g" \
            -e "s|{{MOUNT_TYPE}}|${LIMA_MOUNT_TYPE}|g" \
            "${LIMA_TEMPLATE_PATH}" > "${tmp_template}"

        limactl start --name="${instance_name}" "${tmp_template}" --tty=false
        rm -f "${tmp_template}"
    fi

    echo "Sandbox '${instance_name}' 已啟動"
}

sandbox_stop() {
    local instance_name=$1

    if [[ $(sandbox_is_running "${instance_name}") == "false" ]]; then
        echo "Sandbox '${instance_name}' 未在運行中"
        return 0
    fi

    # 停止前自動保存 tmux session
    sandbox_tmux_save "${instance_name}"

    echo "停止 Sandbox '${instance_name}'..."
    limactl stop "${instance_name}"
    echo "Sandbox '${instance_name}' 已停止"
}

sandbox_exec() {
    local instance_name=$1
    shift
    local command="$@"

    if [[ $(sandbox_is_running "${instance_name}") == "false" ]]; then
        echo "錯誤：Sandbox '${instance_name}' 未在運行中"
        echo "請先執行 kde sandbox start"
        exit 1
    fi

    if [[ -n "${command}" ]]; then
        limactl shell "${instance_name}" --workdir /workspace ${command}
    else
        # 無指令時進入 tmux session
        limactl shell "${instance_name}" --workdir /workspace \
            bash -c 'if command -v tmux &>/dev/null; then
                if tmux has-session -t kde 2>/dev/null; then
                    tmux attach-session -t kde
                else
                    tmux new-session -s kde
                fi
            else
                bash
            fi'
    fi
}

sandbox_status() {
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
        echo "Sandbox '${instance_name}' 不存在"
        echo "請執行 kde sandbox start 建立"
        return 1
    fi

    echo "${info}"
}

sandbox_is_running() {
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

sandbox_snapshot_create() {
    local instance_name=$1
    local tag=$2

    if [[ -z "${tag}" ]]; then
        echo "錯誤：請指定快照名稱"
        echo "用法：kde sandbox snapshot create <tag>"
        exit 1
    fi

    if [[ $(sandbox_is_running "${instance_name}") == "true" ]]; then
        echo "建立快照前先停止 Sandbox..."
        sandbox_stop "${instance_name}"
    fi

    echo "建立快照 '${tag}'..."
    limactl snapshot create "${instance_name}" --tag "${tag}"
    echo "快照 '${tag}' 已建立"

    echo "重新啟動 Sandbox..."
    limactl start "${instance_name}"
}

sandbox_snapshot_list() {
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
        echo "Sandbox '${instance_name}' 不存在"
        return 1
    fi

    limactl snapshot list "${instance_name}"
}

sandbox_snapshot_restore() {
    local instance_name=$1
    local tag=$2

    if [[ -z "${tag}" ]]; then
        echo "錯誤：請指定快照名稱"
        echo "用法：kde sandbox snapshot restore <tag>"
        exit 1
    fi

    if [[ $(sandbox_is_running "${instance_name}") == "true" ]]; then
        echo "還原快照前先停止 Sandbox..."
        sandbox_stop "${instance_name}"
    fi

    echo "還原快照 '${tag}'..."
    limactl snapshot apply "${instance_name}" --tag "${tag}"
    echo "快照 '${tag}' 已還原"

    echo "重新啟動 Sandbox..."
    limactl start "${instance_name}"
}

sandbox_tmux_save() {
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
