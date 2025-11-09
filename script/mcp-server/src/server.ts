import express from 'express';
import { createHttpTransport } from './transport/http';
import { executeKde } from './tools';

const app = express();

const PORT = Number(process.env.PORT || 3333);
const HOST = process.env.HOST || '0.0.0.0';
const TOKEN = process.env.MCP_SERVER_TOKEN || '';
const CORS_ORIGINS = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map(s => s.trim())
  .filter(Boolean);

createHttpTransport(app, {
  token: TOKEN,
  corsOrigins: CORS_ORIGINS,
  runExecuteKde: executeKde,
});

app.listen(PORT, HOST, () => {
  // eslint-disable-next-line no-console
  console.log(`KDE MCP Server listening on http://${HOST}:${PORT}`);
});


