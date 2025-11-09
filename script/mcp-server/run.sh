#!/bin/sh
set -e
PORT="${PORT:-3333}"
HOST="${HOST:-0.0.0.0}"
if [ -z "${MCP_SERVER_TOKEN}" ]; then
  echo "MCP_SERVER_TOKEN is required"
  exit 1
fi
node dist/server.js


