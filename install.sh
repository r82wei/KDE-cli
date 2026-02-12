#!/bin/bash

git clone https://code.anyong.com.tw/ay/v4/quick-start/kde-env/cli.git

cd KDE-cli

# 安裝 kde 腳本
source ./local-install.sh

cd ..
# 詢問使用者是否要刪除安裝檔案
read -p "是否要刪除安裝檔案？(y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf KDE-cli
    echo "安裝檔案已刪除"
else
    echo "保留安裝檔案"
fi
