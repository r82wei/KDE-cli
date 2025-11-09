# KDE MCP Server (HTTP/SSE)

提供 HTTP/SSE 端點讓 AI Agent 透過 `kde` 指令完成開發、驗證、部署與除錯。

## 啟動

以 KDE CLI 啟動：

```bash
kde mcp-server -p 3333 --token <YOUR_TOKEN>
```

或在專案內啟動（首次需安裝依賴並建置）：

```bash
cd script/mcp-server
npm install
npm run build
PORT=3333 MCP_SERVER_TOKEN=<YOUR_TOKEN> node dist/server.js
```

## 健康檢查

```bash
curl http://127.0.0.1:3333/healthz
```

## 呼叫工具：executeKde

1) 建立任務：

```bash
curl -X POST "http://127.0.0.1:3333/mcp/tool/executeKde" \
  -H "Authorization: Bearer <YOUR_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"args":["kde","status"]}'
```

回應：

```json
{"jobId":"job_..."} 
```

2) 查詢任務：

```bash
curl -H "Authorization: Bearer <YOUR_TOKEN>" \
  "http://127.0.0.1:3333/mcp/job/<jobId>"
```

3) 串流輸出（SSE）：

```bash
curl -H "Authorization: Bearer <YOUR_TOKEN>" \
  "http://127.0.0.1:3333/mcp/sse?jobId=<jobId>"
```

## CORS

可用環境變數設定：

- `CORS_ORIGINS`: 以逗號分隔，例如：`http://localhost:11434,http://localhost:3000`

## 環境變數

- `PORT`（預設 3333）
- `HOST`（固定 0.0.0.0）
- `MCP_SERVER_TOKEN`（必填）
- `CORS_ORIGINS`（可選）


