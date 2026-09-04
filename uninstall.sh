#!/bin/bash

# 解除安裝 kde。
#
# 安裝路徑開放以環境變數覆寫，是為了讓測試不必動到真正的 /usr/local（也就不需要 root）。
LIB_DIR="${KDE_INSTALL_LIB_DIR:-/usr/local/lib/kde}"
BIN_DIR="${KDE_INSTALL_BIN_DIR:-/usr/local/bin}"

# 解除安裝要移除目錄「本身」。這與 local-install.sh 的重裝路徑刻意不同——
# 那裡只清內容、保住 inode，理由見 local-install.sh 的註解。
if [[ -d "${LIB_DIR}" ]]; then
    rm -rf "${LIB_DIR}"
fi

if [[ -L "${BIN_DIR}/kde" ]]; then
    rm -f "${BIN_DIR}/kde"
fi
