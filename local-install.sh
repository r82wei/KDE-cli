#!/bin/bash

source ./uninstall.sh

# 安裝 kde 腳本
mkdir -p /usr/local/lib/kde
cp -r kde.sh /usr/local/lib/kde/
cp -r ./scripts /usr/local/lib/kde/
ln -s /usr/local/lib/kde/kde.sh /usr/local/bin/kde
