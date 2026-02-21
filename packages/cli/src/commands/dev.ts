import { Command } from 'commander'
import { spawn } from 'node:child_process'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { watch } from 'chokidar'
import { WebSocketServer, WebSocket } from 'ws'
import pc from 'picocolors'

const DEFAULT_PORT = 8174
const BUNDLE_FILE = 'dist/vue-native-bundle.js'

export const devCommand = new Command('dev')
  .description('Start the Vue Native dev server with hot reload')
  .option('-p, --port <port>', 'WebSocket port for hot reload', String(DEFAULT_PORT))
  .action(async (options: { port: string }) => {
    const port = parseInt(options.port, 10)
    const cwd = process.cwd()
    const bundlePath = join(cwd, BUNDLE_FILE)

    console.log(pc.cyan('\n⚡ Vue Native Dev Server\n'))

    // Start WebSocket server for hot reload
    const wss = new WebSocketServer({ port })
    const clients = new Set<WebSocket>()

    wss.on('connection', (ws) => {
      clients.add(ws)
      ws.send(JSON.stringify({ type: 'connected' }))
      console.log(pc.green(`  iOS client connected (${clients.size} total)`))

      // Send current bundle immediately on connect
      readFile(bundlePath, 'utf8')
        .then(bundle => {
          if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: 'bundle', bundle }))
            console.log(pc.dim(`  Sent bundle to new client (${Math.round(bundle.length / 1024)}KB)`))
          }
        })
        .catch(() => {
          // Bundle not built yet — that's fine, it'll come after first build
        })

      ws.on('close', () => {
        clients.delete(ws)
        console.log(pc.dim(`  iOS client disconnected (${clients.size} remaining)`))
      })

      ws.on('message', (data) => {
        try {
          const msg = JSON.parse(data.toString())
          if (msg.type === 'pong') return // keep-alive
        } catch {}
      })
    })

    wss.on('error', (err) => {
      console.error(pc.red(`WebSocket server error: ${err.message}`))
    })

    console.log(pc.white(`  Hot reload server: ${pc.bold(`ws://localhost:${port}`)}`))
    console.log(pc.dim('  Waiting for iOS app to connect...\n'))

    // Start Vite in watch mode
    console.log(pc.white('  Starting Vite build watcher...\n'))
    const vite = spawn(
      'bun',
      ['run', 'vite', 'build', '--watch', '--mode', 'development'],
      { cwd, stdio: 'pipe' }
    )

    vite.stdout?.on('data', (data: Buffer) => {
      const text = data.toString().trim()
      if (text) console.log(pc.dim(`  [vite] ${text}`))
    })

    vite.stderr?.on('data', (data: Buffer) => {
      const text = data.toString().trim()
      if (text) console.log(pc.yellow(`  [vite] ${text}`))
    })

    vite.on('error', (err) => {
      console.error(pc.red(`Vite error: ${err.message}`))
    })

    // Watch for bundle file changes and broadcast to clients
    const watcher = watch(bundlePath, {
      persistent: true,
      ignoreInitial: false,
      awaitWriteFinish: { stabilityThreshold: 100, pollInterval: 50 },
    })

    watcher.on('add', broadcastBundle)
    watcher.on('change', broadcastBundle)

    async function broadcastBundle() {
      try {
        const bundle = await readFile(bundlePath, 'utf8')
        const payload = JSON.stringify({ type: 'bundle', bundle })
        let sent = 0
        for (const client of clients) {
          if (client.readyState === WebSocket.OPEN) {
            client.send(payload)
            sent++
          }
        }
        console.log(pc.green(`  ✓ Bundle updated (${Math.round(bundle.length / 1024)}KB) → sent to ${sent} client(s)`))
      } catch (err) {
        // File not ready yet
      }
    }

    // Keep-alive ping every 30s
    setInterval(() => {
      for (const client of clients) {
        if (client.readyState === WebSocket.OPEN) {
          client.send(JSON.stringify({ type: 'ping' }))
        }
      }
    }, 30_000)

    // Handle graceful shutdown
    process.on('SIGINT', () => {
      console.log(pc.yellow('\n  Shutting down dev server...'))
      vite.kill()
      wss.close()
      process.exit(0)
    })
  })
