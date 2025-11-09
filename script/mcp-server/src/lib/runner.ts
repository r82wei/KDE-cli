import { spawn } from 'child_process';
import { EventEmitter } from 'events';

export type RunOptions = {
  cwd?: string;
  timeoutMs?: number;
  env?: NodeJS.ProcessEnv;
};

export type RunResult = {
  code: number | null;
  stdout: string;
  stderr: string;
};

export type RunProgressEvent = {
  type: 'stdout' | 'stderr' | 'exit';
  data?: string;
  code?: number | null;
};

export class ProcessRunner extends EventEmitter {
  private killed = false;

  runKde(args: string[], options: RunOptions = {}): Promise<RunResult> {
    if (!Array.isArray(args) || args.length === 0) {
      throw new Error('args must be a non-empty array');
    }

    // 僅允許執行 kde 子命令
    const [first, ...rest] = args;
    if (first !== 'kde') {
      throw new Error('Only "kde" commands are allowed');
    }

    // 簡單白名單（可視需求擴充）
    const allowed = new Set([
      'init', 'list', 'ls', 'start', 'create', 'stop', 'restart',
      'status', 'remove', 'rm', 'current', 'cur', 'use', 'load-image',
      'k9s', 'dashboard', 'headlamp', 'expose', 'exec', 'reset',
      'project', 'proj', 'namespace', 'ns', 'projects', 'projs',
      'ngrok', 'cloudflare-tunnel', 'telepresence', 'code-server'
    ]);
    const sub = rest[0];
    if (!sub || !allowed.has(sub)) {
      throw new Error(`Subcommand not allowed: ${String(sub)}`);
    }

    const child = spawn('kde', rest, {
      cwd: options.cwd ?? process.cwd(),
      env: { ...process.env, ...(options.env ?? {}) },
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdoutBuf = '';
    let stderrBuf = '';

    const onStdout = (chunk: Buffer) => {
      const text = chunk.toString();
      stdoutBuf += text;
      this.emit('progress', <RunProgressEvent>{ type: 'stdout', data: text });
    };

    const onStderr = (chunk: Buffer) => {
      const text = chunk.toString();
      stderrBuf += text;
      this.emit('progress', <RunProgressEvent>{ type: 'stderr', data: text });
    };

    child.stdout?.on('data', onStdout);
    child.stderr?.on('data', onStderr);

    let timeout: NodeJS.Timeout | undefined;
    if (options.timeoutMs && options.timeoutMs > 0) {
      timeout = setTimeout(() => {
        this.killed = true;
        child.kill('SIGKILL');
      }, options.timeoutMs);
    }

    return new Promise<RunResult>((resolve) => {
      child.on('close', (code) => {
        if (timeout) clearTimeout(timeout);
        this.emit('progress', <RunProgressEvent>{ type: 'exit', code });
        resolve({ code, stdout: stdoutBuf, stderr: stderrBuf });
      });
    });
  }

  cancel(): void {
    // 由於目前使用一次性 child process，外部拿不到 child handle
    // 如需主動取消，可改為在外部保存 child 並呼叫 kill。
    // 暫不實作（此類型需要更改 API）。
    this.killed = true;
  }
}


