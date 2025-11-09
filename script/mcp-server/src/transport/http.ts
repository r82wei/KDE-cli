import express from 'express';
import cors from 'cors';
import { z } from 'zod';
import { ExecuteKdeInput } from '../tools';

type JobStatus = 'queued' | 'running' | 'completed' | 'failed';
type JobRecord = {
  id: string;
  status: JobStatus;
  stdout: string[];
  stderr: string[];
  code: number | null;
  createdAt: number;
  updatedAt: number;
  error?: string;
};

export type RunExecuteKde = (input: z.infer<typeof ExecuteKdeInput>, onProgress?: (data: { type: 'stdout' | 'stderr', chunk: string }) => void) => Promise<{
  code: number | null;
  stdout: string;
  stderr: string;
}>;

export function createHttpTransport(app: express.Express, opts: {
  token?: string;
  corsOrigins?: string[];
  runExecuteKde: RunExecuteKde;
}) {
  const jobs = new Map<string, JobRecord>();

  // CORS
  const corsOrigins = (opts.corsOrigins ?? [])
    .map(s => s.trim())
    .filter(Boolean);
  app.use(cors({
    origin: (origin, callback) => {
      if (!origin || corsOrigins.length === 0) return callback(null, true);
      if (corsOrigins.includes(origin)) return callback(null, true);
      return callback(new Error('Not allowed by CORS'));
    },
    credentials: true,
  }));
  app.use(express.json({ limit: '2mb' }));

  // Auth
  app.use((req, res, next) => {
    if (req.path === '/healthz') return next();
    const hdr = req.header('authorization') || '';
    const token = hdr.startsWith('Bearer ') ? hdr.slice('Bearer '.length) : '';
    if (!opts.token) {
      return res.status(401).json({ error: 'MCP_SERVER_TOKEN not set on server' });
    }
    if (token !== opts.token) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    next();
  });

  // Health
  app.get('/healthz', (_req, res) => res.send('ok'));

  // Create job
  app.post('/mcp/tool/executeKde', async (req, res) => {
    const parse = ExecuteKdeInput.safeParse(req.body);
    if (!parse.success) {
      return res.status(400).json({ error: 'Invalid input', details: parse.error.flatten() });
    }
    const id = `job_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    const job: JobRecord = {
      id,
      status: 'queued',
      stdout: [],
      stderr: [],
      code: null,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    };
    jobs.set(id, job);
    res.json({ jobId: id });

    // Run in background
    job.status = 'running';
    job.updatedAt = Date.now();
    try {
      const result = await opts.runExecuteKde(parse.data, (p) => {
        if (p.type === 'stdout') job.stdout.push(p.chunk);
        else job.stderr.push(p.chunk);
        job.updatedAt = Date.now();
      });
      job.code = result.code;
      if (result.code === 0) job.status = 'completed';
      else job.status = 'failed';
      job.updatedAt = Date.now();
    } catch (err: any) {
      job.status = 'failed';
      job.error = err?.message ?? String(err);
      job.updatedAt = Date.now();
    }
  });

  // Get job status
  app.get('/mcp/job/:id', (req, res) => {
    const job = jobs.get(req.params.id);
    if (!job) return res.status(404).json({ error: 'Job not found' });
    res.json({
      id: job.id,
      status: job.status,
      code: job.code,
      stdout: job.stdout.join(''),
      stderr: job.stderr.join(''),
      error: job.error,
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
    });
  });

  // SSE stream
  app.get('/mcp/sse', (req, res) => {
    const jobId = String(req.query.jobId || '');
    const job = jobs.get(jobId);
    if (!job) {
      res.status(404).end();
      return;
    }
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders?.();

    // push existing
    const send = (event: string, data: any) => {
      res.write(`event: ${event}\n`);
      res.write(`data: ${JSON.stringify(data)}\n\n`);
    };
    if (job.stdout.length) send('stdout', { chunk: job.stdout.join('') });
    if (job.stderr.length) send('stderr', { chunk: job.stderr.join('') });
    if (job.status === 'completed' || job.status === 'failed') {
      send('done', { status: job.status, code: job.code, error: job.error });
      res.end();
      return;
    }

    // Polling fallback for demo simplicity
    let cursorStdout = job.stdout.length;
    let cursorStderr = job.stderr.length;
    const interval = setInterval(() => {
      const j = jobs.get(jobId);
      if (!j) return;
      if (j.stdout.length > cursorStdout) {
        const chunk = j.stdout.slice(cursorStdout).join('');
        cursorStdout = j.stdout.length;
        send('stdout', { chunk });
      }
      if (j.stderr.length > cursorStderr) {
        const chunk = j.stderr.slice(cursorStderr).join('');
        cursorStderr = j.stderr.length;
        send('stderr', { chunk });
      }
      if (j.status === 'completed' || j.status === 'failed') {
        send('done', { status: j.status, code: j.code, error: j.error });
        clearInterval(interval);
        res.end();
      }
    }, 1000);

    req.on('close', () => clearInterval(interval));
  });
}


