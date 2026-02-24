import { Command } from 'commander'
import { spawn, execSync } from 'node:child_process'
import { readFile } from 'node:fs/promises'
import { existsSync } from 'node:fs'
import { join } from 'node:path'
import { watch } from 'chokidar'
import { WebSocketServer, WebSocket } from 'ws'
import pc from 'picocolors'

const DEFAULT_PORT = 8174
const BUNDLE_FILE = 'dist/vue-native-bundle.js'

// ---------------------------------------------------------------------------
// Simulator / emulator detection helpers
// ---------------------------------------------------------------------------

interface SimulatorInfo {
  name: string
  udid: string
  state: string
}

function detectIOSSimulators(): SimulatorInfo[] {
  try {
    const output = execSync('xcrun simctl list devices available -j', {
      stdio: 'pipe',
      encoding: 'utf8',
    })
    const data = JSON.parse(output)
    const simulators: SimulatorInfo[] = []
    for (const [runtime, devices] of Object.entries(data.devices ?? {})) {
      if (!runtime.includes('iOS')) continue
      for (const device of devices as any[]) {
        if (device.isAvailable !== false) {
          simulators.push({
            name: device.name,
            udid: device.udid,
            state: device.state,
          })
        }
      }
    }
    return simulators
  } catch {
    return []
  }
}

function bootSimulator(udid: string): void {
  try {
    execSync(`xcrun simctl boot "${udid}"`, { stdio: 'pipe' })
  } catch {
    // Already booted
  }
  try {
    execSync('open -a Simulator', { stdio: 'pipe' })
  } catch {}
}

function detectAndroidEmulators(): string[] {
  try {
    const output = execSync('adb devices', { stdio: 'pipe', encoding: 'utf8' })
    const lines = output.split('\n').filter(l => l.includes('device') && !l.startsWith('List'))
    return lines.map(l => l.split('\t')[0]).filter(Boolean)
  } catch {
    return []
  }
}

// ---------------------------------------------------------------------------
// Dev command
// ---------------------------------------------------------------------------

export const devCommand = new Command('dev')
  .description('Start the Vue Native dev server with hot reload')
  .option('-p, --port <port>', 'WebSocket port for hot reload', String(DEFAULT_PORT))
  .option('--ios', 'auto-detect and launch iOS Simulator')
  .option('--android', 'auto-detect Android emulator')
  .option('--simulator <name>', 'specify iOS Simulator name')
  .action(async (options: { port: string, ios?: boolean, android?: boolean, simulator?: string }) => {
    const port = parseInt(options.port, 10)
    const cwd = process.cwd()
    const bundlePath = join(cwd, BUNDLE_FILE)

    console.log(pc.cyan('\n  Vue Native Dev Server\n'))

    // ── iOS Simulator auto-detect ──────────────────────────────────────────
    if (options.ios) {
      console.log(pc.white('  Detecting iOS Simulators...'))
      const simulators = detectIOSSimulators()
      if (simulators.length === 0) {
        console.log(pc.yellow('  No iOS Simulators found. Install Xcode and create a simulator.'))
      } else {
        // Find a matching simulator
        let target = simulators.find(s => s.state === 'Booted')
        if (!target && options.simulator) {
          target = simulators.find(s => s.name === options.simulator)
        }
        if (!target) {
          // Prefer iPhone models
          target = simulators.find(s => s.name.includes('iPhone')) ?? simulators[0]
        }

        if (target) {
          if (target.state !== 'Booted') {
            console.log(pc.white(`  Booting ${target.name}...`))
            bootSimulator(target.udid)
          }
          console.log(pc.green(`  iOS Simulator ready: ${target.name}`))
        }
      }
      console.log()
    }

    // ── Android emulator auto-detect ───────────────────────────────────────
    if (options.android) {
      console.log(pc.white('  Detecting Android emulators...'))
      const emulators = detectAndroidEmulators()
      if (emulators.length === 0) {
        console.log(pc.yellow('  No Android emulators detected. Start one via Android Studio or `emulator -avd <name>`.'))
      } else {
        console.log(pc.green(`  Android emulator(s) connected: ${emulators.join(', ')}`))
      }
      console.log()
    }

    // ── WebSocket server for hot reload ────────────────────────────────────
    const wss = new WebSocketServer({ port })
    const clients = new Set<WebSocket>()

    wss.on('connection', (ws) => {
      clients.add(ws)
      ws.send(JSON.stringify({ type: 'connected' }))
      console.log(pc.green(`  Client connected (${clients.size} total)`))

      // Send current bundle immediately on connect
      readFile(bundlePath, 'utf8')
        .then((bundle) => {
          if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: 'bundle', bundle }))
            console.log(pc.dim(`  Sent bundle to new client (${Math.round(bundle.length / 1024)}KB)`))
          }
        })
        .catch(() => {
          // Bundle not built yet
        })

      ws.on('close', () => {
        clients.delete(ws)
        console.log(pc.dim(`  Client disconnected (${clients.size} remaining)`))
      })

      ws.on('message', (data) => {
        try {
          const msg = JSON.parse(data.toString())
          if (msg.type === 'pong') return
        } catch {}
      })
    })

    wss.on('error', (err) => {
      console.error(pc.red(`WebSocket server error: ${err.message}`))
    })

    console.log(pc.white(`  Hot reload server: ${pc.bold(`ws://localhost:${port}`)}`))

    // Show connection info for both platforms
    const iosDir = join(cwd, 'ios')
    const androidDir = join(cwd, 'android')
    if (existsSync(iosDir)) {
      console.log(pc.dim(`  iOS app should connect to ws://localhost:${port}`))
    }
    if (existsSync(androidDir)) {
      console.log(pc.dim(`  Android emulator should connect to ws://10.0.2.2:${port}`))
    }
    console.log(pc.dim('  Waiting for app to connect...\n'))

    // ── Start Vite in watch mode ───────────────────────────────────────────
    console.log(pc.white('  Starting Vite build watcher...\n'))
    const vite = spawn(
      'bun',
      ['run', 'vite', 'build', '--watch', '--mode', 'development'],
      { cwd, stdio: 'pipe' },
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

    // ── Watch for bundle file changes and broadcast ────────────────────────
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
        console.log(pc.green(`  Bundle updated (${Math.round(bundle.length / 1024)}KB) -> sent to ${sent} client(s)`))
      } catch {
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
