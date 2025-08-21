#!/bin/bash

# 定義顯示說明的函數
show_help() {
    echo "usage:"
    echo "  kde alias <name> [path]   建立 bash alias 指令，透過 tmux 快速啟動 session 到指定路徑的目錄"
    echo "  "
    echo -e "  \033[31m注意：需要安裝 tmux 才能使用此功能\033[0m"
    echo "  "
    echo "  name: 指令名稱"
    echo "  path: 指定要進入的目錄，如果沒有指定，預設為當前目錄"
    echo "  "
    echo "  example:"
    echo "    kde alias workspace ~/path/to/workspace"
    echo "    kde alias workspace"
}

create_alias_tmux() {
    name=$1
    path=$2

    if [ -f ~/.bashrc ]; then   
        echo "alias ${name}='tmux new-session -A -s ${name} -c ${path}'" >> ~/.bashrc
        source ~/.bashrc
        echo "已在 ~/.bashrc 中建立 alias 指令，請執行 'source ~/.bashrc' 使設定生效"
    fi

    if [ -f ~/.zshrc ]; then
        echo "alias ${name}='tmux new-session -A -s ${name} -c ${path}'" >> ~/.zshrc
        source ~/.zshrc
        echo "已在 ~/.zshrc 中建立 alias 指令，請執行 'source ~/.zshrc' 使設定生效"
    fi
}

# 檢查輸入參數的數量，依照參數數量來決定要執行的流程
case "$#" in
    0)
        show_help
        ;;
    1)
        case "$1" in
            -h|--help)
                show_help
                ;;
            *)
                create_alias_tmux $1 $PWD
                ;;
        esac
        ;;
    2)
        create_alias_tmux $1 $2
        ;;
esac
