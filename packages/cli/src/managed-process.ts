import { spawn, type SpawnOptions } from 'node:child_process'

export interface ManagedProcessOutput {
  stdout?: (data: Buffer) => void
  stderr?: (data: Buffer) => void
}

export interface ManagedProcessResult {
  code: number | null
  signal: NodeJS.Signals | null
}

/**
 * Run a child process until it closes while ensuring it is terminated with the
 * CLI on exit or interruption. Signal listeners are scoped to this invocation
 * so repeated command runs do not accumulate process-level handlers.
 */
export function runManagedProcess(
  command: string,
  args: readonly string[],
  options: SpawnOptions,
  output: ManagedProcessOutput = {},
): Promise<ManagedProcessResult> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, options)
    let settled = false

    const killChild = (signal?: NodeJS.Signals) => {
      if (!child.killed) {
        child.kill(signal)
      }
    }
    const onExit = () => killChild()
    const onSigint = () => killChild('SIGINT')
    const onSigterm = () => killChild('SIGTERM')
    const removeProcessListeners = () => {
      process.removeListener('exit', onExit)
      process.removeListener('SIGINT', onSigint)
      process.removeListener('SIGTERM', onSigterm)
    }
    const settle = (callback: () => void) => {
      if (settled) return
      settled = true
      removeProcessListeners()
      callback()
    }

    process.on('exit', onExit)
    process.on('SIGINT', onSigint)
    process.on('SIGTERM', onSigterm)

    if (output.stdout) {
      child.stdout?.on('data', output.stdout)
    }
    if (output.stderr) {
      child.stderr?.on('data', output.stderr)
    }

    child.on('error', (error) => {
      killChild()
      settle(() => reject(error))
    })
    child.on('close', (code, signal) => {
      settle(() => resolve({ code, signal }))
    })
  })
}
