#!/bin/bash

SERVER_DIR="/Users/maxime/SideProjects/KDE-cli/script/mcp-server"
SERVER_DIST="${SERVER_DIR}/dist/server.js"
PORT="${PORT:-3333}"
HOST="0.0.0.0"
TOKEN="${MCP_SERVER_TOKEN}"
CORS_ORIGINS="${CORS_ORIGINS}"

show_help() {
    echo "usage:"
    echo "  kde mcp-server [-p port] [--token <token>] [--cors <origins>]"
    echo ""
    echo "options:"
    echo "  -p, --port <port>          指定 HTTP 監聽埠（預設 3333）"
    echo "  --token <token>            設定 Bearer Token（亦可使用 MCP_SERVER_TOKEN 環境變數）"
    echo "  --cors <origins>           以逗號分隔之 CORS 來源白名單"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        --token)
            TOKEN="$2"
            shift 2
            ;;
        --cors)
            CORS_ORIGINS="$2"
            shift 2
            ;;
        *)
            echo "未知參數: $1"
            show_help
            exit 1
            ;;
    esac
done

export PORT="${PORT}"
export HOST="${HOST}"
export MCP_SERVER_TOKEN="${TOKEN}"
export CORS_ORIGINS="${CORS_ORIGINS}"

if [[ -f "${SERVER_DIST}" ]]; then
    node "${SERVER_DIST}"
else
    if command -v npx >/dev/null 2>&1 && [[ -f "${SERVER_DIR}/package.json" ]]; then
        (cd "${SERVER_DIR}" && npx ts-node-dev --respawn --transpile-only src/server.ts)
    else
        echo "找不到 ${SERVER_DIST}，且無法以 ts-node-dev 啟動。請先在 ${SERVER_DIR} 執行："
        echo "  npm install && npm run build"
        exit 1
    fi
fi


