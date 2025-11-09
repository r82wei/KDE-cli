import { z } from 'zod';
import { ProcessRunner } from '../lib/runner';

export const ExecuteKdeInput = z.object({
  args: z.array(z.string()).nonempty().describe('kde 子命令參數，例如 ["kde","status"] 或 ["kde","project","list"]'),
  timeoutMs: z.number().int().positive().optional(),
  cwd: z.string().optional(),
});

export type ExecuteKdeInput = z.infer<typeof ExecuteKdeInput>;

export async function executeKde(input: ExecuteKdeInput, onProgress?: (data: { type: 'stdout' | 'stderr', chunk: string }) => void) {
  const runner = new ProcessRunner();
  runner.on('progress', (evt: any) => {
    if ((evt.type === 'stdout' || evt.type === 'stderr') && onProgress) {
      onProgress({ type: evt.type, chunk: evt.data ?? '' });
    }
  });
  const result = await runner.runKde(input.args, {
    cwd: input.cwd,
    timeoutMs: input.timeoutMs,
  });
  return result;
}


