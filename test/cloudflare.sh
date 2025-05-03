#!/bin/bash

# 設定 KDE 根目錄路徑
export KDE_PATH=$PWD
# 設定 KDE scripts 路徑
export KDE_SCRIPTS_PATH=${KDE_PATH}/scripts

source ${KDE_SCRIPTS_PATH}/utils/cloudflare.sh

cloudflare_login

cloudflare_create_tunnel "test.maximema.dev" "http://localhost:8089"
echo "Tunnel ID of test.maximema.dev: $(cloudflare_get_tunnel_id 'test.maximema.dev')"
cloudflare_start_tunnel "test.maximema.dev" "host"
cloudflare_delete_tunnel "test.maximema.dev"