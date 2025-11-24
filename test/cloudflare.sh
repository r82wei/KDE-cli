#!/bin/bash

# 設定 KDE 根目錄路徑
export KDE_PATH=$PWD
# 設定 KDE scripts 路徑
export KDE_SCRIPTS_PATH=${KDE_PATH}/scripts

source ${KDE_PATH}/kde.env
source ${KDE_SCRIPTS_PATH}/utils/cloudflare.sh

# cloudflare_login
# cloudflare_create_tunnel "test.maximema.dev" "http://localhost:8089"
# echo "Tunnel ID of test.maximema.dev: $(cloudflare_get_tunnel_id 'test.maximema.dev')"
# cloudflare_tunnel_url "test.maximema.dev" "http://localhost:8089" "host" "try"
echo "Tunnel ID of test.maximema.dev: $(cloudflare_get_tunnel_id "tunnel.maximema.dev")"
# cloudflare_delete_tunnel "test.maximema.dev"


# cloudflare quick tunnel
# cloudflare_quick_tunnel_url "http://localhost:8089" "host"